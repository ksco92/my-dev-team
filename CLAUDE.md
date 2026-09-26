# my-dev-team

See the root README for what this repo is.

## Layout

- `.claude-plugin/`, the marketplace manifest.
- `plugins/dev-team/.claude-plugin/`, the plugin manifest.
- `plugins/dev-team/skills/`, the TPM, PM, and three review-gate skills.
- `plugins/dev-team/agents/`, the implementer and reviewer agent definitions.
- `plugins/dev-team/context/`, the stack guides and TPM procedure references.
- `plugins/dev-team/hooks/`, the merge-gate and attribution-guard Bash hooks and `hooks.json`.
- `plugins/dev-team/bin/`, the gate-ledger binary.
- `plugins/dev-team/README.md`, the plugin's README.
- `.github/workflows/ci.yml`, the validation CI workflow.

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

Markdown prose in skills, agents, and guides states the rule, not the incident: one imperative
sentence, two at most, no dates, no repo or PR names. Models are named by alias only (`sonnet`,
`opus`, `fable`), never a versioned id.
