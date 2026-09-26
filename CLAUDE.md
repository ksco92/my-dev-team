# my-dev-team

See the root README for what this repo is.

## Layout

- `.claude-plugin/`, the marketplace manifest.
- `plugins/dev-team/.claude-plugin/`, the plugin manifest.
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
