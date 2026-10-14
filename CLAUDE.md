# my-dev-team

See the root README for what this repo is.

## Layout

- `.claude-plugin/`, the marketplace manifest.
- `plugins/dev-team/.claude-plugin/`, the plugin manifest.
- `plugins/dev-team/skills/`, the TPM, PM, and three review-gate skills.
- `plugins/dev-team/agents/`, the implementer and reviewer agent definitions.
- `plugins/dev-team/context/`, the stack guides, TPM procedure references, harness policy,
  `DEV_PROCESS.md` contract, and built-in default process.
- `plugins/dev-team/hooks/`, the merge-gate, attribution-guard, and session-context Bash hooks and
  `hooks.json`.
- `plugins/dev-team/bin/`, the gate-ledger, dev-process, and lesson-lint scripts.
- `plugins/dev-team/templates/`, the blank `DEV_PROCESS.md`.
- `plugins/dev-team/tests/`, the Bash tests for the scripts and hooks.
- `plugins/dev-team/evals/`, the `claude plugin eval` suite for the implementer and the five review
  gates.
- `plugins/dev-team/README.md`, the plugin's README.
- `.github/workflows/ci.yml`, the validation CI workflow.
- `docs/examples/`, example `DEV_PROCESS.md` files; the plugin never reads them.
- `docs/cloud-environment/`, the cloud environment setup script for the psyduck repositories; the
  plugin never reads it.
- `DEV_PROCESS.md`, this repository's own development process.

## Local checks

```
claude plugin validate .claude-plugin/marketplace.json --strict
claude plugin validate plugins/dev-team --strict
shellcheck plugins/dev-team/hooks/*.sh plugins/dev-team/bin/* plugins/dev-team/tests/*.sh
bash plugins/dev-team/tests/dev-process.test.sh
bash plugins/dev-team/tests/lesson-lint.test.sh
bash plugins/dev-team/tests/merge-gate.test.sh
bash plugins/dev-team/tests/evals.test.sh
plugins/dev-team/bin/lesson-lint --added origin/main $(git ls-files 'plugins/dev-team/*.md')
claude plugin eval plugins/dev-team --case readme-writer-doc-drift --scaffold --runs 1 --ablation none --trust-plugin --max-cost-usd 2
claude plugin eval plugins/dev-team --case implementer-date-range-filter --scaffold --allow-tools Bash Write Edit --runs 1 --ablation none --trust-plugin --max-cost-usd 2
```

## Conventions

Every PR bumps `plugins/dev-team/.claude-plugin/plugin.json` `version` per semver, with the major-zero
rule: a breaking change or a feature bumps minor, everything else bumps patch. Never bump to `1.0.0`
without the owner's explicit say-so.

Markdown prose in skills, agents, and guides states the rule, not the incident: one imperative
sentence, two at most, no dates, no repo or PR names. Models are named by alias only (`sonnet`,
`opus`, `fable`), never a versioned id.
