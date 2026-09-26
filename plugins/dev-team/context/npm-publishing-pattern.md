# npm Publishing Pattern (CI/CD)

The shared CI/CD setup for the maintainer's TypeScript/npm projects. Replicate it on any new npm
package. This document is self-contained, but the two reference repos below are the canonical, current
source — read their actual files when replicating.

## Reference repos

- **arceus** — single package at the repo root. npm package `cdk-glue-iceberg-table`.
  <https://github.com/ksco92/arceus>
  - Badges + layout: `README.md`
  - CI: `.github/workflows/ci.yml`
  - Publish: `.github/workflows/publish.yml`
- **eevee** — monorepo; the npm package lives in `packages/core`. npm package `flexdataset`.
  <https://github.com/ksco92/eevee>
  - Badges + layout: `README.md`
  - CI: `.github/workflows/ci.yml`
  - Publish: `.github/workflows/publish.yml`
  - Tagged full releases (binaries + PyPI): `.github/workflows/release.yml`

Use **arceus** as the template for a single-package repo and **eevee** as the template for a monorepo
(package in a subdirectory).

## 1. README badges

Place under the H1 title. Substitute `<owner>/<repo>` and `<pkg>` (the npm package name). The coverage
badge uses `codecov.io`; the rest use `shields.io`.

```markdown
[![CI](https://img.shields.io/github/actions/workflow/status/<owner>/<repo>/ci.yml?branch=main&label=CI)](https://github.com/<owner>/<repo>/actions/workflows/ci.yml)
[![coverage](https://codecov.io/gh/<owner>/<repo>/branch/main/graph/badge.svg)](https://codecov.io/gh/<owner>/<repo>)
[![npm](https://img.shields.io/npm/v/<pkg>.svg)](https://www.npmjs.com/package/<pkg>)
[![types](https://img.shields.io/npm/types/<pkg>.svg)](https://www.npmjs.com/package/<pkg>)
[![downloads](https://img.shields.io/npm/dw/<pkg>.svg)](https://www.npmjs.com/package/<pkg>)
[![last commit](https://img.shields.io/github/last-commit/<owner>/<repo>.svg)](https://github.com/<owner>/<repo>/commits/main)
[![license](https://img.shields.io/npm/l/<pkg>.svg)](LICENSE)
```

The npm and coverage badges read "not found / unknown" until the first publish and first Codecov upload.
That is expected for a new repo, not a defect.

## 2. CI workflow (`ci.yml`)

Triggers on push and pull_request to `main`. One job: checkout, `setup-node@v4` (Node 22, `cache: npm`),
`npm ci`, `npm run lint`, `npm test`, upload `lcov` coverage to Codecov, `npm run build`, then
`npm pack --dry-run`. Codecov upload uses `fail_ci_if_error: false` and `token: ${{ secrets.CODECOV_TOKEN }}`
(the token is required because `main` is a protected branch — tokenless upload is disabled there).

For a monorepo, set `defaults.run.working-directory` to the package directory and
`cache-dependency-path` to that package's `package-lock.json`. eevee's CI also has a `self-validate` job
and a separate `python` job; those are project-specific additions on top of this base.

## 3. Publish workflow (`publish.yml`) — the core pattern

Continuous delivery to npm: every push to `main` (every PR merge) publishes **only if** the version in
`package.json` is newer than what is on the registry, so a forgotten bump is a harmless no-op.

- Triggers: `push: branches: [main]` plus `workflow_dispatch`.
- Auth: **npm trusted publishing via GitHub OIDC — no `NPM_TOKEN` secret.** Set `permissions: id-token: write`,
  upgrade the npm CLI (trusted publishing needs npm >= 11.5.1), and publish with `--provenance`.
- A `concurrency` group prevents overlapping publishes.

The gate and publish steps:

```yaml
permissions:
  contents: read
  id-token: write
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-node@v4
    with:
      node-version: 22
      cache: npm
      registry-url: https://registry.npmjs.org
  - run: npm install -g npm@latest   # trusted publishing needs npm >= 11.5.1
  - run: npm ci
  - run: npm run lint
  - run: npm test
  - run: npm run build
  - name: Compare package.json version against the registry
    id: check
    run: |
      local_version=$(node -p "require('./package.json').version")
      registry_version=$(npm view <pkg> version 2>/dev/null || echo "0.0.0")
      if [ "$local_version" = "$registry_version" ]; then
        echo "skip=true"  >> "$GITHUB_OUTPUT"
      else
        echo "skip=false" >> "$GITHUB_OUTPUT"
      fi
  - name: Publish
    if: steps.check.outputs.skip == 'false'
    run: npm publish --access public --provenance
```

For a monorepo, add `defaults.run.working-directory: <package-dir>` (e.g. `packages/core`) and
`cache-dependency-path: <package-dir>/package-lock.json`; then `require('./package.json')` resolves to
the package's manifest.

## 4. npm trusted publishing setup (one-time, per package)

Before the first publish, configure the trusted publisher at npmjs.com (the package's
Settings → Trusted publishing, or your account's publishing settings): GitHub repo `<owner>/<repo>`,
workflow filename `publish.yml`, branch `main`. All three must match the workflow exactly. Until this is
configured, the publish step fails without harm; CI and the version check still run.

## 5. Version-bump rules

- **Every PR to `main` bumps the `version` field.** The bump size (`x` / `y` / `z`, and the special
  `0.y.z` experimental rule) is defined canonically in the root `CLAUDE.md` "Versioning (semver
  `x.y.z`)" section — follow that. In short: breaking / architectural → major (but on `0.y.z` it stays
  minor, and never go to `1.0.0` without the user's explicit say-so); features / significant fixes →
  minor; everything else → patch.
- `publish.yml` is a no-op unless the version is newer than the registry, so a forgotten bump does not
  error but does not ship. Reviewers reject PRs that forget to bump.
- When a repo ships sibling packages (e.g. an npm package and a PyPI package), keep their versions in
  lockstep and bump them together. Regenerate the lockfile (`npm install --package-lock-only`) so
  `package-lock.json` name/version match `package.json` — a stale lockfile is a common miss.

## 6. Optional: tagged full releases (eevee's `release.yml`)

When a repo also ships standalone binaries and/or PyPI wheels, keep npm continuous (`publish.yml` on
`main`) and put the heavier artifacts on a `v*` tag in `release.yml`: cross-compile per-platform binaries
(`bun build src/cli.ts --compile --target=...`), attach them to the GitHub release, and publish the PyPI
wheels. Do **not** also publish npm from the tag workflow — it would double-publish the version that
`publish.yml` already shipped from `main`.

## 7. Replicate on a new repo

1. Add the badge block to `README.md` (substitute owner / repo / package).
2. Copy `.github/workflows/ci.yml` from arceus (single package) or eevee (monorepo; set the package
   `working-directory`).
3. Copy `.github/workflows/publish.yml`; substitute the package name in the version check and, for a
   monorepo, set the package `working-directory`.
4. Configure npm trusted publishing for the package (section 4).
5. Adopt the version-bump-per-PR rule (section 5).
6. Set the `CODECOV_TOKEN` repo secret if `main` is protected.

## Self-mutation rule

Maintained by the orchestrating session only — never by a delegated subagent or headless worker,
even one instructed to read this file; a subagent that notices something worth adding reports it
under `Proposed learned pattern:` in its own output. Lessons here are stack-specific and true in
any repo of this stack; repo-specific facts go to that repo's `.claude/rules/`. Append an
imperative bullet under `## Learned patterns` (one sentence, two at most; no date, no repo name, no "added after" tail),
refine near-duplicates in place, keep the section under ~25 entries, and open a PR against the
plugin repository (`ksco92/my-dev-team`).

## Learned patterns

- For a jsii construct that also publishes to PyPI, keep `package.json` `repository.url` a plain
  `https://` URL with no `git+` prefix; jsii-pacmak copies it into the wheel's `Project-URL` and
  PyPI rejects `git+` with a 400 while npm accepts it. Fix at the same version: npm skips, PyPI
  publishes, the per-registry version gate keeps them aligned.
