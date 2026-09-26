# Beyond-source signals — pattern catalog (Phase 5)

Companion reference for the `oss-reviewer` skill. Loaded on demand during Phase 5.
Signals from git history, manifests, repo shape, and project metadata. Self-mutation
additions land HERE: grep for the highest existing `### 5.N` and use N+1.

Signals from outside source code: git history, committed agent transcripts, dependency manifests, repo shape, and project metadata. Orthogonal to §4's grep-the-tree heuristics — these catch AI-session fingerprints that source-level checks miss.

### 5.1 Hallucinated / unresolvable dependencies in manifest (BLOCKER)

For each dependency declared in `requirements.txt` / `pyproject.toml` / `package.json` / `Cargo.toml`, verify it resolves on the relevant registry. AI-recommended packages have a documented ~19.7% hallucination rate (USENIX Security 2025); 43% of hallucinations repeat across model runs — the exact names attackers slopsquat.

Related: §4.18 covers the same issue at the README install command surface; §5.1 covers the manifest surface. Both can fire on the same repo for different reasons.

Detection:
- **Python**: `urllib.request.urlopen(f"https://pypi.org/pypi/{name}/json", timeout=5)` per dep; 404 = finding.
- **npm**: `curl -sfo /dev/null https://registry.npmjs.org/{name}` per dep.
- **Rust**: `curl -sfo /dev/null https://crates.io/api/v1/crates/{name}`.

Exclude: private / internal-org packages with custom index URLs declared in the manifest; deps resolved to a git / path source.

Severity: BLOCKER — the project doesn't install + supply-chain attack vector. Also flag deps that resolve but have <10 total downloads or age <30 days (potential typosquats deserving manual review, HIGH).

Added by: research synthesis on 2026-05-23.

### 5.2 Committed coding-agent transcripts (CRITICAL)

Raw chat / agent session logs accidentally committed:

```
.specstory/history/*.md
.aider.input.history
.aider.chat.history.md
.claude/projects/**/*.jsonl
.cursor/chats/**
.windsurf/history/**
.continue/sessions/**
```

These files contain literal prompts, intermediate AI responses, context dumps, and sometimes secrets that leaked into the session. SpecStory's own docs recommend committing the history dir — most authors don't realize this is a disclosure leak.

Exclude: `AGENTS.md` and `CLAUDE.md` at the repo root with curated content (project-conventions files, NOT transcripts); `.cursorrules`, `.github/copilot-instructions.md` (rule files, also fine).

Severity: CRITICAL. Direct evidence + potential secret leak + privacy issue.

Added by: research synthesis on 2026-05-23.

### 5.3 Placeholder author identity in package metadata (CRITICAL)

Project metadata files containing literal template placeholders.

```
(author|maintainer|authors)\s*[=:].*("Your Name"|<your name>|you@example\.com|yourname@|author@example|<author@|John Doe|jdoe@example|name@example\.com)
```

Files: `pyproject.toml`, `setup.py`, `setup.cfg`, `package.json`, `Cargo.toml`, `composer.json`.

Also flag single-word `name = "todo"` / `name = "project"` / `name = "package"` on packages declaring a non-trivial version.

Exclude: template-of files explicitly named (`templates/pyproject.toml`, `examples/setup.py`).

Severity: CRITICAL. The package ships to PyPI / npm / crates.io literally identifying its uploader as "Your Name <you@example.com>".

Added by: research synthesis on 2026-05-23.

### 5.4 Tool configs for languages not present in the repo (HIGH)

Linter / formatter configs whose target language has zero files in the tree:

- `.prettierrc*`, `.eslintrc*`, `eslint.config.*`, `.stylelintrc*` present but no `.{js,jsx,ts,tsx,vue,svelte,mjs,cjs,css,scss}` files.
- `pyproject.toml` containing `[tool.ruff]` / `[tool.black]` / `[tool.mypy]` sections but no `.py` files.
- `Cargo.toml` lint configs but no `.rs` files.
- `.editorconfig` with `[*.go]` / `[*.rs]` rules in a pure-Python or pure-JS repo.

Exclude: monorepos where each package owns its own configs; meta-repos *about* a linter.

Severity: HIGH. Cargo-culted scaffolding from "modern project setup" templates the AI emitted without checking.

Added by: research synthesis on 2026-05-23.

### 5.5 Built / generated artifacts committed (HIGH)

```
htmlcov/
\.coverage
coverage\.xml
dist/
build/
.*\.egg-info/
node_modules/
\.next/
target/
__pycache__/
\.pytest_cache/
\.mypy_cache/
```

Check via `git ls-files`. Presence = `git add .` ran indiscriminately and the `.gitignore` was never curated.

Exclude: front-end libraries that intentionally distribute via the repo (`clipboard.js`-style), with the README explicitly documenting that `dist/` is shipped.

Severity: HIGH. Artifacts in `git ls-files` mean the author committed tool output instead of just source.

Added by: research synthesis on 2026-05-23.

### 5.6 Personal-environment paths leaked into committed configs (HIGH)

Committed files containing absolute paths to the author's machine.

```
/(Users|home)/[a-z][a-z0-9._-]+/
C:\\Users\\[A-Za-z]
/opt/homebrew/
/usr/local/Cellar/
```

Files to scan: `.vscode/settings.json`, `.idea/*`, `*.code-workspace`, any committed `.env*`, any committed JSON / YAML config.

Exclude: documentation that references example paths inside fenced code blocks; `.vscode/extensions.json` (extension recommendations are legitimately shared).

Severity: HIGH for paths baked into config values; INFO for committed `.DS_Store` / `.idea/` alone (mostly noise but signals an uncurated `.gitignore`).

Added by: research synthesis on 2026-05-23.

### 5.7 AI-session-shape git history composite (HIGH / CRITICAL by signal count)

A cluster of git-history signals that, taken together, fingerprint "one AI transcript committed as a repo." Each individual signal has false positives (legitimate fresh projects hit one or two); the composite is the high-confidence finding.

**Signals:**

- **a. Single-session initial dump.** First 1-3 commits introduce >50 files / >2000 LOC, all from one author email, all within a 4-hour timestamp window.
  ```bash
  git log --reverse --pretty=format:'%H %aI %ae' | head -3
  git log --reverse --shortstat -1
  ```

- **b. Conventional Commits uniformity.** ≥95% of commit subjects match `^(feat|fix|chore|docs|refactor|test|perf|style|build|ci|revert)(\([^)]+\))?: ` AND repo has no `commitlint` / `.husky` / `conform` enforcement infrastructure AND no CONTRIBUTING.md mandating the convention.

- **c. PR-shaped commit bodies.** Commit message bodies containing H2 headers (`## Summary`, `## Test plan`, `## Changes`) or markdown checklists (`- [ ]` / `- [x]`).

- **d. AI-trailer saturation.** Count `Co-Authored-By: Claude` (plus GPT / Copilot / Cursor variants) and `🤖 Generated with [Claude Code]` footers across commits. >80% of commits carrying the trailer = the author never trimmed one. Acceptable in moderation; saturation is the finding.

- **e. No "messy" history artifacts.** For a repo with >50 commits, zero merge commits, zero `revert "..."` commits, zero amend evidence (author / commit timestamp drift), zero 0-or-1-file "fix typo" commits.

**Triage:**
- 0-1 signals: no finding.
- 2 signals: INFO.
- 3 signals: HIGH.
- 4-5 signals: CRITICAL ("history is the literal output of one AI session, no human curation visible").

Exclude: repos announcing a "ported from <X>, opened YYYY" history in README; repos using release-please / squash-merge workflows that legitimately compress history.

Added by: research synthesis on 2026-05-23.

### 5.8 Docs-template scaffold with no content (CRITICAL)

A `docs/` directory containing the full template scaffold — `getting-started.md`, `architecture.md`, `api.md`, `contributing.md`, `faq.md`, `tutorial.md` — but each file is <30 lines and/or contains placeholder text ("Coming soon", "This section will cover", "TODO", "Lorem ipsum").

```bash
for f in docs/getting-started.md docs/architecture.md docs/api.md docs/faq.md docs/tutorial.md; do
  [ -f "$f" ] || continue
  lines=$(wc -l < "$f")
  placeholders=$(grep -ciE 'TODO|coming soon|this section will|will cover|to be (added|written|completed)|placeholder|lorem ipsum' "$f")
  [ "$lines" -lt 30 ] || [ "$placeholders" -gt 0 ] && echo "stub: $f ($lines lines, $placeholders placeholders)"
done
```

Exclude: Sphinx / MkDocs auto-generated stubs pointing at `.. automodule::` directives; in-progress docs explicitly marked WIP in `docs/README.md`.

Severity: CRITICAL. A docs scaffold with no content is worse than no docs — it implies completeness that doesn't exist.

Added by: research synthesis on 2026-05-23.

### 5.9 Stale CHANGELOG (HIGH / INFO)

`CHANGELOG.md` exists but is empty / stale relative to `git log`:

- Only one release entry (`## 1.0.0 - Initial release` / `## [Unreleased]`) but `git log` shows >20 commits in the last 30 days.
- CHANGELOG entries open with marketing-shaped phrasing: "We're excited to announce", "Today we're shipping", "This release brings".

```bash
changelog_releases=$(grep -cE '^## \[?[0-9]+\.[0-9]+' CHANGELOG.md 2>/dev/null || echo 0)
recent_commits=$(git log --since='30 days ago' --oneline | wc -l)
```

Exclude: projects using `release-please` / `semantic-release` with the corresponding `.releaserc` config.

Severity: HIGH for stale + active git; INFO for marketing-phrased entries alone.

Added by: research synthesis on 2026-05-23.

### 5.10 Examples that don't run (CRITICAL)

`examples/` directory exists but:
- No example file is referenced from README or `docs/`.
- No CI workflow exercises `examples/`.
- At least one example imports a symbol that isn't exported from the package's public surface (`__init__.py` / `index.ts`).

Detection: cross-reference. Read `examples/*.py` (or equivalent); parse `from <pkg> import <X>` lines; verify `<X>` is in the package's exported API. Grep README + `docs/` for path references to `examples/`.

Exclude: examples explicitly marked WIP in an `examples/README.md`.

Severity: CRITICAL. Examples that don't run are docs that lie. Catches AI sessions that scaffold examples to "round out the project" without executing them.

Added by: research synthesis on 2026-05-23.

### 5.11 Untrimmed template scaffolding (HIGH)

Files whose contents are byte-identical (or near-identical) to widely-published template scaffolding:

- `create-react-app` default `src/App.tsx` (contains `Edit <code>src/App.tsx</code> and save to reload.`).
- `cargo new --bin` default `main.rs` (only content: `println!("Hello, world!");`) in a non-trivial repo.
- Vite's default README block.
- `cookiecutter-pypackage` default README sections.

Detection: hash known-template files and compare; or grep tell-strings.

Exclude: explicit tutorial / hello-world repos.

Severity: HIGH. The AI scaffolded a project then never trimmed the scaffold.

Added by: research synthesis on 2026-05-23.

### 5.12 Directory-bloat scaffolding (HIGH)

Repo top-level contains ≥6 "category" directories — `src/`, `lib/`, `app/`, `core/`, `utils/`, `helpers/`, `services/`, `models/`, `controllers/`, `handlers/`, `middleware/`, `adapters/`, `interfaces/`, `domain/`, `infra/` — AND ≥3 of them contain ≤3 files each.

Exclude: monorepos with documented architectural layering; repos whose `ARCHITECTURE.md` justifies the split.

Severity: HIGH. A 200-line project does not need a `controllers/` directory with one file. The AI applied "layered architecture" because tutorials say to, not because the problem needs it.

Added by: research synthesis on 2026-05-23.

### 5.13 Public repo without branch protection on `main` (BLOCKER for public repos)

Policy: any repository set to **public** MUST have branch protection on `main` that blocks
direct pushes — changes land only through merged pull requests. This gate is enforced here, not
left to human discipline.

Determine the repo from the clone's `origin` remote, then check visibility and protection:

```
owner_repo=$(git remote get-url origin | sed -E 's#.*github.com[:/]([^/]+/[^/.]+)(\.git)?#\1#')
gh api "repos/$owner_repo" --jq .visibility
gh api "repos/$owner_repo/branches/main/protection" 2>/dev/null
gh api "repos/$owner_repo/rules/branches/main" --jq '[.[].type]' 2>/dev/null
```

Evaluate:

- **`visibility == "public"` and `main` is not protected** — the classic protection endpoint
  returns 404 AND no ruleset of type `pull_request` covers `main` (so direct pushes are allowed,
  or PR review is not required) → **BLOCKER**. Direct pushes to `main` on a public repo defeat the
  PR + review gate the project relies on. A `pull_request` ruleset (newer GitHub model) or classic
  protection with `required_pull_request_reviews` set satisfies the requirement.
- **`visibility == "private"`** — record as **INFO** with the note "set branch protection on `main`
  before going public." It is a pre-public requirement, not yet a blocker.

If `gh` is unauthenticated or the API call fails, report INFO ("could not verify branch protection;
confirm manually") rather than passing silently.

Exclude: nothing for public repos — this is a hard gate.

Severity: BLOCKER (public repo, no PR-only protection on `main`); INFO (private repo, as a
pre-public reminder, or when verification is not possible).

Added on 2026-06-05 per maintainer policy: public repos must have branch protection on `main`.

### 5.14 Same-target version bump across concurrently open PRs (HIGH under bump-per-PR policy)

Two or more in-flight branches each bump the manifest version to the IDENTICAL next
value. The hunks are identical, so whichever PR merges second rebases/merges cleanly
with ZERO version movement — silently violating a bump-per-PR policy, with no conflict
raised to force a human decision. The failure is invisible precisely because git sees
agreement where the policy sees collision.

Detection: when reviewing any PR in a repo with concurrent open PRs, diff each open
branch's manifest-version change against the shared base; identical target values
across two branches = finding on whichever lands second (or on both, pre-merge). Also
check the merged history: a merge commit whose PR claimed a bump but whose net version
delta vs its parent is zero confirms the collision already happened.

Exclude: repos without a bump-per-PR convention; lockfile-only version echoes.

Severity: HIGH where the repo mandates per-PR bumps (the history lies about what
shipped under which version); INFO otherwise.

Added by: oss-reviewer self-mutation on 2026-07-05 after charmander PRs #63 and #64
(plus #65), briefed in parallel from the same base, all took 0.22.0/0.17.0 while merged
PR #62 had already consumed pyproject 0.17.0 — every later-landing PR would have
shipped a silent no-op bump.

### 5.15 No `.gitignore` with build/IDE artifacts already sitting in the working tree (HIGH)

A repo has no `.gitignore` file at all (or one present but empty/trivial) while common
build/IDE/cache artifacts already exist on disk at review time: `.venv/`, `.idea/`,
`__pycache__/`, `.pytest_cache/`, `.coverage`, `node_modules/`, `dist/`, `build/`,
`.DS_Store`. This is the pre-commit sibling of §5.5 (which fires only once such
artifacts are already in `git ls-files`): in a repo that hasn't made its first commit
yet, or is about to, the absence of `.gitignore` means the very next `git add -A` (or
even a careless `git add .`) sweeps the author's local virtualenv, IDE config, and test
caches into version control permanently. Because the reviewer is often invoked exactly
at this pre-first-commit moment, catching the landmine before it's pulled is more
valuable than catching it after — the fix is a one-line `.gitignore`, but only if
someone looks before the first commit.

```bash
[ -f .gitignore ] && [ -s .gitignore ] || echo "no (or empty) .gitignore"
for d in .venv .idea __pycache__ .pytest_cache node_modules dist build .DS_Store .coverage; do
  [ -e "$d" ] && echo "present on disk: $d"
done
```

Exclude: repos with any non-trivial `.gitignore` present, even an imperfect one (that's
a curation-quality nit, not this finding); repos where none of the listed artifact
paths exist yet (nothing at risk of being swept in).

Severity: HIGH for a pre-first-commit (or pre-first-push) repo where the artifacts
already exist locally — the risk is imminent and the fix is trivial, so leaving it
unflagged wastes the one window where it's cheap to prevent. Downgrade to the §5.5
finding (still HIGH) once anything has actually been committed — at that point the
question is no longer prevention but cleanup (`git rm -r --cached` + add the ignore
file).

Added by: oss-reviewer self-mutation on 2026-07-19 after observing the `grimer` repo
review: no `.gitignore` anywhere in the tree while `.venv/`, `.idea/`, `__pycache__/`,
`.pytest_cache/`, and `.coverage` all sat in the working directory of a repo with zero
commits — the project's own `git status` already showed these as untracked, one
`git add -A` away from being permanently committed.

### 5.16 Single-PR version bump exceeds one minor step under a bump-per-PR semver policy (HIGH)

Under a "bump-per-PR" semver policy (see §5.14) that scales bump size to change type — patch
for a small fix, exactly one minor step for a feature/breaking/architectural change while a
package is on `0.y.z` — a single PR's version diff jumping by more than one minor step (e.g.
`0.3.0` -> `0.6.0`) for what the PR itself describes as one qualifying change is a policy
violation invisible to CI (nothing asserts the delta *size*, only that a version changed) and
invisible to a merge gate that only checks a version bump happened at all. It reads as one of:
the author bundled several would-be-separate bumps into a single PR, borrowed against
anticipated future work, or slipped when typing the number by hand. Each explanation means the
version number has stopped tracking "one bump = one shipped change," which is the entire point
of a bump-per-PR policy.

Detection: read the project's own versioning policy (a `## Versioning` section in `CLAUDE.md` or
equivalent, or the user's global policy if the repo doesn't override it). Diff the PR's manifest
`version` field against its merge-base value. Read the PR's own description to classify its
change(s) as patch vs one-minor-step-worthy. If the actual minor-version delta is more than 1
(or more than the count of distinct, individually-justified changes the PR body enumerates),
that gap is unexplained and is the finding.

```
# manifest version before (merge-base) vs after (PR HEAD)
version\s*=\s*"([0-9]+)\.([0-9]+)\.([0-9]+)"
```
Then compare `minor_after - minor_before` (or the major delta on a post-1.0 package) against 1
and against the number of distinct qualifying changes the PR body itemizes.

Exclude: repos with no documented bump-per-PR policy; PRs whose body itemizes N distinct
qualifying changes that together justify an N-minor jump; monorepo version fields tracking an
unrelated sub-package; the first version-bump PR after a period of unversioned commits (nothing
to diff against as "one prior bump").

Severity: HIGH when the policy is stated as binding/MUST (nothing else catches the drift — it's
a convention, not a CI check); INFO when the policy is advisory.

Added by: oss-reviewer self-mutation on 2026-07-22 after observing grimer PR #11 bump
`pyproject.toml` `version = "0.3.0"` -> `"0.6.0"` for one feature (universe-aware queries)
against the repo owner's global `CLAUDE.md` policy, which states a single `0.y.z` feature/
architectural change moves `y` by exactly 1 (expected `0.4.0`); the PR body describes only the
one change and does not itemize a second or third bump-worthy item.

### 5.17 Undocumented stateful-resource exhaustion makes a repeatable test suite look regression-prone (HIGH)

A test/e2e suite (or its documented prerequisite service) depends on a shared, per-process
stateful resource — a rate limiter, a request quota, a fixed-capacity in-memory cache — that is
NOT reset between suite runs. Nothing in the suite's own docs (README, CLAUDE.md, the suite's
own behaviour-contract doc) tells a contributor that running it more than once or twice in a row
against the same live process will start failing with errors that look exactly like a real
regression (e.g. HTTP 429s, quota-exceeded, cache-eviction thrashing) rather than an environment
exhaustion artifact. The suite is provably correct on a fresh process (clean run passes), so the
failure mode is invisible to the PR that adds the suite and only surfaces to the next contributor
who reruns it — at exactly the moment a suite billed as "a behaviour contract for N future
migration phases" most needs to be trusted.

Detection rule: identify the service(s) the test suite talks to (same repo or a documented
sibling repo). Grep their config for rate-limit / throttle / quota declarations and check whether
the backing store is process-local and non-resettable between test invocations (Django REST
Framework `DEFAULT_THROTTLE_RATES` + default `LocMemCache`, an in-process token bucket, a
fixed-size LRU with no per-test-run reset hook, etc.). Cross-check the test suite's own
docs (README "Running the suite" / "Prerequisites" section, CLAUDE.md, a `*_test_flow.md`
behaviour-contract doc) for any mention of the exhaustion mode, a restart/reset step, or a
"don't run this back-to-back" caveat. Its absence, combined with a confirmed stateful limiter in
the dependency graph, is the finding — independent of whether the limiter's own rate values are
reasonable.

```
# In the dependency's settings/config
DEFAULT_THROTTLE_RATES|RateLimiter|rate_limit|token_bucket|Bucket4j|slowapi
LocMemCache|in-memory cache|InMemoryCache
# In the suite's own docs -- absence of any of these is the gap
restart|reset|rate.?limit|throttl|429|quota exceeded
```

Exclude: suites whose docs already state the caveat and the recovery step; limiters backed by a
shared store that IS reset per test run (a Redis/Memcached instance flushed in suite setup);
suites where the dependency graph has no stateful limiter at all.

Severity: HIGH for a suite explicitly positioned as a regression gate for future work (the
undocumented flakiness erodes exactly the trust the suite exists to provide); INFO for an
ordinary dev-convenience suite where a false failure costs only the one contributor's time.

### 5.18 Migration/improvement-log doc cites a file path a later PR deletes (INFO / HIGH)

A narrative "what we fixed" doc (`improvements.md`, `MIGRATION.md`, a `## Resolved` changelog
section — not `CHANGELOG.md` itself, covered by §5.9) names a specific file path or exported
symbol as the artifact of a "Resolved" item ("Created a generic `useApi<T>()` hook", "**File:**
`src/hooks/useApi.ts`"). A later, unrelated cleanup PR deletes that file as dead code. Nobody
updates the migration doc, because it isn't linked from README.md or CLAUDE.md and nobody treats
it as living documentation — but it still sits in the repo root reading as current, and a
contributor who greps it for "how does API state management work here" lands on a path that
404s. The doc doesn't just go stale in prose (§5.9's marketing-phrasing case) — it makes a
falsifiable claim about the tree shape that the tree no longer supports.

Detection rule: extract every inline-code file path (`` `src/...` ``) from top-level narrative
`.md` files that read as historical reports (title/intro says "the following N items have been
resolved" or similar retrospective framing). For each, check the path exists at HEAD. A miss is
the finding. Cross-reference: if the diff under review is the one deleting the file, the drift is
introduced by *this* PR and is squarely in scope even under `--scope=diff`.

```
\*\*File:\*\*\s*`([a-zA-Z0-9_./-]+)`
`(src/[a-zA-Z0-9_./-]+\.(ts|tsx|js|jsx|py|go))`
```

Exclude: docs explicitly labelled as a point-in-time snapshot with a caveat that later PRs may
supersede them; entries describing a rename (not a deletion) where the new path is documented
alongside; `CHANGELOG.md` (§5.9 owns that file).

Severity: INFO when the doc is clearly a one-off historical report with no other living-doc
signals pointing at it. HIGH when the doc is linked from README.md/CLAUDE.md or otherwise
presented as current architecture reference — then the dead path actively misleads.

Added by: oss-reviewer self-mutation on 2026-08-01 after observing
`improvements.md:113` (references `reactSelectStyles`) and `improvements.md:133,146` (references
`src/hooks/useApi.ts` and lists "Hooks: useApi" as a tested item) in a PR (psyduck-fe #87) that
deletes `src/hooks/useApi.ts`, its test, and the `reactSelectStyles` prop/variable from
`AddAllergyForm.tsx`/`AllergiesSection.tsx` as dead code. `improvements.md` is not linked from
README.md or CLAUDE.md, so this graded INFO rather than HIGH.

Added by: oss-reviewer self-mutation on 2026-07-26 after observing the psyduck_frontend
PR #55 review: `psyduck_backend`'s `REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]` (`anon`
60/min, `user` 1000/hour, `public_profile` 30/hour) is backed by the default per-process
`LocMemCache` and is not stage-aware; three consecutive `npm run e2e` runs against the
same backend process produced cascading `429 Request was throttled` failures (by the
third run, even sign-in failed), while two runs after a backend restart were clean (9
passed, 9 passed). Neither `psyduck_frontend`'s README/CLAUDE.md/`ui_test_flow.md` nor
`psyduck_backend`'s own docs mention the throttle or the restart-to-recover step, so a
contributor rerunning the suite a few times sees what looks like a real regression.

### 5.19 Hedged closing keyword in a PR body still triggers GitHub's unconditional auto-close (CRITICAL)

A PR body uses a GitHub closing keyword (`closes`/`fixes`/`resolves` + `#N`) inside a
sentence that hedges the closure on a human condition — "Closes #N **if** review agrees
the evidence is sufficient; otherwise leave #N open" — intending the issue to stay open
pending a judgment call. GitHub's issue-linking parser has no concept of a conditional: it
matches the keyword immediately followed by the reference and links/auto-closes
regardless of what surrounding prose says. The author's careful hedge (often written
specifically because the fix is unconfirmed/hypothesis-only, per §5.17-adjacent honesty
concerns) is silently overridden the moment the PR merges — the issue closes even though
the PR's own text says it shouldn't, and nobody notices because the PR body *reads* as
appropriately cautious.

Detection rule: grep the PR body for a closing keyword followed by `#\d+` where the same
sentence also contains a conditional/hedge word (`if`, `unless`, `once`, `pending`,
`assuming`, `provided`, `only if`). For each match, confirm via the GitHub API whether it
actually registered as a closing reference:

```
gh api graphql -f query='
query { repository(owner: "OWNER", name: "REPO") {
  pullRequest(number: N) { closingIssuesReferences(first: 10) { nodes { number } } }
}}'
```

```
# In the PR body
\b(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#\d+[^.\n]{0,40}\b(if|unless|once|pending|assuming|provided)\b
```

If the queried issue number appears in `closingIssuesReferences`, the hedge is
cosmetic — merging closes the issue unconditionally. Exclude: PR bodies where the
hedge precedes the keyword+number in a way GitHub's regex can't match at all (rare —
verify empirically per the query above rather than trusting the regex alone, since
GitHub's exact matching behavior is undocumented and this pattern is best confirmed via
the live API call, not assumed from the prose shape).

Severity: CRITICAL. The whole point of the hedge is usually that the fix is
unconfirmed/hypothesis-directed (see the PR's own "could not reproduce" section) —
auto-closing the tracking issue anyway destroys the paper trail the hedge was written to
preserve, and does so silently since the merge itself gives no warning.

Added by: oss-reviewer self-mutation on 2026-08-02 after observing
`psyduck_backend` PR #39's body closing paragraph — "Closes #25 if review agrees the
evidence above is sufficient; otherwise treat as hardening and leave #25 open with this
PR's findings attached" — while `gh api graphql ... closingIssuesReferences` on the open,
unmerged PR already returns issue #25, proving GitHub parsed the hedge as a plain
unconditional close. The PR's own "Empirical verification" section explicitly states the
literal #25 symptom could not be reproduced, making the auto-close the opposite of what
the author's careful phrasing intended.

### 5.20 New operational script added to a documented scripts/ directory without a matching docs entry (INFO / HIGH)

A repo establishes the convention that every script under `scripts/` gets a one-line
(or multi-line usage block) entry in the project's own docs — typically a `## Commands`
section in `CLAUDE.md` and/or a dedicated section in `README.md` — for an *existing*
script (e.g. `scripts/dev-stack.sh` is listed with its flags in both places). A PR then
adds a **new** script to the same directory (`scripts/<new>.sh`) with its own `--help`
but never touches `CLAUDE.md` / `README.md` to add the matching entry. The new script
works fine standalone, so nothing breaks — but the docs now silently under-represent
`scripts/`, and the next reader following "the Commands section lists everything you can
run" as an implicit contract won't discover the new script exists at all.

Detection rule: `ls scripts/*.sh` (or the project's equivalent script directory), diff
against the set of script paths/basenames mentioned in `CLAUDE.md` + `README.md`. If at
least one existing sibling script IS documented (establishing the convention) and the
new script in the diff is absent from both docs, that asymmetry is the finding — not
merely "this script lacks docs" in isolation (a repo with zero documented scripts has no
convention to violate).

```
# Enumerate scripts on disk
ls scripts/*.sh
# Check each basename appears in the docs
grep -n 'scripts/<basename>' CLAUDE.md README.md
```

Exclude: scripts under `scripts/internal/` or similarly namespaced as
maintainer-only/non-user-facing if the project documents that convention; one-off
migration/backfill scripts clearly out of scope for a "Commands" list (judge via the
script's own `--help` framing — a script addressed to "the orchestrator" or "CI only"
is a weaker case for INFO rather than HIGH).

Severity: HIGH when the new script is user-invokable and mutates state (deploy,
delete, schedule) — a stranger has no way to discover it exists short of reading
`scripts/`. INFO when the script is read-only/reporting and low-stakes to miss.

Added by: oss-reviewer self-mutation on 2026-08-02 after observing
`scripts/kms-orphan-audit.sh` (PR adding a read-only + optional `--schedule-deletion`
KMS audit script) land with a complete `--help` block while `CLAUDE.md`'s `## Commands`
section documents `scripts/dev-stack.sh` (including all three of its flag variants) and
says nothing about the new script — the sibling-script convention is established but not
followed for the new addition.

### 5.21 PR body attributes an unmet acceptance criterion to an out-of-scope note that names a different metric (HIGH)

A PR misses an explicit numeric acceptance criterion and explains the residual by citing the
issue's Out of Scope section, but that section, read directly, scopes a different metric or
fixture. The inference may be honest (the same cost explains both gaps), but a reader who does
not open the issue takes a required target for a pre-approved scope cut.

Detection: for every "out of scope per issue #N" claim, fetch the issue body and match the
named metric and fixture against the one the criterion required. A mismatch is the finding even
when the numbers are reported accurately.

```
issue #\d+('s)?\s+(own\s+)?out.of.scope
```

Exclude: a paraphrase for the same metric the note was written about; prose that states the
inference as inference ("the same class of cost the note names for the other fixture").
Fix: state the residual's cause and the tracking issue that owns it; drop the claim of coverage.

### 5.22 PR body claims a divergence is "documented in <file>" but the file has no such content (HIGH)

For each "documented in `<file>`" claim in a divergence, limitation or triage section, extract
two or three words the content would have to contain (the mechanism, the value class, the bound)
and grep the referenced file at the PR head. Zero hits is the finding: a dead pointer that a
reader trusts, and often an undocumented nuance the project's own policy forbids.

```
document(ed)? in `([a-zA-Z0-9_./-]+\.md)`
```

Exclude: a file the PR does not touch that already covered the divergence before the PR.

### 5.23 PR or commit body uses a word the project's binding attribution policy bans (HIGH)

Read the project's own binding policy for its enumerated ban list and grep the PR body and the
new commit messages for each term as a whole word. "Gate" restating an internal threshold
("≥95 gate") is the common leak. Exclude pre-existing source usage outside the diff and accepted
code identifiers.

```
\b(gate|orchestrat\w*|agent|subagent|implementer|pipeline)\b
```

### 5.24 A binding "update both companion docs" rule is satisfied at only one location (HIGH)

For each project rule phrased "update both X and Y in the same commit", check the PR's
changed-file list for both named locations whenever the PR triggers the rule's condition.
One present and one absent is the finding even when the updated one is correct.

```
update both .* and .*, the two places
in the same commit, (restate|update) .* and .*
```
