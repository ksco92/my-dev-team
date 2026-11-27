---
difficulty: medium
priority: p1
status: done
---

# Add `trivial` Local-Model Difficulty Tier and TPM Ticket Guardrails

## Context

`dev-team` currently routes all implementation slices to Sonnet (`low`/`medium`) or Opus (`high`)
and forbids a local-model tier in `context/policy.md`. Now that `my-dev-team` ships a native Pi
adapter (`plugins/dev-team/pi/dev-team.ts`) with `run_agent`, adding a strict `trivial` tier beneath
`low` lets local Pi models handle narrow, closed-world mechanical tickets without causing token
inversion against the five SOTA review gates.

## Requirements

- [ ] Update `plugins/dev-team/context/policy.md`:
  - Add `trivial` beneath `low` in the pipeline summary and `Tiered delegation` section (replacing
    `"There is no local-model tier."`): route `trivial` to a local Pi implementer when running on or
    delegating to a local-AI host, falling back to `implementer` on Sonnet (or queuing a tracked
    `difficulty:trivial` ticket for a local runner) when no local host is available.
  - Define the two-step local pre-flight handoff: a `trivial` local implementer passes tests, lint,
    and `preflight-scan --scope=diff`, commits locally, and returns before pushing; the TPM runs
    `run_agent(<gate>, backend="pi")` self-checks on that commit and resumes the implementer to push
    and open the PR for the five SOTA review gates (authoritative merge-blocking gate verdicts
    remain SOTA-only: `sonnet`/`opus` via Claude Code or Antigravity).
  - Update escalation policy: `trivial` local Pi runs move to Sonnet on strike 1 (re-tagged to
    `low`; see `tpm` 5.2), and any slice at Sonnet moves `Sonnet → Opus`.
  - Keep `plugins/dev-team/context/policy.md` under 9,500 UTF-8 characters.
- [ ] Update `plugins/dev-team/skills/tpm/SKILL.md`:
  - Frontmatter `description`: update `low/medium/high` to `trivial/low/medium/high` and note
    `trivial → local Pi (Sonnet fallback)`.
  - Phase 2 (Decomposition): define the four-tier boundary cleanly without duplicating shared
    lower-tier exclusions:
    - `trivial`: closed-world, zero-discovery mechanical edit (at most 3-4 files, single
      layer/module, no cross-module interface/schema changes, context small enough for 64K local
      models, verified by a fast deterministic local check; never migrations, concurrency,
      public-API breaks, live external-API assumptions, or the lower-tier exclusions).
    - `low`: mechanical recipe allowed to span multiple files/layers or light codebase discovery
      (Sonnet).
    - `medium`: clear goal/files with some design/edge-case judgment (Sonnet).
    - `high`: real decisions, unclear approach, research, or correctness/security-critical surface
      (Opus).
    - Shared lower-tier exclusion stated once: anything touching security, auth, money, or data
      integrity is never `trivial` or `low`.
    - Tie-breaker: when torn between `trivial`/`low` or `low`/`medium`, tag `low`.
    - Anti-over-slicing rule: never split a cohesive slice solely to manufacture `trivial` tickets
      (running five SOTA gates per tiny PR costs more than one clean Sonnet PR).
  - Phase 3 (Tickets): define the `trivial` ticket contract requiring four concrete elements: closed
    `Files to read` / `Files to edit` allowlist, exact `file:lines` reference pattern, verbatim
    local verification command(s) (tests, lint, `preflight-scan --scope=diff`), and an explicit
    anti-bloat constraint (no added comments, no new helper abstractions, no guards beyond listed
    edge cases).
  - Phase 4 (Delegation): add `trivial` to the routing table (local Pi `run_agent(backend="pi")`
    pointing to `policy.md` for the two-step local pre-flight handoff; Sonnet fallback when no local
    runner is available, or `Model="flash"` under Antigravity), point `Under Pi` to `policy.md` for
    that two-step handoff, and update the code-economy note for `trivial`/`low`.
  - Phase 5.1 (The five gates): update `pr-reviewer` model row to `D ∈ {trivial, low, medium}` for
    Sonnet (and Opus for `high` or any PR whose implementer ran on Opus).
  - Phase 5.2 (Fix until clean): state the 1-strike escalation rule for `trivial` local Pi runs (at
    most one local fix pass for mechanical SOTA nits after re-passing the two-step local pre-flight;
    strike-1 escalation to Sonnet re-tagging the ticket to `low` on any logic/structural/security
    finding, if that single nit pass does not turn clean, or on two failed local test attempts
    before PR creation) and that any slice at Sonnet (including `trivial` on Sonnet fallback or
    escalated from local Pi) moves `Sonnet → Opus` after two failed fix attempts.
- [ ] Update `plugins/dev-team/context/tpm/briefing.md` line 43-44 to carve out `trivial` local
      implementers from `"No pre-push self-check list for implementers (owner decision)."` by
      pointing to the local pre-flight in `policy.md` before opening a PR for SOTA gates.
- [ ] Sync `plugins/dev-team/agents/implementer.md` and `plugins/dev-team/agents/pr-reviewer.md`
      ladder descriptions to include `trivial` (local Pi or Sonnet fallback for `implementer`;
      `trivial`/`low`/`medium` PRs on Sonnet unless implemented on Opus for `pr-reviewer`).
- [ ] Update difficulty value enumerations from `low|medium|high` to `trivial|low|medium|high` in:
  - `plugins/dev-team/context/dev-process-contract.md`
  - `plugins/dev-team/context/dev-process.default.md`
  - `plugins/dev-team/templates/DEV_PROCESS.md`
  - `DEV_PROCESS.md` (keeping `DEV_PROCESS.md` under 9,500 UTF-8 characters)
  - `docs/examples/DEV_PROCESS.github.md`
  - `docs/examples/DEV_PROCESS.asana.md`
- [ ] Bump version from `0.20.0` to `0.21.0` in both `plugins/dev-team/.claude-plugin/plugin.json`
      and root `package.json`, and update `README.md` status line from `v0.20.0` to `v0.21.0` (keep
      the one-line description byte-identical across all 6 synced files).

## Acceptance Criteria

- [ ] `wc -m plugins/dev-team/context/policy.md` < 9,500 and `wc -m DEV_PROCESS.md` < 9,500 (and
      `plugins/dev-team/hooks/session-context.sh policy` and `process` both inline cleanly without
      truncation).
- [ ] Zero em-dashes (`—`) introduced in any added or modified lines, and zero private repository
      names or personal machine hostnames anywhere in the diff.
- [ ] `claude plugin validate .claude-plugin/marketplace.json --strict`,
      `claude plugin validate plugins/dev-team --strict`, `shellcheck`, `python3 -m py_compile`,
      `prettier@3.6.2 --check`, full-tree `lesson-lint`, `preflight-scan --scope=diff` and
      `--scope=full`, and all 9 test scripts pass with zero errors and zero warnings.
- [ ] `plugins/dev-team/.claude-plugin/plugin.json` and root `package.json` both read `0.21.0`,
      `README.md` status reads `v0.21.0`, and the one-line description matches byte-for-byte across
      all 6 synced files.

## Implementation Plan

1. Update `policy.md` concisely first and check `wc -m` (< 9,500) plus `session-context.sh policy`.
2. Update `tpm/SKILL.md` (frontmatter + Phases 2, 3, 4, 5.1, 5.2) and `context/tpm/briefing.md`.
3. Update `dev-process-contract.md`, `dev-process.default.md`, `templates/DEV_PROCESS.md`,
   `DEV_PROCESS.md`, `docs/examples/DEV_PROCESS.github.md`, and `docs/examples/DEV_PROCESS.asana.md`
   to include `trivial` in difficulty enumerations and ticket templates.
4. Bump `plugin.json` and `package.json` to `0.21.0`, update `README.md` status to `v0.21.0`, format
   with `prettier@3.6.2 --write`, and run all local validation checks and test suites.

## Dependencies

- Blocked by: pi-adapter-core (merged in PR #78) · Blocks: none

## Out of Scope

- Changes to `plugins/dev-team/pi/dev-team.ts` or any hook/CLI executable scripts.
- External machine setup scripts or chat-bot bridges.
