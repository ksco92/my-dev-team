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
  - State that `trivial` local runs must pass local tests, lint, `preflight-scan --scope=diff`, and
    a local `run_agent(backend="pi")` self-check before opening a PR for the five SOTA review gates,
    and that authoritative merge-blocking gate verdicts remain SOTA-only (`sonnet`/`opus` via Claude
    Code or Antigravity).
  - Update escalation policy: `trivial` escalates to Sonnet (`low`) immediately on strike 1 if SOTA
    gates find a logic, structural, or security defect, if one local fix pass for mechanical nits
    does not turn clean, or if local tests fail twice before PR creation; `low`/`medium` still
    escalate `Sonnet → Opus`.
  - Keep `plugins/dev-team/context/policy.md` under 9,500 UTF-8 characters.
- [ ] Update `plugins/dev-team/skills/tpm/SKILL.md`:
  - Frontmatter `description`: update `low/medium/high` to `trivial/low/medium/high` and note
    `trivial → local Pi (Sonnet fallback)`.
  - Phase 2 (Decomposition): define the four-tier boundary cleanly so `trivial` does not overlap
    `low`:
    - `trivial`: closed-world, zero-discovery mechanical edit (at most 3-4 files, single
      layer/module, no cross-module interface/schema changes, context small enough for 64K local
      models, verified by a fast deterministic local check; never security, auth, billing,
      migrations, concurrency, public-API breaks, or live external-API assumptions).
    - `low`: mechanical recipe allowed to span multiple files/layers or light codebase discovery
      (Sonnet; still never security/auth/money/data integrity).
    - `medium`: clear goal/files with some design/edge-case judgment (Sonnet).
    - `high`: real decisions, unclear approach, research, or correctness/security-critical surface
      (Opus).
    - Tie-breakers: when torn between `trivial` and `low`, tag `low`; when torn between `low` and
      `medium`, tag `low`.
    - Anti-over-slicing rule: never split a cohesive slice solely to manufacture `trivial` tickets
      (running five SOTA gates per tiny PR costs more than one clean Sonnet PR).
  - Phase 3 (Tickets): define the `trivial` ticket contract requiring four concrete elements: closed
    `Files to read` / `Files to edit` allowlist, exact `file:lines` reference pattern, verbatim
    local verification command(s) (tests, lint, `preflight-scan --scope=diff`), and an explicit
    anti-bloat constraint (no added comments, no new helper abstractions, no guards beyond listed
    edge cases).
  - Phase 4 (Delegation): add `trivial` to the routing table (local Pi `run_agent(backend="pi")`
    with local pre-flight self-check; Sonnet fallback when no local runner is available, or
    `Model="flash"` under Antigravity).
  - Phase 5.1 (The five gates): update `pr-reviewer` model row to `D ∈ {trivial, low, medium}` for
    Sonnet (and Opus for `high` or any PR whose implementer ran on Opus).
  - Phase 5.2 (Fix until clean): state the 1-strike escalation rule for `trivial → Sonnet` (at most
    one local fix pass for mechanical SOTA nits after re-passing local pre-flight; immediate
    escalation to Sonnet on any logic/structural/security finding or on two failed local test
    attempts before PR creation).
- [ ] Update `plugins/dev-team/context/tpm/briefing.md` line 43-44 to carve out `trivial` local
      implementers from `"No pre-push self-check list for implementers (owner decision)."` so
      Sonnet/Opus implementers remain exempt while `trivial` local runs run their local pre-flight
      before opening a PR for SOTA gates.
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
