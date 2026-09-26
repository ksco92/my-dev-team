# my-dev-team

A Claude Code plugin marketplace. `dev-team` carries a personal dev harness: TPM orchestration,
tiered implementer agents, review-gate agents, stack guides, hooks, and a gate ledger.

## Layout

- `.claude-plugin/marketplace.json` — the marketplace manifest, at the repo root.
- `plugins/dev-team/` — the plugin.
  - `.claude-plugin/plugin.json` — the plugin manifest, including its version.
  - `skills/`, `agents/`, `context/`, `hooks/`, `bin/`, `evals/` — the plugin's components.

## Local checks

```
claude plugin validate .claude-plugin/marketplace.json --strict
claude plugin validate plugins/dev-team --strict
shellcheck plugins/dev-team/hooks/*.sh plugins/dev-team/bin/*
```

## Conventions

Every PR bumps `plugins/dev-team/.claude-plugin/plugin.json` `version` per semver, with the major-zero
rule: a breaking change or a feature bumps minor, everything else bumps patch. Never bump to `1.0.0`
without the owner's explicit say-so.

Markdown prose in this repo states the rule, not the incident: one imperative sentence, two at
most, no dates, no repo or PR names.

No versioned model ids appear anywhere in this repo; use aliases (`sonnet`, `opus`) only.

PRs land through the five review gates (`pr-reviewer`, `code-health`, `oss-reviewer`,
`security-review`, `readme-writer`); the merge is refused until every gate passes.
