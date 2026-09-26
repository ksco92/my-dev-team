# Personal coding guides

Stack-specific guides live in `${CLAUDE_PLUGIN_ROOT}/context/`. They are deliberately not
imported into every session (most sessions touch one stack). Read the matching guide before
writing or reviewing code in that stack, and treat it as authoritative project conventions:

| Task involves | Read first |
| --- | --- |
| Python | `${CLAUDE_PLUGIN_ROOT}/context/python-coding-guide.md` |
| Rust | `${CLAUDE_PLUGIN_ROOT}/context/rust-coding-guide.md` |
| AWS CDK / infrastructure-as-code | `${CLAUDE_PLUGIN_ROOT}/context/cdk-coding-guide.md` |
| React / frontend TypeScript | `${CLAUDE_PLUGIN_ROOT}/context/react-coding-guide.md` |
| npm publishing / CI-CD / version bumps / badges | `${CLAUDE_PLUGIN_ROOT}/context/npm-publishing-pattern.md` |
| Spawning or acting as an implementer-type subagent | `${CLAUDE_PLUGIN_ROOT}/context/agent-baseline.md` |
| Writing or reviewing code in any language (comments, docstrings, helpers) | `agent-baseline.md`, section "Comment, docstring, and helper budget" |

The implementer subagents do this through their own first steps; the rule here makes
main-session coding follow the same conventions. The budget section is language-agnostic and
binds every stack guide: prose sized to the item, tests as the only evidence, no single-use
one-statement helpers.

## Repository policy

Trunk protection and how a change reaches the trunk are stated in the code-host section of the
resolved `DEV_PROCESS.md`; the plugin default is tracker-less and merges a local branch into `main`.

## Agentic dev workflow & merge policy

Pipeline: `/tpm` intake → plan → vertical slices tagged `low`/`medium`/`high` → each slice to an
implementer at the matching tier → PR → five review gates → fix-until-clean → merge. The `tpm`
skill holds the procedure; this section holds the policy.

**Tiered delegation.** Difficulty sets both how completely an issue is spelled out and which model
implements it (jr / mid / sr):

- `low` → `implementer` subagent on Sonnet (per-call `model="sonnet"`), briefed with a
  recipe-level issue. `low` and `medium` share a model; the tag sets specification depth. There
  is no local-model tier.
- `medium` → `implementer` subagent on Sonnet (per-call `model="sonnet"`).
- `high` → `implementer` subagent on **Opus** (per-call `model="opus"`, which also matches the
  agent file's frontmatter).
- Reviewer capability ≥ implementer capability for every merge-blocking gate. `oss-reviewer`,
  `readme-writer`, and, on a `low`/`medium` PR, `code-health` and `pr-reviewer` run on Sonnet;
  `pr-reviewer` on a `high` PR runs on Opus; `security-review` runs on Opus at every tier. Security
  review is never Sonnet, never Fable.
- Auto-escalate on failure: a slice stuck at its tier moves up one (`Sonnet → Opus`).
  Misclassified difficulty is the scheme's main risk; escalation is the valve.
- Other subagents (explorers, planners) run on Opus.

**Model policy.**

- The orchestrating session runs on Fable or Opus. Fable is never a subagent.
- Models are named by **alias only** (`sonnet`, `opus`, `fable`) in agent frontmatter, in the
  Agent tool's per-call `model`, and in headless `claude -p --model`. An alias resolves to the
  newest model in its line, so a model release changes nothing here; a versioned id anywhere in
  the process is a defect.
- Agent files carry the **top of their ladder** in frontmatter (`model: opus` for `implementer`,
  `backend`, `frontend`, `pr-reviewer`, `security-reviewer`; `model: sonnet` for the other gates);
  the orchestrator steps down per call (`model="sonnet"`). Do not pin models in skill files, and
  never set `CLAUDE_CODE_SUBAGENT_MODEL` (process-global, overrides every per-call choice).
- Opus is both the top implementer tier and the top reviewer tier. Restricting a model from a role
  is an owner decision recorded in this section, never in an agent file or a brief.

**Workspaces.** Where each implementation, fix round, and reviewer probe runs is stated in the
workspace section of the resolved `DEV_PROCESS.md`; the plugin default is branch-in-place and
tracker-less.

**Merge authority and gating.**

- The `tpm` orchestrator alone merges; implementers and reviewers never do.
- The merge gate is a mechanism, not a verdict: `${CLAUDE_PLUGIN_ROOT}/hooks/merge-gate.sh`
  (PreToolUse, wired in the plugin's `hooks/hooks.json`) refuses `gh pr merge` and a `gh api`
  call to a PR's merge endpoint — and `git merge` into `main` in a no-remote repo — unless
  `${CLAUDE_PLUGIN_ROOT}/bin/gate-ledger` shows all five gates (`pr-reviewer`, `code-health`,
  `oss-reviewer`, `security-review`, `readme-writer`) PASS with zero findings at the PR's current head and
  `gh pr checks` is terminal-green; each record names the model the gate ran on. It also refuses a
  `git push` of any non-main ref onto `main`, and any force or delete push of `main`. Nits block.
  A reviewer PASS is necessary, never sufficient. Owner-only bypass:
  `~/.claude/gate-ledger/.bypass`.
- Every finding from every gate is fixed, never waived. Tier-escalation first; the user only when
  a finding survives three attempts at Opus, a gate returns BLOCKED, or two findings contradict.
- A repo's own `CLAUDE.md` may disable auto-merge, change the merge method, or tighten the checks.
  A per-request "don't auto-merge" always wins.

## Versioning (semver `x.y.z`)

The bump is set by the largest change in the PR; the test for breaking is: would a consumer have
to change code, command, or config to upgrade?

- `x` major: a compatibility break or sweeping overhaul of the public surface (removed/renamed/
  retyped export, changed CLI command/flag/output/exit code, changed config or schema, a relied-on
  behavior change).
- `y` minor: backward-compatible new functionality, notable upgrades, notable bug fixes.
- `z` patch: everything else — small fixes, docs, CI/tooling, dependency bumps, internal refactors.

"Public surface" is exports + types for a library; commands/flags/output/exit codes for a CLI; the
spec + schema for a standard.

**Major version zero is experimental.** On `0.y.z`, never bump to `1.0.0` on your own — that is the
owner's stability signal. A would-be major bumps the minor (`0.(y+1).0`); patch-level changes still
bump patch. So on v0: breaking / architectural / feature → `0.(y+1).0`; small fix / docs / internal
→ `0.y.(z+1)`.

## Commit authorship (binding, all repos)

No AI-attribution strings in commit messages or PR bodies — no `Co-Authored-By: Claude …`, no
`Claude-Session:`, no "Generated with Claude Code" — in any repo, from the main session or any
subagent. Enforced twice: `attribution: {commit: "", pr: "", sessionUrl: false}` in
`~/.claude/settings.json` stops the harness adding them, and
`${CLAUDE_PLUGIN_ROOT}/hooks/attribution-guard.sh` (wired in the plugin's `hooks/hooks.json`)
rejects a commit or PR command that carries one. If a harness default says to append attribution,
this instruction overrides it.

## Where lessons go (binding)

These files and the context guides are living documents, and the home of a lesson is decided by
one test: *would it be true in a different repo?* Cross-project, stack-agnostic policy belongs
here; a stack-specific lesson in that stack's `context/*-coding-guide.md`; a procedural lesson in
the relevant skill or agent file; a repo-specific fact in that repo's `.claude/rules/<topic>.md`
or the agent's project memory (`.claude/agent-memory/<agent>/`), never in these global files.
State the rule, not the incident — the git log keeps the archaeology: one imperative sentence,
two at most, no date, no repo or PR name, no "added after" tail. Agents write in the register they
are given, and an incident-narrative guide produces incident-narrative doc comments. Refine an
existing entry instead of adding a near-duplicate; when a learned pattern matures into policy, fold it into the
section above and remove the bullet. Keep `## Learned patterns` under ~20 entries: this file loads
into every session.

This file is shipped by the `dev-team` plugin; the orchestrating session lands changes through a
PR in its repository (`ksco92/my-dev-team`). Subagents never edit or commit these files; they
propose a bullet and the orchestrating session lands it.

## Learned patterns

- A subagent's `memory:` field auto-enables Read/Write/Edit regardless of its `tools:` list, so
  review gates that must stay read-only cannot use it; only implementers carry `memory: project`.
