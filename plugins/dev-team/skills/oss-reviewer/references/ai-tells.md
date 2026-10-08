# AI-generated-code tells — pattern catalog (Phase 4)

Companion reference for the `oss-reviewer` skill. Loaded on demand during Phase 4.
Each pattern: regex or structural rule + exclude list + severity + rationale.
Self-mutation additions land HERE (see the numbering rule in SKILL.md): grep this
file for the highest existing `### 4.N` and use N+1 — never reuse a number.

Every pattern excludes this catalog's own quoted examples under `references/` and the skill text. Entries 4.1, 4.26, 4.36, 4.86, 4.87, 4.109, 4.110, 4.112, 4.114, 4.115, 4.118, 4.119, 4.122, 4.126, 4.131, 4.132 and 4.141 were widened on 2026-10-07.

This is the core mandate. Grep the working tree for the patterns below. For each match, capture `<file>:<line>` + the matched snippet so the user can navigate.

### 4.1 Task-referential leftovers (CRITICAL)

These are the strongest AI-session tells. Any one of them is a CRITICAL finding.

Regex (case-insensitive where natural):
```
§\d+(\.\d+)*                          # "§4.10", "§3.2"
TODO\s*§\d                            # "TODO §4.10"
(per|as per|per the)\s+brief          # "per the brief", "as per the brief"
(per|as)\s+(the|this)\s+spec          # "per the spec", "as this spec"
TODO\s+from\s+(brief|spec|task)
in\s+(this|the|the\s+next)\s+PR
this\s+PR\s+lands
land(s|ed)?\s+in\s+§
will\s+land\s+in\s+§
deferred\s+to\s+§
the\s+issue\s+(asks?|says|requires?|specifie[sd]|calls?\s+for)   # unnumbered tracker appeal; a numbered #N cite is INFO
the\s+issue's\s+\w+
(claude|gpt|gemini|copilot|cursor)-(generated|coded)
generated\s+by\s+(claude|gpt|chatgpt|gemini)
🤖\s+Generated\s+with\s+\[Claude\s+Code\]
```

Note: the `🤖 Generated with [Claude Code]` footer is **acceptable in commit messages and PR descriptions** but is a finding if it appears in source files or docstrings.

Join lines first (`tr '\n' ' '`) so a phrase split across a comment line, `per the` / `brief` included, still matches. Also match (case-insensitive):
```
issue #[0-9]+'s\s+.{0,20}requirement
acceptance example|this issue is about
```

### 4.2 Crumb TODOs / FIXMEs in source (CRITICAL)

Any of these patterns in `.py` / `.ts` / `.js` / `.go` / `.rs` / etc. files:
```
^\s*#\s*TODO[:\s]
^\s*#\s*FIXME[:\s]
^\s*#\s*XXX[:\s]
^\s*#\s*HACK[:\s]
^\s*//\s*TODO[:\s]
^\s*//\s*FIXME[:\s]
^\s*/\*\s*TODO
```

Exclude:
- Files matching `**/tests/**` or `**/test_*.py` (test fixtures sometimes use TODO comments intentionally).
- Files in `.gitignore`.
- Files matching `**/docs/**` (documentation can legitimately list TODOs).

Severity: each match is CRITICAL. AI sessions love to leave breadcrumbs; production code should not.

### 4.3 Defensive-for-impossible-cases (HIGH)

Patterns that suggest defensive code for cases that can't actually occur:

```
except\s+Exception\s*:\s*pass         # bare swallow
except\s*:\s*pass                     # bare except
try:[\s\S]{1,200}except\s+\w+:\s*pass # silent except
^\s*assert\s+\w+\s+is\s+not\s+None   # narrowing assert IF the value
                                      # was just returned from a typed call
```

For the narrowing-assert case, project-specific exemption may apply (see Project context section above). Flag with severity HIGH and a hint that the user check the surrounding context.

### 4.4 Narration-of-the-obvious comments (HIGH)

```
^\s*#\s*Increment\s+\w+\s+by\s+\d+
^\s*#\s*Set\s+\w+\s+to\s+\w+
^\s*#\s*Return\s+the\s+\w+
^\s*#\s*Loop\s+through\s+\w+
^\s*#\s*Check\s+if\s+\w+
^\s*#\s*Initialize\s+\w+
^\s*#\s*Iterate\s+over\s+\w+
^\s*#\s*Call\s+\w+
```

Severity: HIGH. These are the Claude-Code tic where every line gets a leading explanatory comment.

### 4.5 Helpfulness verbosity (HIGH)

```
^\s*#\s*Certainly[!,]
^\s*#\s*Note\s+that
^\s*#\s*As\s+(requested|noted)
^\s*#\s*I'?ve\s+(done|added|implemented)
^\s*#\s*We'?ll\s+need\s+to
^\s*#\s*Let'?s\s+(also|now)
^\s*"""\s*Certainly[!,]
```

Severity: HIGH. These are conversational fragments that leaked from a chat into source.

### 4.6 Mixed-style tells (INFO)

Inconsistency within a single file:

- **`Optional[T]` AND `T | None`** in the same file (Python). Pick one. Flag the file.
- **f-strings AND `%`-formatting AND `.format()`** in the same file. Pick one.
- **`@dataclass` AND `attrs.define`** in the same file. Pick one.
- **`Dict[K, V]` AND `dict[K, V]`** in the same file (Python 3.9+ syntax mixing).
- **`from typing import ...` AND `from typing_extensions import ...`** for the same name.

Severity: INFO. Style consistency is a taste thing; flag for triage.

### 4.7 Stub-shaped scaffolding (HIGH)

```
^\s*def\s+\w+\([^)]*\)\s*->\s*[^:]+:\s*$   # function with annotation but no body following
^\s*pass\s*$                                # bare pass after function def
^\s*\.{3}\s*$                                # bare ellipsis (in non-Protocol context)
^\s*raise\s+NotImplementedError\(\s*\)      # NotImplementedError without a message
```

Severity: HIGH for `NotImplementedError()` without a message; INFO for `pass` / `...` since these are legitimate in Protocols.

### 4.8 Configuration scatter (HIGH)

Configs scattered instead of grouped. Specifically:

- Multiple `os.environ.get(...)` calls across more than 3 files without a central config module / class.
- Hardcoded magic numbers (`max_retries=3`, `timeout=30`) repeated in 3+ files.
- Hardcoded URLs / endpoints in 3+ files.

Heuristic: run `grep -rn 'os.environ.get' src/` (or equivalent), tally by file. If > 3 files independently read env vars without a `config.py` / `settings.py` / equivalent, flag.

Severity: HIGH. Configuration spread is the canonical "AI generated each file independently" tell.

### 4.9 Tight-coupling refactor-blockers (HIGH)

- Direct instantiation of concrete classes where an interface would do (e.g. `PostgresBackend()` hardcoded in 5+ places instead of routing through an entry-point registry).
- Cross-module imports that violate layering (e.g. `pag.connectors` importing from `pag.cli`).
- Hardcoded file paths (`/Users/...`, `C:\\Users\\...`) in source.

Severity: HIGH. These create extension blockers that need big refactors to remove.

### 4.10 Prose tells in docstrings + README (INFO unless egregious)

Adapted from `jalaalrd/anti-ai-slop-writing`:

Banned vocabulary in docstrings + README:
```
delve|tapestry|landscape|testament|vibrant|pivotal|nuanced|seamless|robust\s+and|comprehensive\s+and|leverage(?!\s+the\s+existing)
```

Phrase tells:
```
It'?s\s+(worth|important)\s+to\s+note
In\s+(today's|the)\s+(competitive|fast-paced|ever-evolving)
This\s+(elegant|robust|comprehensive)\s+(solution|implementation|approach)
(Moreover|Additionally|Furthermore|Subsequently),\s+\w+
```

Severity: INFO. These are weak signals — a real human writes "robust" sometimes. Three or more independent matches in one document = HIGH.

### 4.11 Whole-file read pass (BINDING)

The grep pass in 4.1–4.10 catches surface signals. It misses:

- Module-level architecture smells that don't fit a regex (a 300-line "god module" that should be three smaller ones).
- Files whose existence is its own finding — generators, stubs, half-finished experiments, dead drop-ins.
- Inter-section structural inconsistencies (a class that uses both `@property` and bare attribute access for the same logical field).
- Files where the docstring lies about what the file does (says "tests for X" but only tests Y).
- Files that are exact or near-duplicates of each other modulo identifier renames.
- Files whose code style swerves halfway through (first half snake_case, second half camelCase).

**Read every source file in full.** Not just the diff. Use the `Read` tool for each file matching `glob('src/**/*.py')` (or the project's source-language equivalent — `src/**/*.{ts,go,rs}` etc.). Per file, ask:

1. **Does this file have an active purpose?** A `utils.py` containing one function used in one place is a smell. A `helpers/__init__.py` re-exporting things from a single sibling module is a smell. Flag files that could be merged into another file or deleted outright with no information loss.

2. **Is the file internally consistent?** Style, naming, ordering, idiom. A class whose private methods use `_lead_underscore` while its public methods use no underscore is the expected pattern; a class that mixes both within one section, or whose private/public split is randomly scrambled, is a smell.

3. **Does the file's docstring match its contents?** If the docstring says "tests for the LISTEN/NOTIFY trigger" but the file's tests cover the unrelated DSN-conversion helper, the docstring is wrong AND someone forgot to move the tests. Both are findings.

4. **Is the file accidentally split?** Two modules where one would do — `foo_helpers.py` + `foo_utils.py` + `foo_misc.py` is a smell, especially if each is < 50 lines.

5. **Is the file's structure load-bearing or cargo-cult?** Multi-`#` separators are fine (project-specific exemption). Section comments that mark "Initialization" / "Helpers" / "Main logic" on a 40-line file are not — they're scaffolding the AI left behind.

6. **Does the file have any code paths that look right but can't ever execute?** Defensive guards, fallbacks for impossible inputs, except-clauses for exceptions the calling code can't raise.

7. **Is the file's complexity proportional to its job?** A connector that's three times the size of the protocol it implements is a smell — usually means premature configuration parameters, dead branches, or commented-out experiments.

Each finding is captured with `<file>:<line(s)>` + a one-sentence "why" + a suggested fix. Severity is **HIGH** by default; if the reviewer is confident the file is dead code or the smell is structural, escalate to **CRITICAL**.

**Budget guidance**: this is the most expensive phase. For repos with > 200 source files, read every file in the public API surface (entry points, exported classes, things the README references) — comprehensive — and SAMPLE the rest at 1-in-5. Note in the report which files were read fully vs sampled.

Do NOT skip this phase. The grep-based heuristics catch ~70% of AI-tells; the whole-file read catches the structural 30% that decide whether the project looks like a person's work or a transcript.

### 4.12 Hardcoded developer identity in IaC source (BLOCKER)

CDK / Terraform / Pulumi stacks that bake the author's IAM username, account number, or personal ARN directly into the stack body — not exposed as a prop — break the quickstart for every user who isn't the author.

```
arn:[^"'`]*:iam::[^"'`]*:user/[A-Za-z0-9_.-]+
arn:[^"'`]*:iam::[0-9]{12}:(user|role)/[A-Za-z0-9_.-]+
new\s+ArnPrincipal\(\s*[`'"]arn:[^"'`]*:iam::[^"'`]*:(user|role)/[a-z]+
```

Exclude: code under `**/test/**` (fixture ARNs are fine); ARNs that interpolate a prop / context value (`${props.foo}`, `${context.foo}`).

Severity: BLOCKER when the hardcoded identity is on the stack's deploy path (Lake Formation admin, S3 bucket policy principal, IAM-grant target) — the deploy will fail for any other user. CRITICAL when it's behind a feature flag or unused branch. HIGH for an ARN buried in a default value with a clear `// override me` comment.

Added by: oss-reviewer self-mutation on 2026-05-23 after observing
`lib/arceus-stack.ts:57` — `new ArnPrincipal(\`arn:${this.partition}:iam::${this.account}:user/rodrigo\`)` hardcoded into the Lake Formation admin list of a demo CDK stack whose README invites strangers to `cdk deploy ArceusStack`.

### 4.13 "This is the description." placeholder strings (CRITICAL)

String literals whose content is a filler description the author meant to fill in later. These ship with the construct because nobody re-reads CFN/Glue/RDS property strings during review.

```
["'`](?:This is (?:a|the|my|some|just)|TODO[: ]|placeholder|example description|sample (?:text|description)|description here|insert .* here|change me|fixme)[^"'`]*["'`]
```

Exclude: anything under `**/test/**` or `**/__fixtures__/**` (fixtures legitimately use placeholders); strings that are clearly internal IDs / keys (e.g. `'placeholder-key'` used as a Map key).

Severity: CRITICAL. The literal `'This is the description.'` shipping in a Glue `Database` description field is a documentation-equivalent slop: AI scaffolding the author forgot to fill in.

Added by: oss-reviewer self-mutation on 2026-05-23 after observing
`lib/arceus-stack.ts:214` — `description: 'This is the description.'` shipping as the live Glue database description on a public-facing demo stack.

### 4.14 Caller-ARN shell-parsing in quickstart (HIGH)

README quickstarts that derive an identifier from `aws sts get-caller-identity --query Arn --output text` via shell string-slicing (`awk -F/ '{print $NF}'`, `cut -d/`, `sed 's|.*/||'`, etc.) work for the author (who is usually a literal IAM user, ARN shape `arn:...:iam::ACCT:user/NAME`) and silently produce garbage for any caller using SSO or an assumed role (ARN shape `arn:...:sts::ACCT:assumed-role/ROLE/SESSION` — the trailing field is the session, not a usable identity).

```
aws\s+sts\s+get-caller-identity[^|]*\|[^\n]*\b(awk|cut|sed)\b[^\n]*\b(/|F/|-d/)
```

Exclude: scripts whose surrounding text explicitly asserts the user is an IAM user (e.g. inside a `## For IAM-user callers only` heading), or pipelines that parse `--query 'Arn'` to extract `iam::ACCT:user/NAME` substring with `grep -oE 'user/[^[:space:]]+'` (this fails closed for non-user callers).

Severity: HIGH. Quickstart silently produces a wrong-but-plausible value, the downstream resource (LF principal, IAM grant, KMS key policy) accepts the wrong value at synth time, and the failure surfaces only at deploy time as a cryptic `Principal not found`. Flag whenever the one-liner is documented as a default and the README doesn't gate it on caller type.

Added by: oss-reviewer self-mutation on 2026-05-23 after observing
`README.md:55` — `DEVELOPER_IAM_USER="$(aws sts get-caller-identity --query Arn --output text | awk -F/ '{print $NF}')"` works for the author (IAM-user `rodrigo`) and would produce `session-name` for any SSO caller, silently breaking the LF deploy.

### 4.15 Stale test-output transcript pasted into README (CRITICAL)

READMEs that paste a literal `npx jest` / `pytest` / `cargo test` transcript ("Tests: 167 passed", "Statements: 100% (411/411)") drift the first time the test suite grows. The author updates the suite, the transcript doesn't, and a stranger comparing the README to a fresh run sees a lying document. The pattern is identifiable as any line of the form `Tests:\s+\d+\s+(passed|failed)` or `(Statements|Branches|Lines|Functions)\s*:\s*\d+%?\s*\(\s*\d+/\d+\s*\)` inside README.md.

```
Tests:\s+\d+\s+(passed|failed|total)
(Statements|Branches|Lines|Functions)\s*:\s*\d+(\.\d+)?%?\s*\(\s*\d+\s*/\s*\d+\s*\)
Test Suites:\s+\d+\s+passed
\d+\s+passed,\s+\d+\s+total
```

Exclude: example-output blocks that are explicitly labelled "example" / "sample" / "approximate" in the surrounding prose; coverage *thresholds* (e.g. "the 95% coverage floor is enforced in `jest.config.js`") which are config-driven invariants, not transcripts.

Severity: CRITICAL when Phase 1 ran the same command and produced different numbers (the README is provably wrong); INFO if Phase 1 couldn't run the command and the transcript can't be falsified. The fix is either to drop the numbers ("`npx jest` — see jest.config.js for the coverage floor") or replace the transcript with a CI badge whose value floats.

Added by: oss-reviewer self-mutation on 2026-05-30 after observing
`README.md:64` / `README.md:508-514` — claims `167 tests, 100% line coverage` and pastes a `Tests: 167 passed, 167 total / Statements: 100% (411/411) / Branches: 100% (146/146) / Lines: 100% (408/408)` transcript while Phase 1's `npx jest` reports `184 passed, 184 total / 479/479 / 223/223 / 477/477`. The jsii-compatible-types PR added 17 tests and the numbers were never updated.

### 4.16 GitHub fragment URL pointing at a non-existent comment / review / commit ID (CRITICAL)

GitHub host: READMEs that link to a specific GitHub artifact via fragment (`#issuecomment-NNN`, `#pullrequestreview-NNN`, `#discussion_r-NNN`, `#commit-SHA`) will silently soft-fail when the fragment ID is wrong: GitHub returns HTTP 200 for the parent issue / PR page, the fragment scrolls nowhere, and the reader lands at the top of an unrelated long thread instead of the artifact the prose just promised. `curl -I` cannot catch this — the parent URL is always 200. The check has to hit the GitHub API and confirm the artifact exists.

```
https?://github\.com/[^/\s)]+/[^/\s)]+/(issues|pull)/\d+#(issuecomment|pullrequestreview|discussion_r)-\d+
https?://github\.com/[^/\s)]+/[^/\s)]+/commit/[0-9a-f]{7,40}
```

Verification rule: for each match, extract `(owner, repo, kind, number, fragment_id)` and call:
- `gh api repos/<owner>/<repo>/issues/comments/<fragment_id>` for `#issuecomment-`,
- `gh api repos/<owner>/<repo>/pulls/<number>/reviews/<fragment_id>` for `#pullrequestreview-`,
- `gh api repos/<owner>/<repo>/pulls/comments/<fragment_id>` for `#discussion_r-`,
- `gh api repos/<owner>/<repo>/commits/<sha>` for `/commit/`.

A 404 from the API is the finding. As a fallback when the fragment ID is unguessable, list all comments on the parent issue (`gh api repos/<owner>/<repo>/issues/<number>/comments --paginate --jq '.[].id'`) and grep for the ID — its absence is the finding.

Exclude: links whose surrounding prose explicitly names the parent issue/PR as the target (e.g. "see the discussion on aws/aws-cdk#29660" — no fragment); fragment IDs interpolated from a script (`#issuecomment-${ID}`).

Severity: CRITICAL. The README prose makes a specific claim ("manmartgarc's comment documents the only working shape") and the link delivers a different artifact (or nothing). A reader following the link sees a 600-comment thread, not the claimed evidence, and the document silently loses credibility.

Added by: oss-reviewer self-mutation on 2026-05-30 after observing
`README.md:10` — `[\`manmartgarc\`'s comment](https://github.com/aws/aws-cdk/issues/29660#issuecomment-3243988858)`. `gh api repos/aws/aws-cdk/issues/comments/3243988858` returns 404; the actual manmartgarc comment on issue 29660 is id `4411359248`. The round-4 fix that introduced this permalink shipped pointing at a comment ID that does not exist.

### 4.17 Lint script wired to a tsconfig that excludes lintable files (CRITICAL)

`package.json` exposes `"lint": "eslint . --ext .ts"` (or equivalent) and `eslint.config.{js,mjs}` configures the `@typescript-eslint` parser via `parserOptions.project: './tsconfig.json'`. The lint step then walks every `.ts` file in the tree but the TypeScript parser fails on any file not in the tsconfig `include:` set with `Parsing error: ... that TSConfig does not include this file`. This breaks the moment `tsconfig.json` `include:` is narrowed for publishing (e.g. to `lib/iceberg/**/*.ts` only) without also (a) updating the lint glob to match, (b) creating a `tsconfig.eslint.json` that covers everything lint touches, or (c) using `EXPERIMENTAL_useProjectService` / `project: true` to auto-resolve. Tests + build pass green; `npm run lint` (and any CI step that runs it) fails red on every push.

Detection rule: open `package.json`, find the `lint` script. If it runs `eslint` on `.` or `**` or `src` or any directory broader than the tsconfig `include:`, open the eslint config and look for `parserOptions.project`. If that points at a tsconfig whose `include:` is narrower than the directories the lint script walks, the lint will fail. Fastest confirmation: actually run `npm run lint` in the fresh clone (Phase 1 already requires `npm install`; one more script invocation is cheap) — the parse error is unmissable.

```
# In package.json
"lint":\s*"eslint\s+\.[^"]*"
# In eslint.config.*
parserOptions:\s*\{[^}]*project:\s*['"]\./tsconfig\.json['"]
# In tsconfig.json
"include":\s*\[[^\]]*"lib/[a-z_-]+/\*\*/\*\.ts"[^\]]*\]
```

Exclude: monorepos with one tsconfig per package and matching per-package lint scripts; projects whose lint config explicitly sets `parserOptions.project: false` for non-tsconfig files; projects with a separate `tsconfig.eslint.json` referenced from the eslint config.

Severity: CRITICAL. The repo claims to be publish-ready (CI workflow runs lint+test+build+pack); CI fails on first push. The fix is one of: widen `tsconfig.json` `include:` and use a separate `tsconfig.build.json` for the publish path, OR add `tsconfig.eslint.json` whose `include:` covers everything lint walks, OR scope the lint script to the same directories the tsconfig covers.

Added by: oss-reviewer self-mutation on 2026-05-30 after observing
`tsconfig.json:30` (`"include": ["lib/iceberg/**/*.ts"]`) + `eslint.config.js:86` (`project: './tsconfig.json'`) + `package.json:39` (`"lint": "eslint . --ext .ts,.tsx ..."`) + `.github/workflows/ci.yml:19` (`- run: npm run lint`). `npm run lint` in the fresh clone errors out with 9 "TSConfig does not include this file" parse errors covering `bin/`, `lib/arceus-stack.ts`, `lib/iceberg-evolution-stack.ts`, and all 6 test files. The publishing commit narrowed the tsconfig for the build path but did not also narrow the lint script — and the CI workflow was added in the very next commit to invoke that lint script unconditionally.

### 4.18 README install command for a package that isn't on the registry yet (CRITICAL)

READMEs that present `npm install <name>` (or `pip install <name>`, `cargo add <name>`, `gem install <name>`, `go get <module>`) as the first user-facing instruction work only if `<name>` is actually published. Pre-tag-push releases, hijacked package names, typo-squat fixes, and unpublished betas all leave the install command 404ing while the README confidently advertises it. The shields.io badges in the README header (`https://img.shields.io/npm/v/<name>.svg`) make this even more visible — they render "package not found" rather than a version number, and the document looks publicly broken.

Detection rule: pull the package name from the README's first install code block AND from any shields.io badge URL of the form `img.shields.io/{npm,pypi,crates}/v/<name>`. Hit the corresponding registry endpoint:
- `https://registry.npmjs.org/<name>` for npm (200 with JSON when published; 404 when not)
- `https://pypi.org/pypi/<name>/json` for PyPI
- `https://crates.io/api/v1/crates/<name>` for crates.io
- `https://rubygems.org/api/v1/gems/<name>.json` for RubyGems

A 404 means the install command in the README is currently a lie. Cross-check with the local `package.json` / `pyproject.toml` `version` field: if it's `0.1.0` or `0.0.1` and the registry returns 404, this is the canonical "pre-publish, README written for post-publish state" pattern.

```
# Find the install command in README
npm install\s+([a-z0-9@/-]+)
pip install\s+([a-z0-9_.-]+)
cargo (?:add|install)\s+([a-z0-9_-]+)

# Find the shields badge name
img\.shields\.io/(npm|pypi|crates)/v/([a-z0-9_.-]+)
```

Exclude: install commands for known-private scoped packages (`@org/name` where `org` is the user's private scope) — the registry will 404 to an unauthenticated reviewer but legitimately resolve for the project's users; READMEs whose surrounding prose explicitly says "this package is not yet published; install from source via ..." right before the install block.

Severity: CRITICAL when the README presents itself as a published library (badges, npm-install headline, no "not yet published" disclaimer) and the registry 404s. INFO if the README clearly stages itself as a release candidate. The fix is either (a) publish the package, (b) add a disclaimer ("0.1.0 will be published when [PR/issue] lands; meanwhile install from git"), or (c) defer adding the install block until the first tag is pushed.

Added by: oss-reviewer self-mutation on 2026-05-30 after observing
`README.md:24-28` — `npm install cdk-glue-iceberg-table` shipping as the headline install command while `https://registry.npmjs.org/cdk-glue-iceberg-table` returns 404 and the two shields.io badges in the header render "package not found". The publish workflow (`.github/workflows/publish.yml`) is wired to publish on `v*.*.*` tag push, but no tag has been cut yet — the README is written for the post-publish state while the package is still pre-publish.

### 4.19 Sycophancy + AI scratchpad markers in source (CRITICAL)

Comments containing conversational fragments AI emits when conceding to user pushback, or planning markers from the agent's scratch space, leaking into committed source.

```
(#|//)\s*(you'?re (absolutely )?right|good (catch|point)|great (catch|point|question)|apologies|my apologies|let me (fix|adjust|update)|i see (the issue|what (you mean|happened))|sorry for the (confusion|oversight))\b
(#|//)\s*(todo\(claude|todo\(ai|note for (the|future|next) ai|i'?ll (come back|revisit)|approach:|plan:|strategy:)\b
```

Exclude: documentation files capturing code-review threads (e.g. `docs/reviews/`); test fixture strings containing sample dialogue.

Severity: CRITICAL. Near-zero false-positive rate. Sycophancy phrases are leftovers from a chat reply pasted into the wrong place; planning markers are the AI's literal scratchpad.

Added by: research synthesis on 2026-05-23.

### 4.20 Numbered-step narrative comments in implementation code (HIGH)

A single function body containing 3+ sequential `# Step 1:` / `# Step 2:` / `# Step 3:` markers as a structural comment scheme.

```
(?m)^\s*(#|//)\s*Step\s+\d+\s*[:.\-]
```

Threshold: 3+ matches within ~50 lines.

Exclude: tutorial code in `**/examples/**`, `**/docs/**`, README code blocks, files named `*_tutorial.*` / `*_walkthrough.*`.

Severity: HIGH. Humans break sequential logic into named functions; AI breaks it into numbered comments inside one function — the "disguised listicle" fingerprint.

Added by: research synthesis on 2026-05-23.

### 4.21 Status emojis in production print / log statements (HIGH)

Print / log calls embedding celebratory or status emojis in production source.

```
(print|console\.\w+|log\w*|logger\.\w+)\s*\(\s*[fF]?["'`][^"'`]*(✅|❌|🚀|✨|🎉|⚠️|🔥|📦|🔧|🔍|💾|⏳)
```

Exclude: CLI front-ends that explicitly use Rich / Ink / Chalk for terminal UX (verify via dep in `pyproject.toml` / `package.json`); `**/examples/**` and `**/demos/**`; `__main__.py` / `cli.py` banner code.

Severity: HIGH. Production logs do not need rocket emojis. Tutorial-style print noise is a Claude / Cursor fingerprint.

Added by: research synthesis on 2026-05-23.

### 4.22 Test-suite anti-patterns (CRITICAL)

Three test smells that all produce tests that always pass regardless of correctness. Each is independently CRITICAL.

**a. No-assertion tests.** `def test_*` function whose AST body contains zero `assert` statements, zero `pytest.raises`, zero `mock.assert_*` / `assert_called_*` calls, and zero `self.assert*` calls. The test "passes if no exception" — the contract is unchecked. Same shape in JS / TS: `it()` blocks with no `expect()`.

**b. Tautological tests.** `assert sut(args) == sut(args)` — SUT compared against itself. Detection: AST `Compare` nodes where `left` and `comparators[0]` are syntactically identical `Call` expressions.

**c. Self-mocked SUT.** A test mocks the very function it claims to test (`@patch("foo.bar")` decorating `test_bar`). The "passing" assertion verifies the mock returned what the test programmed it to return.

Exclude: smoke tests explicitly named `test_smoke_*` / `test_imports_*`; determinism / idempotency tests named `test_*_idempotent` / `test_*_deterministic`; tests that mock a helper called by the SUT (legitimate).

Severity: CRITICAL. Each shape produces false coverage that masks regressions and inflates the coverage signal.

Added by: research synthesis on 2026-05-23.

### 4.23 Manager / Helper / Service noun-suffix proliferation (HIGH)

Class names ending in `Manager`, `Handler`, `Helper`, `Utility`, `Utils`, `Service`, `Wrapper`, `Processor`, `Orchestrator`, `Coordinator` where the class has ≤2 public methods.

```
class\s+\w+(Manager|Handler|Helper|Utility|Utils|Service|Wrapper|Processor|Orchestrator|Coordinator)\b
```

Combine with AST: count non-underscore methods. Flag classes with ≤2 public methods; escalate to CRITICAL for 0 public methods (noun-as-namespace).

Exclude: framework-mandated names (Django `Manager`, Spring `@Service`, AWS SDK `*Service`, JPA `*Repository`); projects where `services/` is documented architectural convention with curated members.

Severity: HIGH. The "AI-Java" tic — wrap every operation in a noun-suffixed class. Senior engineers prefer free functions or domain-named modules.

Added by: research synthesis on 2026-05-23.

### 4.24 Comment-to-code ratio outlier in internal modules (HIGH)

Source files where `(comment lines + docstring / doc-comment lines) / total non-blank lines > 0.4` AND the file is NOT a public API surface, NOT a tutorial / example, NOT an `__init__.py`.

Detection: per-file count via tokenizer / AST, or `grep -cE '^\s*(#|//|///|//!|\*|"""|/\*)'` against `grep -cvE '^\s*$'`. Any language: `#`, `//`, `///`, `//!`, `/* */`, `"""`. Flag every file exceeding the ratio, whatever directory it sits in.

"Public API surface" means a file whose exported items are consumed outside the package or crate. A module inside a library whose items are private, `pub(crate)`, or `_underscored` is internal even when the crate itself is a published library; a `lib.rs`/`__init__.py` re-exporting it does not make its internals public.

Exclude: public API modules consumed downstream; `examples/` and `tutorials/`; educational `#!`-shebang scripts; auto-generated code (`# generated by`, `*_pb2.py`).

Severity: HIGH. > 40% comments in internal code is the AI "explain every line" fingerprint. Industry catalogs consistently list over-commenting as the #1 LLM anti-pattern.

Added by: research synthesis on 2026-05-23.

### 4.25 Docstrings restating the function signature verbatim (HIGH)

Docstrings whose parameter descriptions are just the parameter name + type + filler verb. Treats docstrings as a typing exercise instead of intent documentation.

Sphinx-style:
```
:param\s+(\w+):\s*(the|a|an|input|inputs?|parameter|value)\s+\1\s*\.?\s*$
:param\s+(\w+):\s*\1\s+(value|parameter)\s*\.?\s*$
:return:\s*(the|a|an)\s+(value|result|output)\s*\.?\s*$
```

Numpy / Google style: param description ≤4 words AND contains the param name or its declared type.

Per-file rule: flag files where >30% of public functions match.

Exclude: `Protocol` / `@abstractmethod` definitions where restatement is the contract; auto-generated stub modules.

Severity: HIGH. Restated docstrings add zero information; the pattern signals docstrings were filled mechanically rather than by an author with intent.

Added by: research synthesis on 2026-05-23.

### 4.26 Identical multi-line file-header docstring template (HIGH)

Every (or most) source file in a package opens with the same multi-line module docstring template, varying only by module name.

Detection: extract top-level module docstring from every `.py` / `.ts` / `.go` file. Compute pairwise similarity (Jaccard on tokens, or normalized Levenshtein) ignoring module-name substitution. Flag if ≥3 files share ≥80% structural similarity in their first 5 docstring lines.

Exclude: auto-generated code (`# generated by`, `*_pb2.py`, files leading with `<auto-generated />`); projects whose CLAUDE.md mandates a specific docstring template (then it's convention).

Severity: HIGH. Humans don't rubber-stamp every file with the same multi-line header. The residue of "run Claude across the folder to add docstrings everywhere."

Added by: research synthesis on 2026-05-23.

Also counts: the same doc sentence on three or more helpers in one file; a two-file template pair restating a third file; four sibling item docs that differ by one word.

### 4.27 `if __name__ == "__main__":` demo blocks in library modules (INFO)

A file with an `if __name__ == "__main__":` demo / smoke-test at the bottom, where the file is imported elsewhere in the package (not an entry point).

```
\nif\s+__name__\s*==\s*["']__main__["']:
```

For each match, skip if the filename is `__main__.py`, `main.py`, `cli.py`, `app.py`, `run.py`, or lives in `bin/` / `scripts/`. Otherwise grep the package for `from <thismodule> import` — if any callers exist, the demo block is tutorial leakage.

Exclude: scripts, CLI entry points, explicit `examples/` directory contents.

Severity: INFO. The AI's "and here's how you'd use this" footer learned from blog posts. Not damaging but a tell.

Added by: research synthesis on 2026-05-23.

### 4.28 Single-use over-typed private helpers (INFO / HIGH at cluster)

`_private` helpers with full type annotations on a 1-3 statement body, called exactly once in the same file.

Detection (AST): for each function matching `_[a-z_]+`:
1. ≤3 statements in body.
2. All parameters typed AND return type annotated.
3. Called exactly once in module.

Exclude: `@staticmethod`, `@classmethod`, `@property`, `@functools.lru_cache`-decorated (caching may require isolation); hot-path helpers in performance-critical modules.

Severity: INFO per occurrence; HIGH when a single file has ≥3 such helpers.

Added by: research synthesis on 2026-05-23.

### 4.29 Prose tells, extended

Extends §4.10 with quantitative + structural prose patterns. Apply to `*.md`, `*.rst`, top-level module docstrings, and README content. Strip fenced code blocks before analysis.

**a. Em-dash density (INFO / HIGH).** Count em-dashes (`—`, U+2014) per 100 words across the README + `docs/` corpus. Human casual prose: 0.1–0.4 per 100w. Claude / GPT: 1.0–1.3. GPT-4.1 even under suppression: ~3.28× human baseline. Llama under suppression: ~0.0 (absence of em-dashes is itself a model fingerprint). Thresholds:

- < 0.8 per 100w → no finding.
- 0.8–1.5 → INFO.
- > 1.5 → HIGH.

Also count ASCII surrogate ` -- ` (used by authors who write em-dashes deliberately in markdown).

**b. Contrastive negation — "It's not X — it's Y" (INFO / HIGH at 3+).** Structural rhetorical pivot.
```
(?i)\b(it'?s|this is|we'?re|that'?s)\s+not\s+(just\s+)?[a-z][^.!?\n]{3,40}[—–-]+\s*(it'?s|this is|we'?re|but)\b
(?i)\b\w+\s+isn'?t\s+just\s+(a|an|the)?\s*\w+
(?i)\bmore\s+than\s+just\s+\w+
(?i)\bnot\s+\w+,?\s+but\s+\w+\s+(also|too)
```

**c. Hedging / signposting filler phrases (HIGH at 3+).**
```
(?i)\b(it'?s worth (noting|mentioning|highlighting)|it bears (mentioning|noting)|importantly,|notably,|crucially,|interestingly,|let'?s (dive in|unpack|break (this|it) down|explore)|here'?s (the kicker|the thing|where it gets (interesting|tricky)|what most people miss))\b
```

**d. Pompous copula replacements (INFO / HIGH at 3+).**
```
(?i)\b(serves as|stands as|represents (a|an|the)|marks (a|an|the)|acts as (a|an|the))\s+[a-z]
```
Exclude OOP docs where "acts as a proxy/factory" is literal.

**e. Closing signpost in short docs (HIGH in short READMEs).**
```
(?im)^\s*(##+\s+)?(in conclusion|to (sum up|wrap up|summarize)|in summary|the bottom line|to recap)\b[:,.]?
```
HIGH in READMEs < 500 lines; INFO otherwise.

**f. Universal-appeal closing (HIGH).**
```
(?i)\bwhether\s+you'?re\s+(a\s+)?(beginner|new|seasoned|expert|experienced|just\s+starting|building)
(?i)\bperfect\s+for\s+both\s+\w+\s+and\s+\w+
(?i)\bno\s+matter\s+(your\s+(level|experience)|where\s+you'?re)
(?i)\bfrom\s+\w+\s+to\s+\w+,\s+(this|our)\s+\w+\s+(has|gives)\s+you\s+covered
```
Real OSS READMEs assume a peer-engineer reader.

**g. Emoji-decorated section headings (INFO / HIGH at 3+).**
```
(?m)^#{1,4}\s+[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}✨🚀📦🛠💡🎯⚡]
```

**h. "Why <project>?" boilerplate section (INFO).**
```
(?im)^#{1,4}\s+(why\s+[A-Z]\w*\??|what\s+is\s+[A-Z]\w*\??|the\s+(problem|solution|vision))\s*$
```

Added by: research synthesis on 2026-05-23.

### 4.30 Language-specific tells

Patterns scoped to a single language ecosystem. Apply only when the relevant file extension is present in the tree. Severities and excludes vary per pattern.

#### 4.30.a TypeScript / JavaScript

- **`any` proliferation (HIGH).** Count `: any`, `as any`, `Array<any>`, `Record<string, any>` per file. Flag files with ≥2 matches in `src/**/*.{ts,tsx}` (excluding `*.d.ts`, `*.test.ts`, `*.spec.ts`).
  ```
  :\s*any\b(?!\s*=\s*\w)
  \bas\s+any\b
  Array<any>|any\[\]|Record<\s*string\s*,\s*any\s*>
  ```

- **`@ts-ignore` / `@ts-expect-error` without justification (CRITICAL).** Bare directive with no preceding comment AND no `-- <reason>` on the same line.
  ```
  ^\s*//\s*@ts-(ignore|expect-error)\s*$
  ```
  PASS: `// @ts-expect-error -- <reason>`.

- **`as unknown as Foo` double-cast (HIGH).**
  ```
  \bas\s+unknown\s+as\s+\w
  ```
  Exclude tests + `types/` modules where a typed bridge is documented.

- **Permissive `tsconfig.json` (CRITICAL).** Parse `tsconfig.json`; flag explicit `"strict": false`, `"noImplicitAny": false`, `"strictNullChecks": false` without a documented migration note.

- **Promise-handling swallows (CRITICAL).** Same shape as §4.3 but in TS / JS:
  ```
  \.catch\(\s*\(\s*\w*\s*\)\s*=>\s*\{\s*\}\s*\)
  \.catch\(\s*\(\s*\)\s*=>\s*null\s*\)
  ```

- **`eslint-disable` without rule + reason (HIGH).**
  ```
  //\s*eslint-disable(-next-line)?\s*$
  //\s*eslint-disable(-next-line)?\s+[\w/-]+\s*$
  ```
  PASS: `// eslint-disable-next-line <rule> -- <reason>`.

- **Internal barrel `index.ts` (HIGH).** An `index.ts` of <30 lines consisting exclusively of `export * from './...'` / `export { Foo } from './foo'` statements, living under `src/<subdir>/` (not the package root). Internal barrels cause circular-import risk and ~75% slower bundler builds.

#### 4.30.b Go

- **Bare `if err != nil { return err }` chains without `%w` wrapping (HIGH).** Per file: >5 bare `return err` AND zero `fmt.Errorf("...%w", err)` wrappings.
  ```
  ^\s*if\s+err\s+!=\s+nil\s*\{\s*\n\s*return\s+(err|nil,\s*err|[^,]*,\s*err)\s*\n\s*\}
  ```

- **`interface{}` / `any` as a substitute for typing (HIGH).**
  ```
  \bfunc\s+\w+\s*\([^)]*\b(interface\{\}|any)\b
  map\[string\](interface\{\}|any)
  ```
  Exclude JSON-decode scratch values explicitly named (`var raw map[string]any`).

- **Goroutine without `context.Context` propagation (HIGH).** `go fn(...)` launched from a scope that has `ctx` in scope but doesn't pass it. Structural — requires caller-scope check.

- **Channel declared and never closed (HIGH).** Per file: list `make(chan ...)`; for each, verify a `close(<var>)` exists in a producer path.

- **Stutter-named packages (INFO).**
  ```
  ^package\s+(utils|helpers|common|shared|manager|services|misc|lib)\s*$
  ```

#### 4.30.c Rust

- **`.unwrap()` / `.expect("")` in non-test code (CRITICAL).**
  ```
  \.unwrap\(\)
  \.expect\(\s*"[^"]*"\s*\)
  ```
  Exclude `tests/`, `examples/`, `build.rs`, lines preceded by `// SAFETY:` / `// INVARIANT:`.

- **`.clone()` proliferation (HIGH).** Per-file count >5 in production code AND no `Arc` / `Rc` types in scope (which would justify the clones).

- **`Box<dyn Error>` as universal return type (HIGH).** Public API returning `Result<T, Box<dyn Error>>` in a crate with no `thiserror` dependency.
  ```
  ->\s*Result\s*<[^,]+,\s*Box\s*<\s*dyn\s+(?:std::error::)?Error
  ```

- **`unsafe {}` without `// SAFETY:` comment (CRITICAL).** Clippy `undocumented_unsafe_blocks` lint.

- **`#[allow(...)]` without explanation (HIGH).**
  ```
  ^\s*#\[allow\([^)]+\)\]\s*$
  ```
  Check the immediately preceding line for a comment justifying the allow.

- **`Arc<Mutex<T>>` overuse (HIGH).** >3 distinct `Arc<Mutex<...>>` / `Arc<RwLock<...>>` declarations in one module.

#### 4.30.d Java / Kotlin

- **Manager / Helper / Util class proliferation (HIGH).** Combine with §4.23. Flag >3 such classes outside Spring `@Service`-annotated context.

- **Swallow-and-log catches (HIGH).**
  ```
  catch\s*\(\s*(Exception|Throwable)\s+\w+\s*\)\s*\{[\s\n]*(log|logger|LOG)\.(error|warn)\([^;]+;\s*\}
  ```

- **`Optional<T>` in Kotlin (INFO).**
  ```
  import\s+java\.util\.Optional
  ```
  Kotlin's `T?` is the idiom.

- **Lombok `@Builder` on classes with ≤3 fields (INFO).**

#### 4.30.e C# / .NET

- **`async void` outside event handlers (CRITICAL).**
  ```
  \basync\s+void\s+\w+\s*\(
  ```
  Exclude UI event handler signatures `(object sender, EventArgs e)`.

- **`Task.Run(async () => await ...)` (HIGH).**
  ```
  Task\.Run\(\s*async\s*\(\s*\)\s*=>\s*await\s+\w
  ```

- **Single-implementation interfaces (HIGH).** `IFoo` whose only implementor is `Foo` and which is not registered in a DI swap-for-tests boundary.

#### 4.30.f Swift

- **Force unwraps in non-test code (CRITICAL).** `!` operator on optional values outside `@IBOutlet` / `@IBAction` / tests / `try!` in test setup. Crash vector.

#### 4.30.g Ruby

- **`rescue` with empty body (CRITICAL).**
  ```
  rescue\s*(StandardError)?\s*=>\s*\w*\s*\n\s*end
  rescue\s*(StandardError)?\s*\n\s*end
  ;\s*rescue\s*;\s*end
  ```

- **Empty `def foo; end` stubs (HIGH).**
  ```
  ^\s*def\s+\w+(\([^)]*\))?\s*\n\s*end\s*$
  def\s+\w+(\([^)]*\))?\s*;\s*end
  ```

#### 4.30.h Cross-language framework / config tells

- **Dockerfile narration-of-the-obvious (HIGH).** Each `RUN` / `COPY` / `WORKDIR` instruction preceded by `# <verb the instruction does>`.
  ```
  ^#\s*(Install|Copy|Set|Add|Create|Define|Configure|Run)\s+\w+\s*$
  ```
  ≥3 such comment-instruction pairs in a single Dockerfile.

- **GitHub Actions redundant `if: success()` (INFO).**
  ```
  ^\s*if:\s*success\(\)\s*$
  ```

- **GitHub Actions workflow duplication instead of matrix (HIGH).** Multiple `.yml` files with >70% line-similarity differing only by `python-version` / `node-version`. Should be `strategy.matrix`.

- **Makefile narration comments on every line (HIGH).** `\t# <verb> ...` comments above every recipe line.

- **Per-target `.PHONY` (INFO).** ≥3 single-target `.PHONY: foo\nfoo:` pairs instead of one consolidated declaration.

Added by: research synthesis on 2026-05-23.

### 4.31 In-repo consumer pin drifts behind parent package version (HIGH)

A published package whose repo also ships a sibling consumer harness (`e2e-consumer/`, `examples/realistic-consumer/`, `integration/sample-app/`, etc.) that depends on the **published** version of the parent package via its own `package.json` / `pyproject.toml` / `Cargo.toml`. The harness exists to break CI when the published surface changes incompatibly — but the contract only holds if the pinned version is current. Every release that bumps the parent's `version` without bumping the consumer's pin silently widens the gap between "what CI tests" and "what the README tells users to install."

After a few releases the consumer is testing a stale published surface against the latest source, the e2e job continues passing because the OLD published API still works fine on its own, and the surface-rename / re-export-drop / signature-change that the harness was supposed to catch happens unobserved between the source HEAD and the now-distant pinned version.

Detection rule: read the root manifest's `name` + `version` fields. Recursively find every other `package.json` / `pyproject.toml` / `Cargo.toml` inside the repo (excluding `node_modules`, `dist`, `build`, `cdk.out`, `.venv`). For each, if its dependencies include the parent's `name`, parse the version specifier. Flag if:
- The pin is a literal exact version (`"foo": "1.2.3"`, not `^1.2.3` / `~1.2.3` / `>=1.2.3`) AND
- That exact version is strictly less than the root manifest's `version` field.

```
# In root package.json
"name":\s*"([^"]+)"
"version":\s*"([^"]+)"

# In <subdir>/package.json
"<parent-name>":\s*"([0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?)"
```

Exclude: consumer dirs whose README explicitly justifies the pin ("pinned at the first release we shipped, on purpose, as a backward-compatibility floor"); private monorepos where the sibling is genuinely targeting an older shipped version.

Severity: HIGH when the parent `version` is ≥2 patch / 1 minor ahead of the pin; INFO when 1 patch ahead (release-in-progress is plausible). The fix is one of: (a) bump the pin in the consumer at the same time as the parent version (CI check), (b) replace the exact pin with `latest` / a floating range and accept that the test runs against whatever the npm cache resolves, (c) move the consumer to a workspace dep so it tracks source instead of the registry — at the cost of losing the "round-trip via npm" property.

Added by: oss-reviewer self-mutation on 2026-05-30 after observing
`e2e-consumer/package.json:12` — pins `cdk-glue-iceberg-table` at exact `0.1.3` while the root `package.json:3` declares `version: 0.1.7`. The e2e job is supposed to catch breakage in the **published** surface, but 4 patch versions later it is silently testing a 4-release-stale shape against the latest source. The contract is documented in `README.md:79` ("depends on the **published** … version … proves that a fresh install … works") and the gap between the pin and the live version has not been raising the alarm the contract was meant to raise.

### 4.32 Coverage-exclusion list outgrows the documented exclusion set (HIGH)

A project documents its coverage gate in prose ("95% on `src/**/*.ts` **minus the CLI entry and the barrel**", "coverage on all of `src` except `__main__.py`") that enumerates *exactly which files are carved out*. A later PR then adds one more negation glob to the coverage config (`!src/foo.ts` in Jest `collectCoverageFrom`, an entry in `coveragePathIgnorePatterns`, an `omit =` line in `.coveragerc` / `[tool.coverage.run] omit`, a `--ignore` in an nyc/c8 config) **without** updating the documented enumeration. The gate still passes — the new file is now invisible to it — but the doc now under-counts the exclusions, and a reader auditing "what's allowed to be untested" is given a stale, smaller list than what the config actually exempts. The added exclusion is frequently a wrapper the author didn't want to (or couldn't easily) unit-test, so the drift also hides the one file most worth scrutinising.

Detection rule: parse the coverage config and count the negation/omit entries that exclude *source* files (skip the always-excluded entry point + barrel if the doc already names them). Then read the project's coverage prose (CLAUDE.md / README "Testing and coverage" / contributing doc) and extract the count or enumeration it claims. If the config excludes strictly more source files than the prose enumerates, that's the finding — independent of whether each individual exclusion is technically justified.

```
# Jest config — count source-file negations beyond entry+barrel
'!src/[^']+\.ts'
# coverage.py / pytest
^\s*omit\s*=
coveragePathIgnorePatterns
# the documented set it should match
minus the [^.]*\band\b[^.]*       # prose enumerating "minus X and Y"
```

Exclude: configs whose exclusions are all glob *families* the prose describes categorically ("all `*.d.ts`", "everything under `__generated__/`") rather than a closed enumeration; projects with no prose claim about which files are excluded (nothing to drift against — judge the exclusion on its own merits via the §"Project-specific exemptions" thin-wrapper test instead).

Severity: HIGH when the project's own docs-sync policy mandates updating the doc on a coverage-rule change (then it's a self-declared violation); INFO when the prose is merely informal and no policy binds it. The underlying exclusion may still be a legitimate exemption (a zero-branch WASM/FFI wrapper exercised by an integration step is fine) — but the *doc drift* is the finding, and the fix is to update the enumerated list in the same PR that widens the config.

Added by: oss-reviewer self-mutation on 2026-06-04 after observing
`packages/core/jest.config.js:29` — the diagrams PR adds `'!src/diagram/render.ts'` as a third `collectCoverageFrom` exclusion while `CLAUDE.md:82` still describes the gate as covering `src/**/*.ts` "(minus the CLI entry and the barrel)" — two exclusions. The render.ts exemption itself is sound (a 7-line zero-branch `await import('@hpcc-js/wasm-graphviz')` wrapper, exercised by the CI `self-validate` render step), but CLAUDE.md's own "update CLAUDE.md if the change touches … the coverage rule" policy was not honoured, so the documented exclusion list silently fell behind the config.

### 4.33 Publish/install package name is squatted by an unrelated existing package (CRITICAL)

The companion to §4.18. §4.18 fires when the README's install command names a package that 404s on the registry (unpublished). This pattern is the *inverse and more dangerous* case: the manifest's `name` (the package the release pipeline will `npm publish` / `twine upload` / `cargo publish`) resolves to **200** on the registry — but it's owned by *someone else*. §4.18's "404 = lie" rule passes it clean (200 looks published), yet two things are broken: (a) the release workflow's publish step will fail with `403 Forbidden / you do not have permission`, and (b) the README's `npm install -g <name>` / `pip install <name>` hands every user a *stranger's* package — a 2015 stub, a typosquat, or an actively malicious drop — not this project. Short, generic, dictionary-word names (`fdd`, `dag`, `core`, `cli`) are the ones most likely already taken.

Detection rule: pull `name` from the root `package.json` / `setup.py` / `pyproject.toml` / `Cargo.toml` (the name the release workflow publishes, not just the README install string). Hit the registry:
- `https://registry.npmjs.org/<name>` → if 200, parse `maintainers[].name` / `author` and `time.created`.
- `https://pypi.org/pypi/<name>/json` → if 200, parse `info.author` / `info.maintainer`.
- `https://crates.io/api/v1/crates/<name>` → if 200, parse `crate.owners`.

The finding fires when the registry entry exists AND its owner/maintainer does not match the repo's declared author/maintainer (`setup.py` `author=`, `package.json` `author`, the repo's GitHub org). Strong corroborating tells: `time.created` predates the repo's first commit; the registry `description` is unrelated filler ("just for a test"); the registry `latest` version is higher than and unrelated to the manifest's `version` (e.g. registry `1.0.0` vs manifest `0.3.0`).

```
# In root package.json / setup.py / Cargo.toml
"name":\s*"([a-z0-9_-]+)"
name\s*=\s*["']([a-z0-9_-]+)["']

# Then, after fetching the registry JSON, compare:
#   registry maintainers / author  !=  manifest author / repo org
#   registry time.created          <   repo first-commit date
```

Exclude: scoped names the project legitimately owns (`@org/name`); names where the registry owner *is* the project author (a prior release by the same person); private-index packages declared with a custom registry URL.

Severity: CRITICAL when the release workflow's publish step targets the squatted name (the pipeline cannot succeed) OR the README documents `install <name>` as the headline (users get the wrong package). HIGH if the name appears only in an internal manifest with no publish step and no install doc. The fix is to rename the package to an available name (scoped `@org/name`, or a distinct unclaimed name) before advertising any install command or wiring a publish workflow.

Added by: oss-reviewer self-mutation on 2026-06-04 after observing
`packages/core/package.json:2` (`"name": "fdd"`, version `0.3.0`) + `.github/workflows/release.yml:62` (`npm publish --access public`) + `README.md:26` (`npm install -g fdd`). `https://registry.npmjs.org/fdd` returns 200 — but it's an unrelated 2015 package (`description: "just for a test"`, maintainer `aowu`, latest `1.0.0`, created 2015-07-24, years before this repo). §4.18's 404-check passes it; the release pipeline's `npm publish` would 403, and `npm install -g fdd` installs the stranger's stub. The PyPI name `fdd` 404s (publishable but the Python README's headline `pip install fdd` has no "not yet published" disclaimer).

### 4.34 Package/module rename leaves a stale path in a CI invocation (HIGH)

A rename of a published package's import module / source directory (`src/fdd` → `src/flexdataset`, `pkg/old` → `pkg/new`) that updates the local dev scripts (`scripts/test.sh`, `Makefile`, `tox.ini`) but misses a *parallel* invocation of the same tool in the CI workflow. The most damaging shape is a coverage flag still pointing at the old path: `pytest --cov=<old-module-path>` (or `--cov=<old>`, `coverage run --source=<old>`, `go test -coverpkg=<old>`, `nyc --include <old>`). pytest-cov given a `--cov` target that no longer exists on disk collects **zero** data, reports 0% coverage, and trips the `--cov-fail-under=N` gate — so CI goes red on every push even though the suite itself is green locally (where the dev script uses the *new* path). The grep-the-tree rename audit (§4.33-style `\bold\b` search) catches it only if the reviewer doesn't pre-exclude config/CI files as "non-source."

Detection rule: after confirming a rename (manifest `name`, `package_dir`, the actual `src/<new>/` directory on disk), grep every CI / build / script file for the *old* module path. Cross-check the local dev test script against the CI test step — if `scripts/test.sh` says `--cov=src/<new>` but `.github/workflows/*.yml` says `--cov=src/<old>`, the CI step is broken. Fastest confirmation: the old `src/<old>/` directory does not exist (`ls -d` fails) yet a CI step still references it.

```
# A coverage/source flag naming a path that no longer exists on disk
--cov(-report)?[ =]+src/[a-z0-9_]+
--source[ =]+[a-z0-9_./]+
-coverpkg[ =]+[./a-z0-9_]+
# then: confirm the named dir is absent AND the local dev script names a different (current) path
```

Exclude: monorepos where the CI path legitimately differs from a sub-package's local script; coverage paths that are package *names* resolved on `sys.path` rather than on-disk dirs (verify by checking whether the path exists as a directory); renames where every invocation was updated consistently (no drift = no finding).

Severity: HIGH. The repo claims publish-readiness (release workflow wired) but its own CI test gate fails on the first push after the rename — and it fails for a reason (`--cov-fail-under` on 0% collected) that looks like a coverage regression rather than a stale path, costing the next contributor a debugging session. The fix is to update the CI invocation in the same commit as the rename, or to derive the cov path from a single shared variable both the script and CI read.

Added by: oss-reviewer self-mutation on 2026-06-04 after observing
`.github/workflows/ci.yml:84` (`python3 -m pytest tests/ --cov=src/fdd --cov-fail-under=95`) while the `flexdataset` rename moved the module to `src/flexdataset` (the dir `src/fdd` no longer exists) and the local `packages/python/scripts/test.sh:5` was correctly updated to `--cov=src/flexdataset`. CI would collect 0% coverage against the dead `src/fdd` path and fail the 95% gate on every push.

### 4.35 Runtime `__version__` / version constant drifts behind the manifest version on a version-bump PR (HIGH)

A package exposes its version twice: once in the build manifest (`setup.py` `version=`, `package.json` `"version"`, `Cargo.toml` `version =`) and once as a runtime constant the published artifact actually reports (`__init__.py` `__version__ = "..."`, a `const VERSION = "..."`, a `pkg.Version` literal). A version-bump PR that updates the manifest but forgets the parallel runtime constant ships a package whose `import pkg; pkg.__version__` reports the *previous* release while the registry / wheel metadata reports the new one — a silently wrong self-report that breaks `--version` output, telemetry, and any consumer that branches on the reported version. It is invisible to the test suite (nothing asserts the two agree) and to a coverage gate, so green CI does not catch it.

Detection rule: collect every version string in the repo for the package under bump — the manifest `version` field AND any runtime constant (`__version__`, `VERSION`, `__VERSION__`, a `version:` in a generated `_version.*`). On a PR whose diff bumps the manifest version, confirm each runtime constant was bumped to the same value. The strongest corroboration is the git history: if prior release commits moved the manifest and the runtime constant *together* (one hunk each) and this PR moves only the manifest, the omission is a regression against the repo's own established lockstep.

```
# manifest
version\s*=\s*["']([0-9]+\.[0-9]+\.[0-9]+[^"']*)["']
"version":\s*"([0-9]+\.[0-9]+\.[0-9]+[^"]*)"
# runtime constant — must equal the manifest value
__version__\s*=\s*["']([0-9]+\.[0-9]+\.[0-9]+[^"']*)["']
(?:const|let|var|public)?\s*VERSION\s*[:=]\s*["']([0-9]+\.[0-9]+\.[0-9]+[^"']*)["']
```

Special case (added 2026-07-05, charmander PR #67): a version bump that touches no npm
dependency forces no lock rewrite, so package-lock.json's TWO version fields silently
stay behind the manifest — check them explicitly on every bump-only diff; `npm ci`
exits 0 on the drift, so CI never flags it.

Exclude: projects where the runtime constant is *derived* at build time from the manifest (`importlib.metadata.version(__name__)`, `pkg_resources.get_distribution`, a `setuptools_scm` / generated `_version.py`, a bundler `define` injecting `package.json` version) — there is only one source of truth, nothing to drift; monorepos where the constant legitimately tracks a different sub-package.

Severity: HIGH on a version-bump PR (the published artifact will self-report the wrong version, and the project's own lockstep history shows the bump is meant to be atomic); INFO if the drift predates the PR and the PR doesn't touch versions. The fix is to bump the runtime constant in the same PR as the manifest, or better, derive it from the manifest so it cannot drift.

Added by: oss-reviewer self-mutation on 2026-06-05 after observing
PR #9 (`feature/column-nullability`) on `ksco92/eevee`: the commit bumps `packages/python/setup.py:7` (`version="0.6.0"`), `packages/core/package.json:3`, and `packages/core/package-lock.json` to `0.6.0` but leaves `packages/python/src/flexdataset/__init__.py:7` at `__version__ = "0.5.0"`. Every prior release (0.3.0 → 0.5.0) moved `setup.py` `version=` and `__init__.py` `__version__` together; this PR is the first to drift them, so the published `flexdataset` wheel would report `0.5.0` at runtime while its PyPI metadata says `0.6.0`.

### 4.36 "DEFERRED" / "future PR" / "v2 lift" crumbs (CRITICAL)

The `# DEFERRED:` / `Future PR` / `v2 lift` / `lands later` family. AI sessions
working through a staged build plan love to leave inline reminders of what the
next pass will do — they read as professional ("scope-bound v1") but they're
the §4.1 task-referential-leftover pattern in a more sophisticated disguise.
Once a v1 ships to strangers, "deferred to a follow-up PR" is noise: the
follow-up either lives in the issue tracker or it doesn't.

```
^\s*#\s*DEFERRED[:\s]
\bfuture[- ]PR\b
\bv2\s+lift\b
\bdeferred\s+to\s+a\s+(follow[- ]up|future)\s+PR\b
\blands?\s+later\b
\bnext\s+PR\b
```

Exclude:
- `CLAUDE.md` / `TODO.md` / `ROADMAP.md` — these are the legitimate place for
  "next PR" planning notes (the whole point of TODO.md is to be a task list).
- Test fixtures that document why a code path is skipped (`@pytest.mark.skip(
  reason="...")`).
- CHANGELOG entries.

Severity: CRITICAL when found in shipped source files (`src/**`,
`pkg/**`, `lib/**`). Each match is one finding; file ONE finding per pattern per
file even if the file has multiple matches (cite the count + the first
file:line). The pattern is strong-signal — a single `# DEFERRED:` in a public
API docstring tells a stranger the code is unfinished.

Added by: oss-reviewer self-mutation on 2026-05-16 after observing
`src/pag/engine/identity.py:167`, `src/pag/cli/init.py:198`, and a 16-instance
spread across `src/pag/{engine,cli,storage,connectors}/` of `# DEFERRED:` /
"future PR" / "v2 lift" markers in the pag review.

Also match the §4.142 phrases ("implemented so far", "would be added the same way") and (case-insensitive):
```
a candidate follow-up|natural follow-up
```

### 4.37 Cross-test-file helper duplication (HIGH)

Identical fixture helpers (DB setup, mock factories, sample-data builders)
copy-pasted across many test files instead of living in a `conftest.py` or
shared test-helpers module. The strongest tell: a function named identically
across N test files whose body is byte-identical or differs only in a constant.
AI sessions generate each test file in isolation and re-emit the same helper
each time; a human author would extract on the second or third copy.

Detection: for each test file, capture the names of all module-level
`def _*(...)` helpers and check whether the same name appears in >= 3 sibling
test files. When it does, diff the bodies — exact matches OR
identifier-rename-only matches are the finding.

```
^def\s+_\w+\(    # helper-style underscore-prefixed module-level def
```

Then `grep -l "^def _admin_engine"` (or whatever helper-name) across the test
tree; count hits.

Exclude:
- Test files that are themselves new (< 30 days old or marked WIP) — give the
  author time to factor out.
- Helpers whose duplication count is exactly 2 (a single re-use is not yet
  a refactor target).

Severity: HIGH at a threshold of >= 5 duplicated copies; INFO at 3-4. The
threshold reflects the cost trade-off: extracting a helper is cheap; 5+ copies
means the author wasn't reading their own test tree. Sharper variant at ANY count
(added 2026-07-05, charmander PR #67): same-NAME private helpers across sibling
modules with silently DIVERGENT edge-case contracts (one `_as_optional_float`
raises on "", another returns None) — name implies contract; the divergence traps
both readers and the eventual consolidation. HIGH regardless of copy count.

Added by: oss-reviewer self-mutation on 2026-05-16 after observing
`_admin_engine` / `_create_fresh_db` / `_drop_db` duplicated identically
across 11 test files in `tests/pag/storage/postgres/` and
`tests/pag/skills/` in the pag review.

### 4.38 Test reads user env for "default" assertions (CRITICAL)

(Renumbered from a colliding "4.14" added by self-mutation on 2026-05-18.)

Tests that assert a CLI's default value matches a string literal but DO NOT
isolate the user environment first. The pattern:

* The CLI under test reads `os.environ.get("FOO", "<default>")`.
* The test asserts `result == "<default>"`.
* The test fixture sets *some* env vars (e.g. `PAG_HOME`) but forgets to
  `monkeypatch.delenv("FOO", raising=False)` for any OTHER env var the
  CLI also reads.
* On the author's machine, `FOO` is unset, so the test passes.
* On a contributor's machine where `FOO` IS set (often because the
  README told them to set it before invoking the CLI), the test fails
  with `AssertionError: '<their value>' != '<default>'`.

Detection: grep test files for assertions against hardcoded default-URL /
default-path / default-token strings, then audit the fixture for the
matching `monkeypatch.delenv` call. The asymmetry — fixture deletes one
env var but not the sibling vars the CLI reads — is the smoking gun.

```
monkeypatch\.setenv\(["'](PAG_HOME|XDG_\w+|HOME)
```

Then for each match, check whether the SAME fixture also calls
`monkeypatch.delenv` (or `setenv` to a known empty / non-conflicting
value) for the other env vars the CLI under test reads. Cross-reference
against the CLI's `os.environ.get` calls.

Exclude: tests that explicitly construct a hermetic env via
`monkeypatch.setattr("os.environ", {...})` or `mock.patch.dict(os.environ,
{...}, clear=True)`.

Severity: CRITICAL. A test that depends on a user's shell environment is
a test that lies about its own determinism — the README literally tells
strangers to set the env var, then the test suite breaks because they
did. This is the cleanest possible reproducer of "works on the author's
machine."

Added by: oss-reviewer self-mutation on 2026-05-18 after observing
`tests/pag/cli/test_init.py` failing 4 tests on a stranger's machine
because the `pag_home_dir` fixture sets `PAG_HOME` but not `DATABASE_URL`
— and the README's quickstart literally tells users to set
`DATABASE_URL` before running `pag init`. Tests asserted the URL equals
the hardcoded default `postgresql+psycopg:///pag_dev`.

### 4.39 Linter-config excludes naming directories absent from the repo (INFO)

Lint / formatter config exclude lists (`.flake8` `exclude =`, eslint `ignorePatterns`,
`[tool.ruff] exclude`) naming directories that do not exist anywhere in the tree. The
config was copied from another project (or a template) and never trimmed to this repo;
each stale entry is harmless alone but marks the config as unaudited residue rather
than a curated artifact.

```
# extract exclude entries from .flake8 / setup.cfg [flake8] / pyproject [tool.*] / eslint
^\s*exclude\s*=
ignorePatterns
# then: for each non-glob entry, test -d / test -e — absence in the tree is the finding
```

Exclude: glob families that legitimately anticipate generated dirs (`build/`, `dist/`,
`.venv`, `__pycache__`, `node_modules` — tool-output dirs that appear at runtime even
if absent at review time); monorepo roots whose configs serve subpackages.

Severity: INFO. One stale entry is noise; three or more distinct project-specific names
(an IDE dir the author doesn't use, a `local_stuff/` from a different repo) show the
config was pasted, not written.

Added by: oss-reviewer self-mutation on 2026-07-03 after observing
`.flake8:4-8` in charmander excluding `.idea`, `.run`, and `local_stuff` — none of which
exist in the tree; the block is a byte-level carry-over from the pikachu project's
setup.cfg the toolchain was ported from.

### 4.40 Well-known fixtures type-annotated as `object` to satisfy an annotations linter (INFO)

Test signatures annotating pytest's well-known fixtures with `object` (or `Any`) instead
of their real types — `tmp_path: object` instead of `tmp_path: pathlib.Path`,
`monkeypatch: object` instead of `pytest.MonkeyPatch`, `capsys: object`. The annotation
exists only to silence `flake8-annotations` / `ANN001`; the body then works around the
opaque type (`str(tmp_path)`) instead of using the real API. A human who knows pytest
writes the actual type; mechanically satisfying the gate with `object` is a
generated-code fingerprint.

```
(tmp_path|tmp_path_factory|monkeypatch|capsys|capfd|caplog|pytestconfig)\s*:\s*(object|Any)\b
```

Exclude: fixtures with genuinely dynamic types (`request.param`-driven); codebases that
deliberately avoid importing pytest types for typing-only use and document it.

Severity: INFO per file; HIGH when the pattern covers every annotated fixture in the
test tree (the suite's typing is uniformly decorative).

Added by: oss-reviewer self-mutation on 2026-07-03 after observing
`test_python/databases/gdelt/test_file_list.py:38` (`tmp_path: object`) across a
charmander test file, with `str(tmp_path)` casts working around the opaque annotation.

### 4.41 Per-partition dedupe presented as a global uniqueness guarantee (CRITICAL)

Distributed fan-out code (Spark `mapPartitions`, Beam `DoFn`, multiprocessing pools)
whose OUTPUT contract declares a unique key (a primary key, an upsert key) but whose
assembled output lacks a global dedupe (`dropDuplicates` / `distinct` / `GROUP BY` on
the full key). Two sub-shapes, both the same defect: a worker-local `seen` set that
only deduplicates within its own partition, or NO dedupe at all on the assumption the
source "never repeats a key" (sources re-emit: corrections, reprocessing glitches,
cross-attribution). An empty-target first load (pure insert path) hides the violation
until a later merge hits it — and in batch-resumable pipelines the failure is a
DETERMINISTIC WEDGE: the same batch re-fails on every resume because chunking is
deterministic, so the job cannot make progress past it.

```
# candidate files: fan-out functions carrying a local dedupe set
mapPartitions|foreachPartition
^\s*seen\s*[:=]\s*set
# then: confirm the assembled DataFrame/collection ALSO dedupes on the same key
dropDuplicates|distinct\(\)
```

Detection is structural: for each file matching the first two patterns, check whether
the function that assembles the final output applies a global dedupe on the same key
set; its absence when the table/model declares those columns unique is the finding.
Verify empirically when live data exists: `COUNT(*)` vs `COUNT(DISTINCT <full key
concat>)` — the full composite key, never a single proxy column.

Exclude: fan-outs whose per-worker key spaces are provably disjoint (the partition key
IS the dedupe key); outputs merged by an engine that enforces uniqueness upstream of
the contract (a true upsert sink keyed on the same columns).

Severity: CRITICAL. The first load into an empty target masks it (insert path skips
merge-cardinality checks), so the violation ships silently and detonates on the next
incremental run.

Added by: oss-reviewer self-mutation on 2026-07-04 after observing
`src/charmander/databases/eodhd/news.py:314` — a per-partition `seen` set guarding a
(title, symbol) primary key while cross-attribution made overlapping keys arrive in
different partitions; live table held 5,052,858 rows but only 2,124,467 distinct pairs.

### 4.42 Auto-fixing lint script used as the CI gate (HIGH)

The script CI invokes for linting/formatting contains an auto-repair flag (`--fix`,
`--write`, `-w`), and no subsequent step fails on the resulting diff. Fixable violations
are silently repaired in the runner's ephemeral checkout and never reported — committed
code can violate the style rules forever while the gate stays green; only unfixable rules
actually gate.

```
"(lint|format|style)[^"]*":\s*"[^"]*(eslint|prettier|ruff|black|isort|rustfmt)[^"]*(--fix|--write|\s-w\b)
```

Then cross-reference the CI workflow: the finding fires only if a workflow step invokes
that script (directly or via a composite like `npm run dev`) with no following
`git diff --exit-code` / `--check` re-run.

Exclude: `lint:fix` / `format` convenience scripts that CI never invokes (a separate
check-only script being the gate); workflows that run the fixer and then
`git diff --exit-code`.

Severity: HIGH. The project claims an enforced style gate; the gate is decorative, which
is the §4.17/§4.32 gate-integrity family in its most silent form.

Added by: oss-reviewer self-mutation on 2026-07-04 after observing
`package.json:31` in charmander (`"lint": "eslint . ... --max-warnings=0 --fix ..."`)
invoked as the CI gate by `.github/workflows/ci.yml:24` — auto-fixable violations of the
project's own 4-space/single-quote rules could never fail CI.

### 4.43 Constant-echo tests (INFO / HIGH at ≥3 per suite)

Tests whose assertions consist solely of restating a module constant's literal value
(`assert mod.MAX_RETRIES == 4`, or duplicating a whole source list/set into the test and
asserting equality). No SUT call, no behavior verified — the test is a change detector
that inflates the coverage figure and converts every deliberate tuning change into a
two-file edit whose "fix" is editing the test.

```
assert\s+[\w.]+\.[A-Z][A-Z0-9_]+\s*==\s*
```

Then AST-confirm: a `test_*` body whose every `Compare` has a module-attribute LHS and a
literal (or test-local verbatim copy) RHS, with no call to the unit under test. A
constant-echo assertion appended inside an otherwise-real test counts at half weight.

Exclude: contract pins whose comment says what external contract freezes the value (a
wire-format magic number, a documented API default); derived-invariant assertions
(`len(X) == len(set(X))`, cross-constant consistency checks).

Severity: INFO per instance; HIGH when ≥3 across the suite — systematic coverage padding.

Added by: oss-reviewer self-mutation on 2026-07-04 after observing
`test_python/utils/fred/test_fred_api.py:20-40` in charmander duplicating a 19-element
`SERIES_IDS` list verbatim and asserting it equal, plus six more constant-echo sites
across `test_news.py`, `test_events.py`, `test_api.py`, and `test_symbol_universe.py`.

### 4.44 Predecessor-repo diff narration (HIGH / INFO)

Docstrings, comments, or data-model description strings that document current behavior as
a delta from a codebase not present in the repo: "the legacy code added a stray + 1",
"ported verbatim from the source system", "exactly as <private-repo> does". The
correctness authority is a repo the reader cannot see, and the text is changelog content
in an API doc's clothing. Includes the data-model variant: the same ≥15-word provenance
sentence stamped across ≥3 model/schema files identical modulo one identifier (§4.26
transposed to declarative models).

```
\b(the\s+)?legacy\s+code\b
\bported\s+(verbatim\s+)?from\b
\bin\s+the\s+source\s+system\b
\b(exactly\s+as|matching)\s+\w+(?:'s)?\s+(does|did|exact)
```

Exclude: genuine dialect-translation notes that document the CURRENT behavior a reader
needs (a Postgres→Spark SQL conversion note explaining why the query uses row_number);
NOTICE/ATTRIBUTION files; README history sections ("ported from X, opened YYYY").

Severity: HIGH when the narration replaces behavior documentation in an API docstring or
is template-stamped across ≥3 files; INFO for a file-header provenance note that
accompanies real documentation.

Added by: oss-reviewer self-mutation on 2026-07-04 after observing
`src/charmander/databases/eodhd/news.py:202` ("the corrected paging math (the legacy code
added a stray ``+ 1``…)"), `src/charmander/utils/fred/api.py:25` ("ported verbatim from
the source system"), and one provenance sentence stamped verbatim across six
`lib/databases/**/*.json` model descriptions in charmander.

### 4.45 Delivery-plan vocabulary in deployed resource descriptions (CRITICAL)

Description/comment strings in declarative infra models (Glue database/table
descriptions, Terraform descriptions, CDK construct descriptions, schema doc fields)
that reference the project's DELIVERY PLAN instead of the resource's current contents:
"in later slices", "will be added in a future phase", "once X lands". These strings
deploy verbatim into live catalogs/consoles; a stranger reading the resource sees a
roadmap reference they cannot resolve. It is §4.36's task-referential crumb transposed
into shipped infrastructure metadata, where it outlives the plan invisibly.

```
\b(later|future|upcoming|subsequent)\s+(slices?|phases?|iterations?|sprints?|PRs?|waves?)\b
\bwill\s+be\s+(added|ported|ingested)\s+(when|once|after)\b
\b(out\s+of\s+scope|deferred|planned)\s+for\s+v\d+\b
\b(only\s+)?\(v\d+\)|\bfor\s+v\d+\b        # version-scope tokens in resource descriptions
```

Exclude: issue trackers, TODO.md/ROADMAP.md, PR bodies, commit messages — plan language
is at home there; README roadmap sections explicitly headed as such.

Severity: CRITICAL in shipped model/IaC files (matches §4.36); the fix is to describe
what the resource contains NOW and put the plan in the tracker.

Added by: oss-reviewer self-mutation on 2026-07-04 after observing
`lib/databases/sec/sec.json:4` in charmander shipping "and, in later slices, the 8-K and
Form 4 filing datasets" as the live Glue database description on a PR produced by a
slice-decomposed agentic workflow.

### 4.46 Sibling-target comment references a gate exclusion the diff just removed (HIGH)

Two related targets in a Makefile / CI config cross-reference each other's scope in
comments (e.g. a `mutants:` target says "same exclusion as `make coverage` above, see
that target's comment" and states a concrete trigger condition for widening its own
scope, such as "widen back to `--workspace` once milestone X gives the shim real
behavior plus its own tests"). A PR then satisfies that exact trigger for ONE sibling
(removes the coverage exclusion, updates coverage's own comment, coverage goes to 100%)
but leaves the OTHER target's comment and scope untouched — it still asserts the
removed exclusion exists and still carries its own trigger condition as unmet, even
though the PR that just landed is the trigger firing. The result isn't just a wrong
comment: the second gate (commonly mutation testing) keeps silently skipping the newly
non-trivial code, and the stale comment actively asserts this is still intentional.

```
# find sibling-target back-references in comments
excluded from `make \w+`|same (as|reason) `make \w+`|see that target'?s comment
# then check the diff: did the referenced target's exclusion actually change,
# without the citing target's comment/scope being updated to match?
```

Exclude: comments with no concrete, checkable trigger condition (nothing to violate);
targets whose mutual references are coincidental, not a stated shared-scope contract.

Severity: HIGH. The code the trigger was gating (here, ~300 lines of new CLI arg
parsing / exit-code logic) ships with zero coverage from the second gate while the
comment insists the narrow scope is still deliberate.

Added by: oss-reviewer self-mutation on 2026-08-31 after observing
`Makefile:33-37` in onix: the `mutants` target's comment says onix-cli/src/main.rs is
"the same logic-free shim excluded from `make coverage` above (see that target's
comment)" and "widen back to `--workspace` once M5 gives the CLI real behavior plus its
own tests" — while the `coverage` target's own comment three lines above (line 15-17)
says the opposite: M5a already gave onix-cli real logic + tests and removed the
coverage exclusion (confirmed at 100% lines). `mutants` is still scoped `-p onix-core`
only; the trigger it names fired in this exact commit but the target was never widened.

### 4.46 Closed-inventory doc table missed by a checklist-driven add (HIGH)

A repo documents a CLOSED enumeration of shipped units (README dataset table, command
list, endpoint matrix) AND has a written add-a-unit checklist naming the operational
files to touch. When the checklist omits the enumeration doc, every checklist-following
add updates exactly the named files and silently under-counts the inventory — the
checklist itself manufactures the blind spot, so the drift is systematic, not sloppy.

Detection: on any unit-adding diff, locate closed enumerations of that unit type
(README tables with one row per unit, docs listing "supported X"); verify the diff adds
the corresponding row. Independently, diff the checklist's named files against the set
of docs that enumerate units — any enumeration absent from the checklist is a latent
drift channel worth flagging even before it fires.

Exclude: enumerations explicitly marked partial ("highlights", "examples include");
auto-generated inventories derived from the source of truth at build time.

Severity: HIGH when the inventory is presented as complete (the reader counts N rows
and the system has N+1 units); the durable fix is BOTH the missing row and adding the
enumeration doc to the add-a-unit checklist.

Added by: oss-reviewer self-mutation on 2026-07-04 after observing
charmander PR #40 adding `sec.cik_map` with `scripts/run_all_etls.sh` and
`row_counts_query.sql` dutifully updated (both named in CLAUDE.md's add-a-table
checklist) while the README "Current datasets" table — not named in the checklist —
gained no row.

### 4.47 Inverted-semantics justification comment on a config choice (HIGH)

A comment defending a configuration value ("X, because <alternative> would <behavior>")
whose stated reasoning misstates the API's actual semantics — while the chosen value
itself is defensible, so tests stay green and review skims past. The comment is the
plausible-sounding rationale an AI generates for a decision it made on other grounds;
the danger is downstream: the next maintainer trusts the wrong mental model when
changing the setting.

Detection is structural, not grep-able: for every comment of the form "chose X because
Y would <miss/break/capture/leak>...", verify the alternative's claimed behavior
against the SDK docs or an empirical synth/run. Same family (added 2026-07-04, from
charmander PR #55): extraction-shape tables mapping keys to named API operations where
a named operation actually uses a different key — behavior often survives via
coalesce/fallback, so only checking each key→operation claim against the API reference
catches it (GetPartitions sends TableName, not name). Also in-family: relation-word
claims about named helpers — "the exact inverse of / same as / mirror of <function>" —
must be verified against the named function's actual direction; a relation-inverted
claim restated in both source and PR body is near-certain generation residue
(charmander PR #58: a same-direction transform documented as "the exact inverse"). Two instances of the same wrong claim
in one PR (source + test restating it) is near-certain generation residue. Also in-family (added 2026-07-05,
charmander PR #81): composite-key / dedupe rationales claiming a source "re-emits the same id across
streams/feeds" — probe real source ids before accepting; formats that namespace their streams (GDELT GKG
translation ids all carry a "-T" sequence marker, so an id can never repeat across the two streams) make the
claimed collision impossible, and the invented rationale tends to ship twice (deployed column description +
code comment).

Exclude: comments citing a doc URL whose content actually supports the claim; version-
pinned behavior notes ("as of SDK vX, Y defaults to...") that were true when written.

Severity: HIGH when the misdocumented setting is security- or data-capture-relevant
(audit trails, encryption modes, event capture); INFO otherwise.

Added by: oss-reviewer self-mutation on 2026-07-04 after observing
charmander PR #41: `lib/cost-estimation.ts:167` justified CloudTrail
`ReadWriteType.ALL` with "read-only would miss the per-table access counts entirely"
(READ_ONLY captures GetTable reads; WRITE_ONLY is what would miss them), and
`test/cost-estimation.test.ts:125` restated the same inversion ("renders no
ReadWriteType override" — synth shows an explicit `ReadWriteType: "All"`).


### 4.48 Unfalsifiable downstream-invariant test (INFO / HIGH at cluster)

A test asserting a property on output that the code guarantees by RAISING upstream
before that output can exist — e.g. asserting a result set has unique keys when the
builder throws on any duplicate before returning. The assertion cannot fail for any
buildable output; it inflates coverage, survives deletion of the guard it appears to
test, and reads as rigor while discriminating nothing. Generalizes §4.22: the test has
assertions, but no reachable input can falsify them.

Detection is semantic: for each invariant-shaped assertion (uniqueness, non-emptiness,
ordering), check whether the SUT path raises on the violating input before producing
output — if yes, the test is unfalsifiable; the falsifiable version is the `raises`
test, which usually already exists beside it.

Exclude: property tests running against a DIFFERENT path than the guard (e.g. reading
back from storage where the guard could be bypassed); tests explicitly documenting
they pin the guard's placement.

Severity: INFO per instance; HIGH when ≥3 in a suite (systematic padding).

Specialization (added 2026-07-04, from charmander PR #52): a dedupe/uniqueness test
whose assertions read THROUGH a container keyed on the deduped column (`{row[pk]: row
for row in df.collect()}` then asserting on the dict) — the container collapses
duplicates itself, so the assertion passes even with the dedupe deleted. Require a
count assertion (`df.count() == N`) for any uniqueness claim.

Added by: oss-reviewer self-mutation on 2026-07-04 after observing
charmander PR #46 `test_eight_k_filings.py:413` asserting output accession uniqueness
when `enforce_unique_accessions` raises on any duplicate before the DataFrame exists.

### 4.49 Inclusive-comparison early-stop at the source's pagination granularity (HIGH)

Incremental fetchers that stop paging via an inclusive comparison (`<=` / `>=`) on the
same granularity the source splits pages by (a date, an id prefix), silently dropping
in-window items that straddle a page boundary at exactly the cutoff value. Sources
split pages by COUNT, not by the compared field, so multiple same-valued items can
span two pages; "oldest item on this page <= floor, stop" abandons the tail. The loss
is deterministic when it fires and invisible to boundary tests written clear of the
exact cutoff.

Detection: in pagination/early-stop predicates, find comparisons of a page's min/max
field against a floor/ceiling constant; flag inclusive operators unless the code also
fetches the next page when the boundary value equals the cutoff, or the source
guarantees page splits never divide equal values. Then check the tests: is the exact
cutoff value exercised with a straddling page?

Exclude: sources that paginate BY the compared field with documented no-split
semantics; cutoffs on strictly-monotonic unique keys (no equal values to straddle).

Severity: HIGH — silent, deterministic data loss at one specific value.

Added by: oss-reviewer self-mutation on 2026-07-04 after observing
charmander PR #46 `eight_k_filings.py:265` stopping pagination when the recent block's
oldest filing_date `<=` the 2018-01-01 floor while EDGAR pages split by count, so
same-day filings continuing on the next page would never be fetched.

### 4.50 Tolerant coercer feeding a non-nullable schema slot (HIGH)

A parsing helper maps malformed/blank input to `None` ("tolerant" posture) while the
downstream schema declares that column non-nullable — converting one bad input row
into a runtime schema error far from the parse site. In resumable batch pipelines the
consequence compounds into a deterministic wedge: the failing batch never commits, the
resume logic re-selects it, and every rerun re-crashes on the same row. The tell is
INTERNAL INCONSISTENCY: sibling critical fields get skip-guards or loud raises while
one field alone is tolerated at parse and rejected at write.

Detection: for each `Optional`-returning coercer (`-> T | None`, `except: return
None`), trace every consumer into the output schema; flag when the landing column is
declared non-nullable (StructField(..., False), `"nullable": false`). Then check the
sibling fields' handling — asymmetry confirms it's an oversight, not a policy.

Exclude: coercers whose None output is filtered/guarded before the schema boundary;
pipelines that explicitly validate-and-raise with row context before the write.

Severity: HIGH — a data-quality landmine that unit tests with well-formed fixtures
never step on; CRITICAL in resumable batch pipelines (deterministic re-crash wedge).

Added by: oss-reviewer self-mutation on 2026-07-04 after observing
charmander PR #47 `form4_transactions.py`: `_parse_sec_date` → None stored by
`build_submission_index` and emitted into `filing_date` declared
`StructField(..., False)`, while ISSUERCIK/ACCESSION_NUMBER/NONDERIV_TRANS_SK all got
skip-guards.

### 4.51 Wrong-domain proper noun in a stamped model description (CRITICAL)

A new data-model/resource description containing a proper noun from a SIBLING domain
that cannot apply — "the SEC-unique event_id" on a CloudTrail table, "the EODHD
sentiment payload" on a weather table. Near-proof of cross-dataset template stamping:
the author copied a sibling model's description shape and the domain qualifier rode
along. The factually-garbled sentence deploys verbatim into live catalog metadata.

```
# grep each new model/description for sibling-domain tokens outside their home dir,
# e.g. in a lake with sec/, eodhd/, fred/, gdelt/, misc/ domains:
(SEC|EDGAR|EODHD|FRED|GDELT)[- ](unique|assigned|provided|sourced)
```
Generalize per repo: build the token list from the repo's own domain/dataset names and
flag any appearance outside that domain's directory.

Exclude: genuine cross-references ("joins to sec.cik_map on cik") — the tell is the
noun used as the AUTHORITY/qualifier for the wrong domain's identifier, not a join note.

Severity: CRITICAL in deployed descriptions (a lie in live metadata); HIGH in code
comments.

Added by: oss-reviewer self-mutation on 2026-07-04 after observing
charmander PR #52 `lib/databases/ops/cloudtrail_events.json:4` describing CloudTrail's
eventID as "the SEC-unique event_id (a UUID)" — stamped from the sec/ sibling models.

### 4.52 Phantom-successor doc on a deletion (HIGH)

A PR deletes a concrete artifact (a query file, a script, a module) and the
replacement documentation refers to its successor in the PRESENT tense — "a downstream
view turns these counts into the final estimate" — when no such successor exists in
the tree. Two failure modes ride together: the reader chases a nonexistent artifact,
and the deleted artifact's real capability (an extraction expression, unit prices, a
documented workflow) silently vanishes instead of migrating.

Detection: for every deletion in a diff, list what load-bearing content the deleted
file carried (expressions, constants, documented procedures); verify each landed
somewhere (code, successor file, or a tracked issue). Then grep the ADDED docs for
present-tense references to consumers/successors of the deleted capability and verify
each referent exists; a tracked-issue future is fine ONLY if the doc text avoids
claiming present existence.

Exclude: docs explicitly citing the tracker ("counts are consumed by the cost table
planned in issue #N" — though deployed descriptions should avoid plan language per
§4.45 and just describe current contents).

Severity: HIGH — deleted capability + dangling doc is a double loss that coverage
gates cannot see.

Added by: oss-reviewer self-mutation on 2026-07-04 after observing
charmander PR #52: three files referencing "a downstream view [that] turns the
per-table Glue request counts into the final cost estimate" while the deleted
cost_estimate_query.sql's COALESCE extraction and unit prices existed nowhere else in
the tree (successor was a queued issue, not a view).

### 4.53 Conjoined-subject overclaim in provenance comments (HIGH)

A comment asserting a property of multiple named artifacts — "A and B each carry X",
"both tables store only the lexicographically first member" — where the property holds
for only one conjunct. The author (or model) verified one source and stamped the fact
onto the conjunction; the falsehood is invisible unless each conjunct is checked
independently, and downstream readers inherit a wrong invariant about the unverified
one.

```
\b\w[\w.]*\s+and\s+\w[\w.]*\s+each\b
\b(both|each of)\s+(the\s+)?\w+[\w.]*\s+(tables|sources|modules|jobs|columns)\b
```

Then verify the claimed property against EVERY conjunct's actual implementation, not
just one.

Exclude: claims trivially true by shared construction (both generated from one
template/function — verify the shared origin exists).

Severity: HIGH — a factual claim about code that is wrong for at least one named
subject; CRITICAL if it ships in deployed resource metadata.

Added by: oss-reviewer self-mutation on 2026-07-05 after observing
charmander PR #58 `features_edgar.sql:20-23` claiming eight_k_filings AND
form4_transactions "each carry a REPRESENTATIVE ticker … only the lexicographically
first S&P member ticker" — true for 8-K's build_universe, false for form4's
read_cik_symbol_map (no S&P filter, lowest cik_map symbol).

### 4.54 Parent-scope deployed description falsified by an artifact-adding PR (HIGH)

A PR adds a table/module/resource under a parent whose OWN deployed description makes
a claim the addition breaks — a closed enumeration ("this domain holds X plus Y") or a
domain-defining property ("datasets with no specific external source"). The parent file
is untouched by the diff, so file-scoped review never reads it, and the live catalog
metadata becomes wrong at merge. §4.46's closed-inventory drift transposed one level up
the hierarchy, landing in deployed metadata instead of docs.

Detection: for every added `lib/databases/<db>/<table>.json` (or equivalent
child-artifact), READ the untouched parent `<db>/<db>.json` description and check (a)
any table enumeration includes the newcomer, (b) any domain-property claim holds for
it. Same rule generalizes to package __init__ docstrings, module indexes, service
manifests.

Exclude: parent descriptions written categorically with no enumeration or falsifiable
property claim.

Severity: HIGH (deploys as live metadata); pin the parent description in a test where
the repo pins such strings, so the next addition fails loudly.

Added by: oss-reviewer self-mutation on 2026-07-05 after the same shape fired in TWO
sibling charmander PRs in one pass: #63 (gdelt.json still enumerating "file_list plus
events" while org_aliases arrives, eodhd-derived) and #64 (misc.json claiming "no
specific external source" while geomagnetic/sunspots each have exactly one).

### 4.55 Wide-range job validated only inside the dependency's comfortable sub-range (BLOCKER-class)

A job declares a wide production range (a century of dates, a full ID space) but every
test that touches the REAL dependency uses a narrow modern window, and the end-to-end
assembly test mocks the loader. Coverage reads 100%, the suite is green, and the job is
dead on arrival at the range edge — because libraries silently degrade outside their
comfortable sub-range. Named trap: anything built on pandas holiday rules clips at
`AbstractHolidayCalendar.start_date = 1970-01-01`, so historical calendars silently
lose all rule-derived entries before 1970.

Detection: compare the job's declared range constants against the widest range any
real-dependency test exercises; when the production range strictly contains all tested
ranges AND the assembly test mocks the dependency loader, demand a range-edge smoke
test (run the real loader over the true range; assert the derived artifact straddles
both edges).

Exclude: dependencies with contractually unbounded ranges verified in the PR body;
ranges where the edge behavior is explicitly documented and asserted.

Severity: BLOCKER-class when the crash/degradation is reproducible at the range edge;
HIGH when merely unproven.

Added by: oss-reviewer self-mutation on 2026-07-05 after charmander PR #65:
misc.market_holidays declared 1900-2060, all real-calendar tests used post-2000
windows, the get_data_frame test mocked the loader — and the real build crashed on its
first row (zero rule-derived holidays pre-1970 due to the pandas clip).

### 4.56 Source-gap rationalized as source honesty (HIGH; §4.47 sub-family)

A description or docstring explains surprising ABSENCES in derived data as a virtue of
upstream fidelity — "the early record genuinely differs from the modern holiday set",
"the source is authoritative even where it disagrees" — when the absences are actually
a dependency artifact (a clip, a default bound, an unsupported era). The rationalization
is plausible, flattering to the implementation, and restated across docstring + model
description + PR body (the same-claim-3x residue signature).

Detection: whenever a doc explains missing/absent derived data as an upstream-record
property, spot-check a few specific absences against independently known facts
(Christmas 1899 WAS an NYSE holiday). One contradicting fact converts the claim from
documentation to fabrication.

Exclude: gap explanations backed by a citation to the source's own documentation of
the gap.

Severity: HIGH; CRITICAL when the rationalization ships in deployed metadata.

Added by: oss-reviewer self-mutation on 2026-07-05 after charmander PR #65 shipped
"its historical record differs from the modern holiday set" (docstring + model
description + PR body) for absences caused entirely by the pandas 1970 rule clip.

### 4.57 Missing-object status and retention window never probed on a file-per-period feed (BLOCKER-class)

Jobs over file-per-period HTTP feeds (one file per day/quarter) carry two load-bearing
assumptions that success-case probes never touch: (a) WHAT STATUS a missing period
returns — S3/CloudFront-backed feeds without ListBucket return **403 AccessDenied**,
not 404, for absent keys, so a 404-only skip branch is unreachable and the first
holiday kills the job; (b) the endpoint's RETENTION WINDOW — the feed's documented
history start is not the CDN's rolling retention, so a hardcoded floor can 403 on
request #1, and an anti-join resume cursor turns permanently-missing periods into an
every-run re-fetch treadmill.

Detection: for any such job, demand probe evidence for BOTH a known-missing period (a
holiday/weekend — what status?) and the declared floor date itself (does it serve?).
Mocks/tests that encode 404-for-missing on an S3-backed source are the tell; the fix
gates expected gaps on a calendar so absences on genuine trading/business periods stay
loud.

Exclude: feeds with documented 404 semantics verified by probe; floors probed live in
the PR evidence.

Severity: BLOCKER-class — the job is dead on arrival or silently wedged, with green
gates.

Added by: oss-reviewer self-mutation on 2026-07-05 after charmander PR #66: FINRA's
CDN 403s on five probed holidays + a Sunday and on the declared 2009-08-03 floor
(served window starts ~2018-Q3); the code skipped only 404 and a test enshrined
crash-on-403.

### 4.58 "UTC" claimed in deployed metadata for a local-clock stamp (HIGH)

A model/column description promises UTC semantics ("UTC date this row was ingested")
while the code stamps `date.today()` / `datetime.now()` — the host's LOCAL clock.
Around UTC midnight the stored value contradicts the deployed contract, skewing
snapshot axes and same-day idempotency claims. Trivially greppable and fired twice in
one week in one repo.

```
# descriptions claiming UTC
[Uu][Tt][Cc]
# clock calls that are local
date\.today\(\)
datetime\.now\(\)(?!.*timezone)
```
Rule: for every "UTC" in a deployed description, trace the stamping call; it must be
timezone-aware (`datetime.now(timezone.utc)`).

Exclude: descriptions saying "local run date"; code on hosts pinned to UTC by
documented convention (still flag INFO — hosts move).

Severity: HIGH (deployed-contract-vs-implementation drift).

Added by: oss-reviewer self-mutation on 2026-07-05 after charmander PR #67
(`earnings_trends.py` `date.today()` vs "UTC date this row was ingested"), the same
class the ops.cost_estimates review had just enforced correctly.

### 4.59 Probe evidence gathered with a different HTTP client than production (HIGH; §4.55 sibling)

Live-source probe evidence (status codes, availability, formats) collected with curl /
a browser / WebFetch while production requests go through a language HTTP library with
a different default User-Agent, TLS stack, or header set. CDNs and WAFs filter on
exactly those differences — a URL that curls 200 can 403 the library client
wholesale, so the probes validate the URL while the CLIENT was never exercised. The
resulting failure is total (every request rejected) yet invisible to both the probe
evidence and the mocked test suite.

Detection: for any PR whose evidence cites live probes, check WHAT ISSUED them — the
evidence must include at least one request through the production code path (the
actual download helper in the actual venv), not just the endpoint. A cheap reviewer
check: run the repo's own download function against one probed URL.

Exclude: probes explicitly executed through the production client with the invocation
recorded; sources verified to ignore UA/headers.

Severity: HIGH — and BLOCKER-class when combined with a skip-on-4xx path, because the
blanket rejection then reads as "everything absent" instead of crashing.

Added by: oss-reviewer self-mutation on 2026-07-05 after charmander PR #66's first
live run: cdn.finra.org serves curl (all review probes) but 403s the default
Python-urllib UA (the job), so floor discovery read the whole window as absent.

### 4.60 Sizing rationale contradicted by the PR's own pinned sample (HIGH)

A tuning constant (batch size, fan-out width, timeout, quota) justified in a comment or
PR body by quoted per-artifact sizes/rates of a remote source ("a 15-minute archive runs
~3MB", "an export is ~35-50KB", "so a batch is ~2GB, comparable to X") that no probe
verified. The strongest sub-shape: the PR pins a SPECIFIC sample artifact as its format
evidence while quoting a size range that the pinned artifact itself falls outside — the
evidence contradicts its own exhibit, proving the figures were estimated, not measured.
Backfill pipelines make this worse: source files often differ 2-5x across the ingest
window (older archives can be the largest), so a constant sized to the quoted figures can
be an order of magnitude off at the range edge.

```
# comments quoting source sizes to justify a constant
runs?\s+~?\d+(\.\d+)?\s*(KB|MB|GB)
~\d+(\.\d+)?\s*(KB|MB|GB)\s*(average|avg|each|per)
comparable\s+to\s+the\s+~?\d
```

Detection: for each quoted figure, HEAD-probe the cited artifacts (`curl -sI` →
Content-Length) at 3+ points across the declared ingest window INCLUDING the window's
start (backfill edge) and, when the PR pins a sample, that exact sample. A quoted range
that excludes the pinned sample, or a derived total ("batch ≈ NGB") off by >2x against
probed sizes, is the finding.

Exclude: figures explicitly labelled as measured with the measurement recorded (date,
command, observed values); constants whose comment claims no size rationale.

Severity: HIGH — the constant's documented envelope misstates the real resource
footprint (memory, transfer, commit size) and the next tuner inherits fake numbers;
escalate when the derived workload at the range edge plausibly breaks the runtime
(driver/worker memory), since green unit tests never touch real payload sizes.

Added by: oss-reviewer self-mutation on 2026-07-05 after observing charmander PR #81
`gkg_org_hits.py:41-49` justifying BATCH_FILE_COUNT=500 with "~3MB (English) to ~7MB
(translated)" GKG archives, "sub-MB" exports, and "comparable to the ~2-3GB gdelt.events
targets": live probes read English GKG 5.4-13.4MB and translated 6.7-29.4MB (2018
backfill edge largest, so a 500-file batch is ~4-10GB, not ~2GB), events batches ~0.4-1.2GB
(not 2-3GB), and the PR's own pinned sample (20231215120000.gkg.csv.zip, claimed
~2.7-3.2MB) is 6.05MB.

### 4.61 LEFT-JOIN-fed column declared non-nullable against repo's own nullable convention (HIGH; §4.50 sibling)

A model/schema file declares columns populated by a SQL `LEFT JOIN` from a secondary
source as non-nullable (`"nullable": false` in an eevee/FDD-style table model, `NOT
NULL` in a DDL, a Iceberg/Avro `required` field) while every structurally-equivalent
sibling table in the same repo — one whose columns are populated the same way, via a
`LEFT JOIN` onto a source that "usually" matches — marks the analogous columns
nullable. The repo has already converged on a house convention (LEFT JOIN ⇒ nullable,
with `IsComplete`/DQ-style checks doing the "should always be present" enforcement
instead of a hard schema constraint) and this one table silently breaks it. The
generalization of §4.50: instead of a Python coercer returning `None` into a
non-nullable slot, the source of the potential null is a JOIN the code's own comments
describe as deliberately defensive ("kept 1:1 even if the upstream guarantee ever
changes") — meaning the author already knows a null is reachable, and the schema
declaration contradicts that stated intent. If the PR's own test suite exercises the
join-miss path and asserts NULL values reach that exact column, the contradiction is
self-proven, not speculative.

```
# In the new/changed model file: LEFT-JOIN-fed columns marked non-nullable
"nullable":\s*false
# Cross-check: does the query LEFT JOIN in a secondary source for that column?
LEFT JOIN
# Cross-check: does a sibling model in the repo mark the equivalent LEFT-JOIN-fed
# column nullable instead? (structural, not grep-able — compare column nullability
# across tables with the same join shape)
```

Detection: for any new/changed table model, find the columns sourced from a `LEFT
JOIN` side (not the anchor/driving side) in its packaged query. If the model marks
them `nullable: false`, check (a) whether the PR's own tests feed a join-miss case
and assert a NULL lands in that column, and (b) whether other tables in the repo with
the same "LEFT JOIN from a usually-but-not-guaranteed-complete source" shape mark the
equivalent columns nullable. Either one confirms the finding.

Exclude: LEFT JOINs whose miss side is mathematically impossible (a self-join, an
enum-exhaustive lookup) with no repo precedent to contradict; repos with no existing
nullable convention to break.

Severity: HIGH. The schema's `required`/`nullable: false` declaration will reject the
write (or silently misrepresent the guarantee) exactly in the scenario the LEFT JOIN
was written to survive, so the comment's claimed safety property ("row is kept, never
dropped") is not actually delivered by the code as shipped. Not BLOCKER/CRITICAL when
the join-miss path is provably unreachable today (a stronger upstream invariant holds
by construction) — but still a live landmine if that invariant is ever relaxed, and an
internal inconsistency the PR should resolve one way or the other (mark nullable and
rely on the DQ completeness check, or drop the LEFT JOIN and inner-join to match the
non-nullable claim).

Added by: oss-reviewer self-mutation on 2026-07-16 after observing
`lib/databases/features_v2/price.json` (charmander PR #363) marking `open`, `high`,
`low`, `close`, `adjusted_close`, `volume` — all populated via a `LEFT JOIN` onto
`eodhd.historical_prices` — as `nullable: false`, while `price.sql`'s own comment says
the LEFT JOIN "keeps this table 1:1 with the anchor even if that guarantee ever
changes," and `test_price.py::test_an_anchor_row_without_a_bar_is_kept_with_null_values`
asserts all six columns are NULL for an anchor row with no matching bar. Every
structurally-equivalent LEFT-JOIN-fed table in the repo (`features/features_all.json`,
`features/features_calendar.json`, etc.) marks the analogous columns nullable.

### 4.62 Fabricated specific-date citation in a "verified via archived snapshot" lag/schedule rationale (HIGH; §4.47 sibling)

A release-lag / schedule-derivation comment cites two or more specific dated examples
as if pulled from an actual web.archive.org (or equivalent historical) snapshot ("Final
Jan 2020 by Feb 2"; "Final Mar 2023 on Mar 31") to justify a numeric constant (a
`publication_lag_days`-style value). One example checks out against independently
verifiable history; another does not — the real event happened on a different date
than claimed, sometimes one that would change whether the constant is even safe. The
mix of one accurate and one fabricated citation is the tell: a wholly invented
rationale would be uniformly wrong and easy to catch on a single spot-check: a
plausible mix survives review because the reviewer checks the first example, finds it
right, and stops there instead of checking every conjunct.

```
verified (via|against) an? archived?\b.*(snapshot|page)
\([^()]*\d{4}[^()]*;[^()]*\d{4}[^()]*\)      # two dated parenthetical examples in one rationale
```

Detection: for every "verified via archived / historical snapshot" comment citing 2+
dated examples, independently verify EACH example against a source outside the PR (a
contemporary news article, the releasing body's own historical schedule page, ALFRED
vintage dates) — checking only the first example is insufficient, per §4.53's
conjoined-subject lesson applied to citations instead of code claims. Recompute the
constant against the WORST (latest) of the independently-verified dates, not the
claimed one.

Exclude: rationales whose examples are cited with a working, directly-openable archive
URL (not just prose) the reviewer can follow to confirm; single-example rationales
(nothing to cross-check against for a mix).

Severity: HIGH — the fabricated example didn't happen to break the chosen constant this
time (the real value was more conservative than the false citation implied), but the
pattern is a live risk: the next such comment's fabricated example may be the one that
sized the constant, producing a real leak. Escalate to CRITICAL if the fabricated
citation's implied lag exceeds the chosen constant (a leak this run).

Added by: oss-reviewer self-mutation on 2026-07-16 after observing
`src/charmander/queries/features_v2/macro.sql:61-62` (charmander PR #373) citing "Final
Jan 2020 by Feb 2" as an archived sca.isr.umich.edu snapshot justifying UMCSENT's 31-day
lag, alongside a correct sibling citation ("Final Mar 2023 on Mar 31"); independent
sources (advisorperspectives.com, Nasdaq coverage) confirm the actual Jan 2020 Final
reading released Jan 31, 2020 — within the same reference month as the comment's own
stated rule — and the Feb 2 date does not correspond to any real event.

### 4.63 Prose comparison claim on a metric the results table marks non-comparable (HIGH)

A results table marks one row's value for a metric column as "n/a" (or leaves it blank) —
signaling the author judged the metric not comparable across that row's differing
conditions (most often a return-horizon mismatch between candidates) — while the prose
narrative discussing that same table asserts an explicit win/loss/beat comparison on that
exact metric against the "n/a" row. The n/a marking is itself evidence the metric needs a
normalized variant before it can be compared; the same table often already carries that
fix for a sibling metric (a "/week"-scaled column sitting right next to the raw one) but
never computed the equivalent for the flagged metric, so the prose comparison silently
reuses a raw, un-normalized number against a different-condition baseline.

Detection: for each results table with an explicit non-comparability marker (n/a, --,
blank) in one row's cell, grep the surrounding prose (same section) for a sentence naming
that metric alongside a comparison verb (beats, matches, exceeds, outperforms, below,
above, higher/lower than) directed at the same row. A hit is the finding.

```
\bn/a\b|\| *-- *\|
\b(beats?|matches?|exceeds?|outperforms?|below|above|higher|lower)\s+(it|the incumbent|the (control|baseline|weekly \w+))\s+on\s+\w
```

Exclude: prose comparisons phrased entirely in terms of the candidate's own absolute value
with no explicit "vs incumbent" framing; tables where the n/a is later resolved by a
companion scaled column that IS what the prose comparison actually uses (the correct
pattern, e.g. a `long_short` column marked n/a while `ls/wk` carries the real comparison).

Severity: HIGH — the same document already demonstrates it knows how to fix this (a sibling
metric got the horizon-normalization treatment) but skipped it for this metric, so the
flagged comparison compares a longer-horizon number to a shorter-horizon baseline and calls
it a "beat."

Added by: oss-reviewer self-mutation on 2026-07-17 after observing `docs/model-experiments.md`
(charmander PR #382) marking the weekly incumbent's decile-spread cell "n/a" in the
features_v2 GRU comparison table — for the same horizon-mismatch reason the doc's own
`ls/wk` column exists to fix for long-short — while the "Honest verdict" prose two
paragraphs later asserts the GRU "beats it ... on hit and decile," implicitly comparing the
GRU's 21-day-horizon decile spread (0.0041) against the incumbent's un-scaled 5-day-horizon
decile spread (0.0012, from this same file's original bake-off table) with no like-for-like
normalization.

### 4.64 Column-level semantic edit not propagated to the file's own top-level description (HIGH)

A PR changes a column's documented NULL/value semantics (adds a new state, e.g. "NULL when
every source row's amount is unknown") in its per-column `description`, but the same
model/schema file's own top-level `description` — which summarizes the same block and, for
eevee/FDD-style table models, deploys verbatim as the live Glue table comment (or an
equivalent catalog/OpenAPI/GraphQL summary) — is left as it was, still describing only the
prior (simpler) semantics. Both fields sit in the touched file, so a file-scoped diff review
sees the edit; the drift survives only because reviewers read the column docs and skip
re-reading the table-level prose the diff didn't touch. §4.54's parent-scope drift moved one
level down: same file, sibling description fields, no parent hop required.

Detection: for any diff that edits a column's `description` field in a table/schema model
(`lib/databases/**/*.json`, OpenAPI `properties.*.description`, GraphQL field docs, protobuf
field comments) to add or change a stated NULL/value-semantics claim, read the file's own
top-level `description` (or equivalent summary docstring) in the SAME file and confirm it
still accurately describes that column's behavior. Flag when the top-level summary omits or
contradicts the newly-stated semantics.

Exclude: top-level descriptions written categorically ("counts and amounts, see each column
for its own NULL/zero convention") that make no falsifiable claim about the changed column.

Severity: HIGH when the top-level field deploys as live catalog/API metadata (per repo
convention, e.g. `eevee-to-iceberg.ts`'s `comment: definition.description` on a Glue table);
INFO when it's purely a repo-internal doc string with no deploy path.

Added by: oss-reviewer self-mutation on 2026-07-17 after observing
charmander PR #394 (`fix/384-government-null-amounts`): `lib/databases/features_v2/government.json`'s
`gov_contract_amount` / `lobbying_amount` column descriptions were rewritten to state a new
three-state NULL semantics (NULL when every award/filing amount on a day is unknown, distinct
from the pre-existing floor-NULL and zero-fill states), while the file's own top-level table
`description` — which `eevee-to-iceberg.ts:347` deploys as the Glue table's `comment` — still
reads "award count and total obligated amount, which may be negative..." / "total reported
spend and distinct registrants," with no mention of the new NULL case.

### 4.65 Categorical grouping silently drops records whose reference fails a lookup the same module enforces loudly elsewhere (HIGH)

A function that projects/groups child records under a fixed set of parent categories (e.g. one
section per registry entry, one bucket per enum member) by filtering `record[field] == category`
for each category in turn, when `field` is a foreign-key-shaped reference (a name that must
belong to a known registry/set). A record whose reference names a category NOT in the known set
is never selected by any iteration and disappears from the projection with no error, while a
SIBLING function in the same module resolves the identical reference type through a lookup that
RAISES on the unknown case (e.g. a `_index`/`_key` helper). The asymmetry means malformed data is
caught when it flows through one code path and silently dropped when it flows through another —
the exact hazard a "report every problem, never half-apply/half-render" project convention exists
to prevent.

Detection: for each function that iterates a known category list and filters children into it
(`[x for x in items if x[field] == category]` inside a `for category in known_categories` loop),
find the sibling function(s) in the same module that resolve `field`'s value type into a category
index (a `book_index`/`_resolve`-style raise-on-miss helper). If the grouping function does NOT
call that helper (or something equivalent) before or during filtering, the finding is confirmed.
Verify empirically: construct a record naming a nonexistent category and confirm the projection's
output is silent (no exception, no diagnostic line) rather than raising or emitting an
"N unassigned records" note.

```
for \w+ in \w*(registry|categories|known)\w*\[?
.*==\s*\w+\[.["']name["'].\]
```

Exclude: grouping functions whose category set is provably exhaustive (an actual Python `Enum`
with no "unknown" case reachable at the type level); projections that explicitly emit a
"N records unassigned" summary line for the non-matching remainder.

Severity: HIGH. The malformed reference doesn't crash — it just vanishes from the human-facing
document with no trace, so whoever audits the rendered output has no way to know something was
silently excluded; escalate to CRITICAL if the same drop can also mask a security-relevant
reference an authorization check groups by.

Added by: oss-reviewer self-mutation on 2026-07-22 after observing `src/grimer/universe.py:754`
(`grimer` PR #12): `_timeline_content` groups events into per-book sections via
`event["chapter"]["book"] == book["name"]` with no fallback bucket, while the sibling
`_latest_status`/`_entity_section` path resolves the identical `{book, chapter}` shape through
`time_ref_key` -> `book_index`, which raises `GraphError` on an unknown book. An event whose
`chapter.book` names a book absent from the registry silently disappears from `timeline.md` with
no error, confirmed empirically (`_timeline_content` run on a graph with one such event renders
zero lines about it).

### 4.65 "Learned it the hard way" corrective paragraph contradicts its own lead-in (HIGH)

A doc addition (CLAUDE.md gotcha, PR body, README) opens with a summary sentence stating a
mechanism's host view, size, or alignment, then is immediately followed by a "learned the
hard way" / "learned empirically" / "three approaches that FAIL" paragraph narrating the
real debugging journey — and that corrective paragraph's actual conclusion contradicts the
opening sentence on a concrete, checkable fact (which view hosts it, its pixel size, its
alignment). The opening paragraph reads as boilerplate genericized from a sibling doc entry
(the shape of an existing similar gotcha, drafted before the empirical debugging happened);
the corrective paragraph is the verified truth appended afterward, and the two were never
reconciled into one consistent description. A reader who stops after the first sentence — or
skims past the correction — carries away false information.

```
learned (the hard way|empirically)
```

Detection: for every match, read the paragraph immediately preceding it and diff its concrete
claims (host view/component name, size in points, alignment adverb, named modifiers like
`.contentShape(Rectangle())`) against the corrective paragraph's stated final mechanism AND
against the actual source file the doc describes. A mismatch on any axis (wrong host view,
wrong size, a claimed modifier that isn't actually applied in the code) is the finding —
verify against the real implementation, not just internal doc consistency, since the opening
paragraph and the source can independently agree with each other while the corrective
paragraph is what's actually shipped, or vice versa.

Exclude: docs deliberately framed as "naively, you might try X" before debunking it in the
same breath (an intentional pedagogical device, not leftover residue) — look for explicit
signposting like "at first" / "naively" / "you'd think."

Severity: HIGH. The reader who stops after the first paragraph gets false information about
where/how the mechanism lives, and it will mislead the next engineer editing sibling code
under the wrong assumption about the host view, size, or a modifier they believe is present.

Added by: oss-reviewer self-mutation on 2026-07-22 after observing
`CLAUDE.md:1185-1214` (Seedling PR #329, `fix/326-consecutive-day-age-collapse`) opening with
"a hidden 1×1-pt DEBUG button (`seed-river-button`) in `ContentView`'s bottom-trailing corner,"
then two paragraphs later under "Invisible-but-tappable button pattern (learned the hard
way)" stating the actual button is a 44×44 `Color.clear` view mounted via
`.overlay(alignment: .bottom)` on `KidsListView` (the sidebar), explicitly NOT `ContentView` —
three facts (host view, size, alignment) all contradicted. Confirmed against
`Seedling/KidsListView.swift`'s actual `riverSeedButton` implementation, whose own doc-comment
compounds the error by claiming it carries `.contentShape(Rectangle())` (mirroring the
project's sibling 1×1pt debug buttons) when no such modifier is applied anywhere in the
`Button` chain.

### 4.66 Cross-module import of underscore-prefixed "private" helpers (HIGH)

A module imports one or more leading-underscore names — Python's own convention for
"module-private, safe to refactor without notice" — from a SIBLING module (not a package
`__init__.py` re-export of its own internals) to reuse logic instead of promoting the
symbol to a public name or extracting a shared internal module. The reuse is often
deliberate and even well-commented ("these validators only touch coordinate-free fields,
so they apply unchanged here"), which makes it easy to wave through in review — but the
leading underscore still lies to every other reader and to the next person who edits the
source module: nothing signals that a "private" rename or removal there is now a breaking
change for the importer, and no test failure in the source module's own suite would catch
the break until the importer's suite runs.

```
from\s+[\w.]+\s+import\s+\(?[^)]*\b_[a-z][a-z0-9_]*\b
```

Detection: for each imported name matching the leading-underscore pattern, confirm it is
defined at module level (`def _name` / `class _name`) in the SOURCE module rather than
re-exported through the importing package's own `__init__.py`. That confirms the import
crosses a privacy boundary rather than consuming a package's declared internal API.

Exclude: intra-package `__init__.py` re-exports; codebases with a documented convention
(a module docstring or CLAUDE.md note) that leading-underscore names ARE the package's
internal cross-module API — the exemption is that a policy exists, not that the reuse is
technically safe.

Severity: HIGH. The coupling is real even when the reuse rationale is sound: the source
module's maintainer has no signal that "private" helpers are load-bearing for another
module, so a future rename, signature change, or deletion there breaks the importer
silently until its own test suite (if any) catches it.

Added by: oss-reviewer self-mutation on 2026-07-22 after observing
`src/grimer/universe.py:18-22` (grimer PR #14) importing five leading-underscore functions
(`_find_active_relationship`, `_validate_added_entities`, `_validate_events`,
`_validate_relationships`, `_validate_updates`) from `graph.py` to reuse v1 delta-validation
logic for the v2 schema — a deliberate, well-documented DRY trade-off, but one that leaves
`graph.py`'s "private" helpers load-bearing for `universe.py` with no signal from Python's
normal privacy convention.

### 4.67 New marker/state written by one command, but sibling commands reading the same file are never taught to expect it (CRITICAL)

A PR introduces a state-transition marker — a sentinel object written in place of a
file's normal shape to record "this record has moved / been superseded / been
finalized" (a `{"migrated_to": "..."}` pointer replacing a data file, a `{"archived":
true}` stub, a tombstone record). The command that WRITES the marker (and the command
that re-reads it to reject a double-transition) are updated and tested. But every OTHER
existing command that reads the same file path — unaware the shape can now be a marker
instead of the normal payload — still destructures it with direct key access
(`graph["entities"]`, `record["items"]`) and crashes with a raw, uncaught language-level
exception (`KeyError`, `TypeError: undefined is not an object`) instead of the codebase's
own domain error type. The bug is invisible to the PR's own test suite because every new
test exercises the write path and the immediate re-read/reject path, never "now run an
unrelated pre-existing command against the file the new feature just replaced."

Detection rule: when a diff adds a function that overwrites a file with a new/sentinel
shape (grep the diff for a `write_*` / `save_*` call whose payload is a small literal
dict distinct from the module's normal schema), enumerate every OTHER command/entry point
in the codebase that reads the same file path unconditionally (not gated behind a
type/shape check first). For each, manually invoke it against a file left in the new
marker state and confirm it either handles the marker gracefully or raises the app's own
error type — not a bare interpreter-level exception. This requires runtime testing beyond
grep; a Phase-1-style "exercise every command against every state the PR introduces"
pass is the only way to catch it.

```
# Diff-side signal: a new small-literal write to a path also read elsewhere
write_(file|text)\(.*json\.dumps\(\{["']?\w+["']?:\s
```

Exclude: markers written to a NEW, separate file/path (nothing else reads the old path
so there's no shape ambiguity); codebases where every reader already goes through a
shape-checking loader (`if not isinstance(x, dict) or "schema" not in x: raise ...`)
before destructuring.

Severity: CRITICAL. The crash surfaces as a raw traceback on ordinary, previously-working
CLI usage (not just adversarial input), exits with the interpreter's default code instead
of the app's controlled error exit code, and the PR's own extensive new test suite gives
zero signal that the gap exists — every new test only exercises the write/re-read pair the
author was thinking about.

Added by: oss-reviewer self-mutation on 2026-07-22 after observing grimer PR #16: `migrate`
replaces a migrated book's `graph/graph.json` with `{"migrated_to": "<universe>"}`
(`universe.mark_book_migrated`, `src/grimer/universe.py:706-718`) and `load_migratable_graph`
correctly rejects a second `migrate` against that marker. But `check`, `render`, `apply`, and
the standalone `query` path (`src/grimer/cli.py` `_run_command`/`_run_query`) all call the
unchanged `graphlib.load_graph` on the same path and then destructure `graph["entities"]`
directly, so running any of them against a just-migrated book raises an uncaught `KeyError:
'entities'` with a full Python traceback and exit code 1 — verified by manually migrating a
book and then running all four commands against it. None of the 13 new migrate-focused tests
in `test_cli.py`/`test_universe.py` exercise a sibling command against a migrated book, so
100% coverage and all-green CI shipped alongside the gap.

### 4.68 Positional argument grows a second dispatch meaning that the README never learns (HIGH)

A CLI command's positional argument (a "book" name, a "target" name, an "id") is extended
to also resolve to a second kind of resource via a runtime probe (a sibling registry file
existing, a type tag, a different directory root) — `argparse` `help=` text for the
argument is dutifully updated to describe both meanings ("Book directory name, or a
universe name if one is registered under `--universes-root`"), and the new dispatch path
gets full test coverage. But the README's own CLI reference table, which already lists
that command with its original one-line description, is never revisited — so a reader
who only reads the README (the documented public entry point) has no way to discover the
command now does something entirely different depending on what name they pass. This is
the sibling of §4.46 (closed-inventory table missing a new row): here the row already
exists and stays untouched, but the *behavior the row describes* silently grew a second
mode. Repeated across several PRs, the gap compounds — each PR touches only the one verb
it's wiring, and the README command table drifts further behind the argparse help text
with every release.

Detection rule: for each subcommand in the CLI's argument parser, extract its positional
`help=` string. If the help string names two distinct resolution modes (look for `" or "`,
`"otherwise"`, `"takes precedence"`, "in universe mode" phrasing) but the README's
corresponding usage-block line for that same command is a single-purpose one-liner with no
mention of the second mode, that's the finding. Cross-check by grepping the README for the
second mode's keyword (e.g. `universe`) near the command's usage line.

```
# argparse help text signals dual dispatch
help=.*\bor\b.*\bif\b.*\bregistered\b
help=.*\btakes precedence\b
# README usage line for the same subcommand — grep for the second-mode keyword nearby
```

Exclude: README usage blocks that already document the second mode in prose elsewhere in
the same file (some projects put the polymorphism note in a paragraph below the code
block instead of inline); CLIs whose README explicitly says "run `--help` for full usage"
in place of a usage table (nothing to drift against).

Severity: HIGH. The gap is invisible to tests and CI (the code path is fully exercised),
and only surfaces when a stranger reads the README, tries the documented one-mode usage,
and has no way to discover the mode their actual use case needs.

### 4.69 Truncated placeholder identifier in a doc comment that resolves to nothing (INFO)

A doc comment or docstring points the reader at a symbol using an ellipsis-truncated,
tentative-looking name — `` `SubMonthAll...` tests``, ``see the `Foo...` helper below``
— that never actually exists anywhere in the file or repo under that prefix. The real,
finished identifier ended up named something else entirely (e.g. the test method is
actually `testYoungBabyAllViewUsesDaySuffixInsteadOfZeroMonth`), but a comment written
earlier in the same editing session — before the name was finalized — was never swept
back to match. Harmless functionally (nothing dereferences the name), but it sends the
next reader searching the file for a symbol that isn't there, and it's a distinctive
fingerprint of draft-then-rename authoring: a human polishing their own comment before
committing rarely leaves a "..." stand-in for a name they were about to type anyway.

Detection: grep doc comments for a backtick-quoted CamelCase-ish token immediately
followed by an ellipsis, then verify no declaration in the file (or repo) starts with
that prefix.

```
`[A-Z][A-Za-z]*\.\.\.`
```

Confirm by then grepping the same file for `func test<prefix>` / `class <prefix>` /
`struct <prefix>` and finding zero matches.

Exclude: comments explicitly marked as a naming convention/pattern rather than a
pointer to one specific symbol (e.g. "any test prefixed `Foo...` counts", stated as a
rule rather than "see the `Foo...` tests").

Severity: INFO. Cosmetic doc drift, zero runtime impact — but real, and cheap to fix
(rename the comment to match the actual symbol).

Added by: oss-reviewer self-mutation on 2026-07-23 after observing Seedling PR #331:
`ChartXAxisUnitLabelsUITests.swift`'s file-header comment reads "see the
`SubMonthAll...` tests at the bottom of this file," but the only test added is
`testYoungBabyAllViewUsesDaySuffixInsteadOfZeroMonth` — no symbol anywhere in the repo
starts with `SubMonthAll`.

Added by: oss-reviewer self-mutation on 2026-07-22 after observing grimer PR #17: `cli.py`'s
`_BOOK_OR_UNIVERSE_HELP` string (`src/grimer/cli.py:27`) correctly documents that `apply`,
`check`, `render`, and `query`'s `book` positional "doubles as a universe name" and that "a
universe registry under `--universes-root` takes precedence" — but `README.md:33-45`'s CLI
usage block lists `apply <book>`, `check <book>`, `render <book>` with no mention that a
universe name works too, even though this PR is specifically the one that wires the
universe dispatch path into `apply`/`check`/`render` (`query` already had it from PR #11,
same gap, one PR earlier).

### 4.70 Public method orphaned by its own PR, docstring still names the removed caller (HIGH)

A refactor PR deletes the sole production call site of a public method (e.g. removing a
"write-through mirror" `.onChange` handler, an event listener, a dispatch branch) but
leaves the method itself in place with its pre-existing docstring, which explicitly names
the mechanism/caller that the SAME diff just deleted. The method now has zero production
callers — only a pre-existing unit test still exercises it — and its own doc comment is a
first-person lie about why it exists. This differs from ordinary dead code in that the diff
itself is the proof: the reviewer doesn't need external context to know the caller is gone,
because the deletion is a hunk in the same PR.

Detection rule: for each hunk that deletes a call site (an `.onChange`, event handler, or
call expression), grep the diff's unchanged (context) region and the rest of the file for a
public method/property whose docstring names the deleted mechanism by a distinctive noun
phrase ("write-through", "mirror", "bridge", "listener", callback name) that appears
verbatim in the deleted hunk. Then grep the whole tree (excluding `**/tests/**` /
`**/*Tests.*`) for other call sites of that method — zero non-test hits confirms orphaning.

```
# in the diff's deleted (-) lines: a call site being removed
^-.*\.(onChange|addEventListener|subscribe|addObserver)\(
# in the diff's unchanged context or a nearby doc comment: the same descriptive noun
(write-through|mirror|bridge|listener|callback)
```

Exclude: methods whose docstring is updated in the SAME PR to drop the stale reference (no
finding — the author already caught it); methods retained deliberately for a documented
future caller (a `// DEFERRED:`-adjacent note citing a tracked follow-up, itself subject to
§4.36); methods with a live non-test caller elsewhere in the tree.

Severity: HIGH. The docstring actively misleads the next reader about who calls this code,
and the method is now unreachable production surface — the two compound into a worse smell
than either alone (see §4.11 rule 3, "docstring lies about what the file does").

Added by: oss-reviewer self-mutation on 2026-07-24 after observing Seedling PR (per-kid
chart settings, Slice 3, issue #348): `Seedling/SettingsView.swift` deletes the `.onChange(of:
settings.currentGlobalChartSettings)` "Slice 2 write-through (issue #347)" mirror, but
`SeedlingEngine/Sources/SeedlingSettings/SettingsManager.swift:378-390`'s
`setChartSettings(_:forAllKids:)` keeps its docstring ("Applies `settings` to every id in
`childIDs` in a SINGLE persisted write (issue #347 write-through)... Mirrors the batch shape
of `migratePerKidChartSettings`") verbatim. `migratePerKidChartSettings` inlines its own loop
rather than calling `forAllKids`, and a tree-wide grep confirms the only remaining caller is
the pre-existing `SettingsManagerPerKidChartSettingsTests.swift` unit test — the method is
dead production API with a docstring describing a caller this exact PR removed.

### 4.71 Uniqueness validation checked before generation, blind to what generation will produce (CRITICAL)

A two-phase "validate the whole batch, then apply/generate" pipeline that adds a new
uniqueness invariant (an id, a slug, a key) which can come from EITHER an explicit
caller-supplied value OR a deferred auto-generation step run during apply. The validate
phase builds its collision set from explicit values only (stored values + explicit values
seen earlier in the same batch) — it never simulates what the generator will produce for
the earlier id-less entries, because doing so would mean running generation twice (once
to predict, once for real) or restructuring validate to interleave with apply. The result
is an order-dependent gap: an id-less entry followed by an explicit entry whose value
happens to equal what the generator computes for the id-less one sails through validation
(the explicit value collides with nothing in the checked set) and then collides for real
during apply, silently writing two records that share a supposedly-unique key. The
sibling shape: a merge/migrate function that adds an explicit collision check for one key
type (e.g. entity ids, checked via a set intersection before the merge) while a second key
type introduced in the SAME change (event ids, generated per-source-unit with no
cross-source namespacing) gets no equivalent check at all — the author reasoned about
uniqueness for the key type that already existed and didn't extend the same scrutiny to
the new one sitting right next to it in the same function.

Detection is structural, not grep-able: for any PR adding an auto-generated-or-explicit
uniqueness field, (a) find the validate-phase collision set and confirm it accounts for
values the apply-phase generator will itself produce for OTHER entries in the same batch,
not just explicit values; (b) for any merge function combining collections from multiple
sources, check whether EVERY newly-added identifier field has a collision check mirroring
whatever check already exists for a structurally parallel field in the same function. Both
are best confirmed by writing a two-line repro: one batch/merge with an id-less entry
immediately followed by (or merged with) an entry whose value equals the predicted
generated one, then asserting the resulting collection's ids are actually unique — a
green test suite and a clean invariant-checker are not evidence of correctness here,
because neither was written with this specific race in mind.

Severity: CRITICAL. The whole point of the feature being added is the uniqueness
invariant; a batch/merge that silently violates it, undetected by the PR's own
validator AND by the project's continuity/consistency checker, ships corrupted data
under a green build.

Added by: oss-reviewer self-mutation on 2026-07-24 after observing grimer PR #28 (`src/grimer/graph.py:577-614,672-692`):
`validate_events`'s `batch_ids` only accumulates EXPLICIT event ids seen so far, never
predicting what `generate_event_id` will assign to an earlier id-less entry in the same
delta — `apply_delta({"add_events": [{"chapter": 2, "summary": "Ada meets Bram in the
market."}, {"id": "ch2_ada_meets_bram_in", "chapter": 2, "summary": "..."}]})`
reproducibly writes two events sharing id `ch2_ada_meets_bram_in`, and `check_graph`
reports zero violations on the corrupted graph. The sibling shape fired in the same PR:
`migrate_book` (`src/grimer/universe.py:695-731`) explicitly checks entity-id collisions
across the book being merged and the target universe (`collisions = sorted(set(qualified["entities"])
& set(universe["graph"]["entities"]))`, raising on any hit) but performs no equivalent
check for event ids — `ch{chapter}_{summary-head-words}` carries no book-qualifying
namespace, so two books each with a chapter-1 "arrives" event merge into a universe with
duplicate event ids, again invisible to `check_universe`.

### 4.72 Create-path invariant not re-enforced on the sibling update/mutate path (CRITICAL)

A record type has a semantic invariant enforced at creation (`add_X`/`create_X` validator
rejects the record if some field is empty/missing/out-of-range) because downstream code
relies on it holding (a lookup, an aggregation, a rendering pass that indexes by that
field). The same PR (or a prior one) then adds a sibling `update_X`/`set_X`/`patch_X` verb
that can overwrite that exact field wholesale (`entry["field"] = new_value`, a full
replace, not a merge/append). The update-path validator checks structural things about the
new value (each element is a known reference, the right type) but never re-checks the
*same* invariant the create-path validator enforces — most commonly "must be non-empty" on
a list/string field. A caller can therefore never create an invalid record, but can always
reach the identical invalid state in one step by creating a valid record and immediately
replacing the guarded field with the empty/degenerate value the create path would have
rejected. The record survives with no error, and any downstream code that assumed the
create-path invariant (a reverse index keyed by the field, a rendering pass that expects at
least one entry) silently loses track of the record instead of crashing or flagging it.

Detection: for every `update_X`/`set_X`/`patch_X` validator, find its sibling
`add_X`/`create_X` validator in the same module and diff the two field-by-field. For each
field the update path can wholesale-replace, confirm every invariant the create path
enforces on that field (non-empty, non-null, min-length, matches-a-pattern) has a matching
check in the update path — not just "is each element a known reference," which is a
different, weaker property than "is the collection non-empty." Confirm empirically: build a
valid record via the create verb, then apply an update that sets the guarded field to its
empty/degenerate value; if it's accepted, grep the codebase for a reverse-index or
aggregation keyed by that field and confirm the record silently drops out of it.

```
if not \w+\["participants"\]|if not \w+\[.\w*(id|name|item)s.\]
```

Exclude: fields the update path only merges/appends into (a dict `.update()`, a list
`.append()`) rather than replacing wholesale — those can't reach the empty state through
the update path at all, since the field was already validated non-empty at creation and
merge/append can only grow it. Fields with no create-path invariant to begin with (the
create validator only checks type, no emptiness/range check) — nothing to re-enforce.

Severity: CRITICAL. The create path's whole purpose is guaranteeing the invariant holds for
every record in the graph; an update verb that can silently undo it produces exactly the
corrupted-but-unflagged state the create validator exists to prevent, and it ships under a
green test suite because the new tests exercise the update verb's happy path, not its
interaction with the older verb's guarantee.

Added by: oss-reviewer self-mutation on 2026-07-24 after observing grimer PR #29
(`src/grimer/graph.py:717-745`): `validate_events` rejects `add_events` entries with empty
`participants` (`if not event["participants"]: errors.append(...)`), but the same PR's
`validate_event_updates` only checks that each element of `set_participants` names a known
entity — it never checks the list is non-empty. `apply_delta({"update_events": [{"id":
"ev1", "chapter": 2, "set_participants": []}]})` on a graph with an existing event `ev1`
applies cleanly and leaves `ev1` with zero participants, reproduced empirically. Every
entity's dossier and `interaction_summary` index by scanning `event["participants"]`
(`src/grimer/graph.py:1021`, `:1064`), so the event silently vanishes from every
continuity view that keys off participants while still sitting in `graph["events"]`.

### 4.73 Comment claims a lint/test gate enforces an invariant that the tool config doesn't actually contain (HIGH)

A code comment (often in a test runner script, CI config, or module docstring) asserts that
a specific rule is "enforced by" a named linter/tool — "enforced by the flake8 ban on
unittest.mock imports under that directory", "guarded by the eslint no-restricted-imports
rule", "blocked by the pre-commit hook" — when the referenced tool's actual configuration
contains no rule of that shape at all. The claim reads as authoritative documentation and
survives review because nobody re-derives the enforcement mechanism from the config file;
the comment describes what SHOULD exist (or what an earlier draft intended to wire up) as
if it already does. The gap is invisible to CI (nothing tests the claim itself) and often
persists indefinitely because the violation the "gate" supposedly prevents never happens to
occur, so the missing enforcement is never exercised.

Detection: for every comment matching `enforced by`, `guarded by`, `blocked by`, `banned by`,
`the .* (lint|flake8|eslint|pre-commit|CI) (rule|check|gate)` referencing a specific tool and
a specific rule, open that tool's actual config (`.flake8`, `eslint.config.*`, `.pre-commit-config.yaml`,
`pyproject.toml` lint sections) and confirm a rule producing that exact effect exists. When in
doubt, empirically falsify it: deliberately introduce the "banned" pattern in a throwaway copy
and run the named tool — a clean exit confirms the claimed gate doesn't exist.

```
\b(enforced|guarded|blocked|banned|caught|prevented)\s+by\s+the\s+\w[\w\s-]*\s+(lint|flake8|eslint|ruff|pre-commit|CI|test)\b
```

Exclude: comments describing enforcement that genuinely exists (verified against the config);
comments phrased as aspirational/roadmap ("should eventually be enforced by...", itself then
subject to §4.36).

Severity: HIGH. A reviewer or contributor who trusts the comment believes a safety net exists
where none does; the fix is either to add the missing rule/plugin or to correct the comment to
describe the actual (weaker) guarantee.

Added by: oss-reviewer self-mutation on 2026-07-26 after observing `scripts/test.sh:10` in
psyduck_backend claiming the unit/integration test split is "enforced by the flake8 ban on
unittest.mock imports under that directory" — `.flake8` has no such rule (no `flake8-tidy-imports`,
no per-file forbidden-import config), confirmed empirically by adding a used `unittest.mock.patch`
import to a file under `integration_tests/` and running `flake8`: exit 0, zero violations.

### 4.74 README claim falsified by the same commit's own diff and commit-message rationale (CRITICAL)

A single commit (a) changes code behavior, (b) explains the change and its reason in the commit
message ("X used to require Y; that dependency is now removed because..."), and (c) touches
README.md in the same commit ("README rewritten") — yet leaves a README line describing the OLD
behavior the commit's own message says it eliminated. This is a stronger, more damning variant of
ordinary doc drift: the falsifying evidence isn't external (a later commit, a stale test count) but
sits in the exact same commit, so the contradiction was checkable by the author at review time with
zero extra research — they wrote the correct explanation in the commit message and then didn't
carry it two files over into the README they also touched.

Detection: for any commit whose message describes REMOVING a dependency/ordering-requirement/
behavior ("no longer requires", "removes the...dependency", "that removes the ordering entirely"),
grep the same commit's README.md diff (or the post-commit README, if README wasn't itself touched)
for language describing the old requirement. A hit is the finding — confirm by reading the actual
changed code/data (not just the prose) to establish which claim (commit message or README) matches
reality.

```
\bno longer requires?\b|\bremoves? the .*dependency\b|\bthat removes? the ordering\b
```
Then grep README.md for the specific old-requirement phrase the message says was eliminated.

Exclude: commits where the README was intentionally left describing a still-valid alternate path
(e.g., production still requires what local dev no longer does — verify per-stage applicability
before flagging).

Severity: CRITICAL. This is exactly the "does the README lie" question a fresh clone exposes, and
it's a false claim about a documented dependency ordering, not a cosmetic nit — a reader trying to
understand why `reset_db.sh` creates the superuser before seeding will reach a wrong conclusion.

Added by: oss-reviewer self-mutation on 2026-07-26 after observing PR #17 in psyduck_backend
(commit `7e87c85`, "Make local setup one non-interactive command that actually seeds"): the commit
message states "The seed SQL attributed every reference row to user id 1, which made seeding depend
on a superuser already existing... The audit columns are nullable... so they are now NULL. That
removes the ordering dependency entirely" — and the diff confirms `database/allergens.sql` etc.
changed `1, 1,` to `NULL, NULL,` — yet the same commit's rewritten `README.md:96` still reads
"Requires the superuser to exist first, since the SQL attributes every row to user 1," which is now
false on both counts (no dependency, and rows go to NULL not user 1).

### 4.95 Approval citation baked into an inline source comment (HIGH)

A comment justifying a config/architecture choice by citing WHO authorized it rather than
WHAT the code does or WHY it is technically correct — "(owner-approved trim)", "(approved by
PM)", "(signed off in review)", "(per stakeholder decision)". This is out-of-place provenance:
authorization metadata belongs in the commit message / PR description, which already has a
durable audit trail (git blame, PR review thread). Stamping it into source is a distinct
sub-pattern from ordinary task-referential leftovers (§4.1, which catches spec/brief/issue
citations) — the tell here is citing a *person's approval* rather than a *task artifact*. It
reads as an AI session including the human-in-the-loop context it was just given ("the owner
approved this trim") as if narrating its own justification for a stranger reviewing the diff,
rather than writing the comment a human author would write (which states the technical
rationale alone, with no appeal to authority).

```
\((?:owner|stakeholder|pm|manager|user|team)[- ]approved\b
\(approved by\b
\(per (?:owner|stakeholder|pm|team)('s)? (?:decision|request|approval)\)
\(signed off\b
```

Exclude: CHANGELOG.md entries; commit messages / PR descriptions (this is the correct home
for approval provenance); comments quoting an external compliance/audit requirement by
document ID ("per SOC2 control CC6.1") rather than a person's approval.

Severity: HIGH when the comment sits on a security- or cost-relevant config choice (as here);
INFO otherwise. The underlying decision may be entirely sound — the finding is about where the
provenance claim lives, not whether the decision was correct.

Added by: oss-reviewer self-mutation on 2026-08-02 after observing
`lib/psyduck-stack.ts:547` in psyduck_cdk (PR closing #32): `// WAF is only enabled in prod —
dev traffic is low-risk and the WebACL has a fixed monthly cost regardless of traffic
(owner-approved trim).` — the technical rationale (first sentence) is fine and belongs in
source; the parenthetical citing the owner's approval is provenance that belongs in the PR
description, not baked into a comment a future reader (or contributor with no access to that
approval thread) will trust at face value.

### 4.75 ASCII repo-tree diagram left stale by a fix that corrected the matching prose in the same file (HIGH)

A PR whose stated purpose is fixing stale/inaccurate documentation edits the PROSE describing a
file's existence, location, or path in a conventions doc (`CLAUDE.md`, `README.md`,
`ARCHITECTURE.md`) — but the same document also carries an ASCII repo-structure tree (a fenced
```-block with `├──`/`└──` connectors) that lists the identical fact a second time, and that second
copy is never touched. Two concrete shapes: (a) the diff deletes a file elsewhere in the same
commit, and the tree still lists it; (b) a prior commit moved a directory (e.g. out from under a
package into the repo root), the doc's prose was updated to say so, but the tree diagram still
nests the directory at its old location. Because the tree is a second, structurally distinct
representation of the same fact the author just finished correcting once, this is the doc-drift
equivalent of fixing a bug in one of two copy-pasted functions: the author's attention was on the
literal sentence a reviewer had flagged, not on re-deriving the whole picture the file describes.

Detection rule: for every file the diff deletes (`deleted file mode` in the diff) or that a recent
commit message says was moved/renamed, grep the post-diff conventions docs for the file's basename
inside a fenced tree block. Separately, for any directory the doc's prose claims lives at path P
(e.g. "Unit tests (`tests/`)"), confirm the SAME document's tree diagram draws that directory as a
child of P's actual parent, not some other package — `git ls-tree` the real location and compare
indentation/nesting in the tree diagram against it.

```
# tree-block line naming a path/basename that `git show <deleted-path>` (working tree) no longer has
[├└]──\s+([a-zA-Z0-9_.-]+)\s+#
```
Then: `git show <ref>:<path-to-doc> | grep -n '<basename>'` and cross-check each hit against
`git ls-tree <ref> -- <claimed-parent-dir>`.

Exclude: tree diagrams explicitly marked as historical/illustrative ("as of v1, before the tests/
move" or similar); docs where the tree is auto-generated by a script run in CI (verify: a Makefile/
script target that regenerates it, then check whether that target was actually run for this PR).

Severity: HIGH. The document's own two representations of the same fact now disagree with each
other, not just with the code — a reader has no way to tell which one is current without checking
git themselves, and the fix was one grep-and-edit away in the same review pass that already touched
the file.

Added by: oss-reviewer self-mutation on 2026-07-26 after observing PR #21 in psyduck_backend:
`CLAUDE.md:97` still lists `└── create_docs.sh # Sphinx documentation` under `scripts/` even though
this exact PR's diff deletes `scripts/create_docs.sh` (`deleted file mode 100644`) — the commit
message explicitly says "scripts/create_docs.sh was described as deleted but was still present. It
is deleted now," fixing the prose claim elsewhere but missing the tree's own listing. The same
file's tree also draws `tests/` as the last child of `psyduck/` (`│   └── tests/ # Unit tests
(mirrors source structure)`, indented under `migrations/`), while `git ls-tree` confirms `tests/`
is a repo-root sibling of `psyduck/`, not nested inside it — and the PR's own "Testing" section a
few dozen lines below in the identical file was correctly rewritten from `psyduck/tests/` to
`tests/`, so the document contradicts itself internally.

### 4.76 Own-PR-number citation baked into a source docstring (HIGH)

A module/function/test docstring embeds the enclosing PR's own tracker number ("fixed in PR
#21", "see PR #17", "regression tests for the fix in PR #N") to explain why the code exists,
instead of describing what the code currently does. It reads as tidy scoping in the moment —
often replacing a longer self-contained narrative that a prior review flagged as too
history-heavy — but the number is meaningless to any reader without GitHub open, and once
merged the reference is permanent: nothing "un-references" it later. A contributor grepping
the file for what it tests six months on has to go find the PR to learn what the two holes
were, when the docstring's whole job was to make that lookup unnecessary.

```
\bPR\s*#\d+\b
\bsee\s+PR\s+#\d+\b
\bfixed\s+in\s+PR\s+#\d+\b
```

Apply only to docstrings/comments inside diffed source and test files. Exclude
`CHANGELOG.md` (citing PR numbers is its entire job), commit messages and the PR
description itself (§4.1 already exempts these), and ADR/decision-record docs that
intentionally cite the PR that made a decision as part of a deliberate historical record.

Severity: HIGH in shipped `src/**`, `tests/**`, `migrations/**` files — the file should
stand on its own without the tracker open. Downgrade to INFO if the same docstring also
carries a one-line self-contained description alongside the citation (the number is then
decoration, not the only explanation).

Added by: oss-reviewer self-mutation on 2026-07-26 after observing
`integration_tests/api/test_invitation_authorization_api.py:1` in psyduck_backend PR #21: a
prior review cycle's fix condensed a self-contained module docstring ("Regression tests for
two authorization holes in the invitation endpoints. Both were exploitable end to end
against a running server...") down to `"""Regression tests for the two invitation
authorization holes fixed in PR #21."""` — trading history-narration for a docstring that
now requires opening GitHub to learn what the two holes actually were.

### 4.77 Linter newly enforces a convention that prose docs still only "recommend" (HIGH)

A PR wires a new lint rule / plugin that turns a previously-informal, prose-documented
convention into a hard `error`, but the prose the convention lives in (README,
CONTRIBUTING, a `*_flow.md` / style-guide doc the source comments themselves point at) is
not touched by the same diff. The rule's own config comments can be as thorough as they
like — that doesn't help the contributor who never opens the lint config. The concrete
failure mode: a contributor follows the doc's "prefer X" framing, writes the pattern the
doc allows, and gets a bare rule-name lint error with no doc pointing them at what to do
instead. This is the OSS-onboarding-friction cousin of a stale claim: not "the doc is
wrong," but "the doc under-describes what will now happen to you," which is just as
costly for a stranger's first contribution.

Detection rule: on a diff that adds a lint plugin/rule (`eslint-plugin-*`, a new `ruff`
`select` code, a new `clippy::` lint at `deny`) scoped at `error`/`deny`, find the prose
doc the rule's target convention is drawn from (grep source comments near the rule's
`files:`/target glob for a doc filename reference, or check the README/CONTRIBUTING
section covering that test/lint surface). If that doc still uses only
recommend-language ("prefer", "should", no mention of the tool/rule name) and the same
diff doesn't add an "enforced by `<rule>`" sentence to it, flag.

```
# planning signal: new plugin + new `error`/`deny` rules in a diff
^\+\s*import\s+\w+\s+from\s+['"]eslint-plugin-
^\+\s*['"][\w/-]+['"]\s*:\s*['"]error['"]
# doc-side signal: convention doc uses only soft language
\b(prefer|should|recommended)\b(?!.*\benforc)
```

Exclude: diffs that also touch the convention doc in the same commit/PR (the common,
correct shape); internal team-only rules with no contributor-facing doc to update;
rules whose only failure mode is a self-explanatory TypeScript-level error (formatting
rules like indent/quotes, where the fix is obvious without a doc).

Severity: HIGH — not a functional break (the gate still passes, `npm run lint:check` is
still 0), but it is a first-contribution-experience regression: the person the
convention doc was written for is the exact person who now hits an unexplained failure.
The fix is a one-line addition to the convention doc ("enforced by
`eslint-plugin-playwright`'s `no-raw-locators`; a raw `.locator()` string fails lint")
and, if the rule carves out an exception, that exception belongs in the same doc, not
only in the lint config's override comment.

Added by: oss-reviewer self-mutation on 2026-07-26 after observing
`psyduck_frontend` PR #53 (`eslint.config.mjs`): adds `eslint-plugin-playwright` and sets
`playwright/no-raw-locators` (plus 6 siblings) to `error`, enforcing the selector
convention `ui_test_flow.md` states in "prefer" language. Neither `ui_test_flow.md` nor
`README.md`'s End-to-End Tests section was touched by the same 3-file diff
(`eslint.config.mjs` + `package.json` + `package-lock.json`) — a contributor writing a
new spec from `ui_test_flow.md` alone has no way to learn the convention is now
lint-enforced until ESLint tells them, tersely, after the fact. The one deliberate
exception (`e2e/auth.setup.ts`'s `#id_login`/`#id_password` allowlist) is well-explained,
but only in `eslint.config.mjs`'s override comment — not in `ui_test_flow.md` (the
convention's home doc) nor inline in `auth.setup.ts` itself next to the two raw
`.locator()` calls it exempts.

### 4.78 "Not in the DOM" claim proven only by an accessibility-scoped locator (HIGH)

A behavior-contract doc or code comment asserts an element "does not exist in the DOM at
all" / "is not mounted" / "is fully removed" and cites, as its verification, a
role-scoped or accessible-name-scoped query (Playwright `getByRole`, Testing Library
`getByRole`/`getByLabelText`) returning zero matches. That query family is scoped to the
**accessibility tree**, which silently excludes nodes the DOM still contains whenever an
ancestor has `visibility: hidden`, `aria-hidden="true"`, zero computed size, or is inside
a not-yet-settled CSS transition — exactly the mechanism most component libraries
(MUI `Collapse`/`Accordion`, Radix, Headless UI) use for a "collapsed" panel by default,
since `unmountOnExit` is opt-in, not the default. A DOM-scoped locator on the identical
node (`getByTestId`, a raw CSS `querySelector`, `page.locator(...)`) returns a nonzero
count on the same element, because those locators don't filter by accessibility
inclusion. The doc's claim is then not just imprecise but actively wrong for any query
that isn't role-scoped — and a future spec, or a future migration to a library whose
default really does unmount, has no way to tell from the doc alone which behavior it's
inheriting.

```
\b(not|never|does\s+not|doesn'?t)\s+(exist|render|mount)(ed)?\s+in\s+the\s+DOM\b
\bnot\s+(merely|just)\s+hidden\b
\bzero\s+elements?,?\s+not\s+(a|to\s+a)\s+hidden\s+one\b
```

Verification rule: for any doc/comment matching the above, actually inspect the live DOM
(`element.outerHTML` / `getComputedStyle` via `page.evaluate`, or the framework's
non-accessibility locator) rather than trusting the cited role-query result. If a
DOM-scoped locator returns >0 where the doc claims 0, the doc's mechanism claim is false
even though the specific role-query the doc cites is technically accurate in isolation.

Exclude: claims paired with evidence from a DOM-scoped locator (not just a role query);
libraries confirmed (by reading the component source) to use `unmountOnExit: true` or
equivalent, where the DOM claim is actually correct.

Severity: HIGH. This is the "wrong correction is worse than the original gap" case for a
living behavior contract: the doc reads as more precise than it is, a future author
trusts the DOM-absence claim for a control the doc didn't specifically test (any
testid-queried element, not just the role-queried one cited as proof), and the failure
surfaces as a confusing off-by-one-locator-type bug rather than a doc review catch.

Added by: oss-reviewer self-mutation on 2026-07-27 after observing
`psyduck_frontend` PR #57, `ui_test_flow.md:159-166`: "while the card is collapsed **none
of them exist in the DOM at all** (verified: a `getByRole('button', { name: 'Delete
group' })` scoped to a collapsed card resolves to zero elements, not to a hidden one)."
Live `page.evaluate` inspection of a freshly created, never-expanded group card showed
the "Delete Group" `<button>` fully present in `card.outerHTML`, inside an
`AccordionDetails` styled `visibility: hidden; height: 0px` (MUI `Collapse`'s default,
`unmountOnExit` not set) — not absent, merely excluded from the accessibility tree, which
is why the cited `getByRole` count is 0. A sibling control in the same collapsed panel,
`group-invite-input-${groupId}`, queried via `getByTestId` (a non-role locator), returned
count **1** on the identical collapsed card in the same script run — direct
counter-evidence to "none of them exist in the DOM at all." The PR's own
`e2e/support/groupActions.ts:7-8` states the accurate mechanism one file over ("MUI keeps
a collapsed panel's children mounted but not visible"), so the wrong claim and the right
one shipped side by side in the same PR.

### 4.79 Revision-history narrated inline in a living behavior-contract document (MEDIUM)

A spec / behavior-contract doc that's meant to describe *current* system behavior (not a
changelog) states a correction as a diff against its own past self — "(corrected from an
earlier version of this document, which said/described X)" — instead of just stating the
current fact. The doc's git history already carries this information for anyone who
wants it (`git log -p -- <file>`); restating it inline is changelog content leaking into
a document whose whole value is being a single, current source of truth. It's a mild but
real AI tell: models optimize for showing their edit work / being transparent about what
changed, which is the right instinct in a PR description and the wrong one inside the
artifact the PR description is describing.

```
\(corrected from an earlier version of this document
\bpreviously\s+(described|stated|said|documented)\b.{0,60}\bnow\b
\b(this|the)\s+(doc|document|file)\s+(used to|previously)\s+(say|state|describe)
```

Exclude: `CHANGELOG.md` and files whose entire purpose is chronicling change; a single
provenance note in a document's own header/frontmatter ("adapted from vN"); repos whose
own conventions doc explicitly calls for inline correction notes (then it's a declared
convention, not a tell — but still worth an INFO nudge to reconsider the convention).

Severity: MEDIUM. Doesn't mislead a reader about current behavior (the corrected fact
itself is usually right, per §4.78's independent check), but it's dead weight in a
document graded on being the current, single-page truth, and it compounds: each future
correction adds another "corrected from an earlier version" clause, and the doc gets
harder to read for the same reason a heavily-tracked-changes Word doc does.

Added by: oss-reviewer self-mutation on 2026-07-27 after observing
`psyduck_frontend` PR #57 adds two instances to `ui_test_flow.md` (line 159-160: "corrected
from an earlier version of this document, which mentioned expanding only in journey 8's
step 1"; line 222: "corrected from an earlier version of this document, which described
only the card disappearing"), extending a pattern already present on `main` at line 116
("corrected from an earlier version of this document") from an earlier PR — three
instances total, none touched by a stated project convention that would sanction the
phrasing.

### 4.80 Prose tech-stack doc left stale by a dependency version-bump PR that never touched it (HIGH)

A conventions/README doc states a dependency's version in prose ("React 18.2 with
TypeScript 4.9", "ESLint 9 flat config with `@typescript-eslint`") as part of a Tech
Stack / Stack Overview section. A later PR bumps that same dependency in the manifest
(`package.json`, `pyproject.toml`, `Cargo.toml`) — sometimes across several sequential
commits, each with a thorough rationale — but the diff never touches the doc file, so the
prose claim silently falls behind the manifest truth. Unlike §4.35 (a package's own
self-reported runtime version drifting behind its manifest), this is a *description of a
third-party dependency* going stale, and unlike §4.31 (an in-repo consumer pin), there's
no lockfile to cross-check — only the prose against `package.json`. It's a natural
byproduct of how these PRs get scoped: the commit messages are all about the manifest and
the config files that consume the dependency (eslint.config.mjs, tsconfig.json), and the
doc describing the stack for a human reader isn't in the diff's working set at all, so
nothing prompts the update. It matters specifically because these docs (CLAUDE.md,
AGENTS.md) are frequently the *first thing* a coding agent reads and treats as
authoritative before touching a line of code — a stale version claim there doesn't just
mislead a human skimming the README, it can misdirect an agent's next session.

Detection rule: for every dependency whose manifest version changed in the PR's diff,
grep the repo's conventions docs (README.md, CLAUDE.md, AGENTS.md, CONTRIBUTING.md) for
that dependency's name and compare the stated version against the new manifest value.

```
grep -niE '\b(react|typescript|eslint|vite|node\.?js|python|django|postgres(ql)?)\s+[0-9]+(\.[0-9]+)*\b' README.md CLAUDE.md AGENTS.md
```

Exclude: docs that link to the manifest instead of restating a version ("see
`package.json` for the pinned TypeScript version"); a version cited only inside a dated
changelog/migration-log entry describing what a *past* PR did (that's historically
accurate by construction, not a live claim); floating major-only claims ("React 18") on a
manifest still within that major (`^18.2.0` bumping to `^18.3.0` doesn't falsify "React
18").

Severity: HIGH. The claim is independently verifiable and cleanly falsified (manifest and
prose disagree), it's the class of finding a reader/agent has no way to catch without
diffing the two files themselves, and — per the rationale above — the blast radius
includes future AI coding sessions that treat the doc as ground truth before writing
code, not just human onboarding.

Added by: oss-reviewer self-mutation on 2026-07-30 after observing `psyduck_frontend`
branch `feature/62-ts6-eslint10` (commit 5d594b0, issue #62): three sequential commits
bump `package.json`'s `typescript` from `^4.9.5` to `~6.0.3` and `eslint` from `^9.17.0`
to `^10.8.0` (each with a multi-paragraph rationale), but `CLAUDE.md`'s "Tech Stack"
section — last touched two PRs earlier at commit e48bf91 — still reads "React 18.2 with
TypeScript 4.9 (strict mode)" (line 40) and "ESLint 9 flat config with
`@typescript-eslint`" (line 49), neither of which the branch's diff includes.

### 4.81 Test file's header comment names a disjunction of APIs one of which a sibling PR deleted (HIGH)

A `*_test.*` / `**/tests/**` file's file-header or `describe`-level comment describes
what's under test as "X/Y is called" or "X or Y happens" — a disjunction naming two
alternate code paths. A later, unrelated PR deletes one of the two paths from the
production file the test imports (e.g. removes a fallback branch and its import), but
because the deleting PR's diff never touches the test file, nothing forces the test's
header comment to update. The comment now asserts a code path exists that a `grep` of the
production file proves does not. This is the test-side mirror of §4.70: there the
docstring lies about its own file's production caller; here a *different* file's comment
lies about a *different* file's remaining code paths, and only a tree-wide grep (not the
diff) surfaces it — exactly the blind spot `--scope=diff` reviews must explicitly widen
for when a PR's own stated purpose is "delete a named code path."

Detection rule: grep test/spec files for a comment matching an "A/B" or "A or B" pair of
identifiers in a sentence describing what's exercised; then grep the corresponding
production file(s) the test imports for each identifier. If one is absent, flag.

```
#\s*.*\b([A-Za-z_][\w.]*)\s*/\s*([A-Za-z_][\w.]*)\s+is called
```

Then confirm via a second grep: `\b<missing-identifier>\b` absent from the production
file(s) the test file imports.

Exclude: comments updated in the same PR that removed the code path (no finding — the
follow-up work already happened); disjunctions naming things that were never mutually
exclusive code paths (e.g. "logs to console or file" describing genuinely-live
configuration, not dead branches).

Severity: HIGH. A reader trusts a test's header comment to describe live behavior; here it
asserts a branch is reachable when the production file it tests has already deleted it —
actively misleading about the app's actual mount/render surface.

Added by: oss-reviewer self-mutation on 2026-07-31 after observing psyduck_cdk-adjacent
frontend repo PR (commit 48e2174, "Remove dead react-snap hydrateRoot branch in
index.tsx", closes #61): `src/index.tsx`'s diff cleanly deletes the `hydrateRoot` import,
the `hasChildNodes()` branch, and its docstring sentence — the file itself reads coherent
post-deletion. But `src/tests/Index.test.tsx:2`'s header comment ("Tests for index.tsx
bootstrap. Ensures createRoot/hydrateRoot is called with #root.") still names
`hydrateRoot`, which a tree-wide grep confirms no longer exists anywhere under `src/` —
the deleting PR (and the earlier PR #60 that removed react-snap itself) never touched the
test file, so the disjunction went stale silently.

### 4.82 Tech-stack doc's transform-mechanism claim falsified by the same PR that swaps the mechanism (HIGH; §4.80 sibling)

§4.80 catches a prose *version number* going stale behind a dependency bump. This is the
architectural-description sibling: a conventions doc doesn't just state a version, it
describes *how* a build tool works internally ("the babel pipeline, not SWC", "webpack
with `ts-loader`", "esbuild's default transform") — often phrased as a forward-looking
note ("the React Compiler adoption ahead is a babel plugin"). A PR then swaps that exact
mechanism (a plugin major bump that changes its JSX transform engine, a bundler migration)
and the PR's own commit message narrates the swap in detail — but the diff never touches
the doc, so the doc's mechanism claim silently flips from true to false, and any
forward-looking phrasing ("adoption ahead") silently flips from pending to already-done.
Unlike §4.74 (which requires the doc to be touched-but-incomplete in the same commit),
here the doc isn't touched at all — same blind spot as §4.80, but for *how* a tool works
rather than *which version* it is.

Detection rule: for every devDependency whose PR diff changes major version or is newly
added/removed, grep conventions docs (CLAUDE.md/README.md) for prose describing that
dependency's internal mechanism (parser/transform engine names: babel, swc, oxc, esbuild,
webpack, rollup, vite). Read the PR's own commit message for language explaining a
mechanism swap ("dropped X for Y", "moved behind a second plugin") — a hit there paired
with an untouched doc sentence asserting the old mechanism is the finding. Also check
whether the doc phrases the swap as future ("adoption ahead", "in a later phase") — if the
PR IS that adoption, the forward-looking tense itself is now false.

```
grep -niE '\b(babel|swc|oxc|esbuild|webpack|rollup)\b' CLAUDE.md README.md
```
Then cross-reference each hit against the PR's devDependency diff + commit message for a
stated engine swap.

Exclude: docs that link to the config file instead of asserting the mechanism ("see
`vite.config.ts` for the active transform"); mechanism claims about a dependency the PR
doesn't touch at all.

Severity: HIGH — same rationale as §4.80 (independently verifiable, cleanly falsified, and
these docs are what a coding agent reads as ground truth before writing its next change).

Added by: oss-reviewer self-mutation on 2026-07-31 after observing psyduck_frontend PR #67
(commit f4a3837, "React 18->19 + React Compiler", closes #64): `@vitejs/plugin-react` was
bumped 5.x -> `^6.0.4` in the same diff, and the PR's own `vite.config.mts` comment plus
commit message state plainly that v6 "dropped Babel for its own JSX transform (oxc now...)
and moved React Compiler support behind a second plugin" — yet `CLAUDE.md:41-42`
(untouched by this diff) still reads "`@vitejs/plugin-react` (the babel pipeline, not
SWC — the React Compiler adoption ahead is a babel plugin)", which is now false on both
counts: plugin-react no longer runs a babel pipeline, and the "adoption ahead" is this
very PR. The same doc's version claim ("React 18.2 with TypeScript 6.0") is the
already-cataloged §4.80 pattern recurring one day after it was first added to this file.

### 4.83 Discovery-loop guard test whose filter matches zero current instances (HIGH; CRITICAL if security-framed)

A regression-guard test iterates a dynamically-discovered set (`pkgutil.iter_modules`,
`apps.get_models()`, `importlib`-driven module scans, `Path.glob`) and filters each
discovered item with a `continue`/`skip` before reaching the real assertion. If, under
the CURRENT codebase, zero discovered items pass the filter, the assertion body is
unreachable — the test is a no-op that always goes green, indistinguishable in CI from
having no test at all, while its docstring frames it as forward-looking rigor ("guards
against a future X"). The tell is the author correctly reasoning about the future risk
while missing that the very sentence proves today's coverage is zero. Generalizes §4.22
(always-passes tests) and is the discovery-loop sibling of §4.48 (unreachable assertion)
— but the unreachability here comes from an empty filter match on the present code, not
from an upstream guard that raises.

Detection is semantic, same posture as §4.48: find test bodies that discover a class/
module set at runtime and filter by an attribute (`Meta.model`, a decorator, a base
class) before asserting. Independently enumerate the real target set the same way the
test does (e.g. grep every `Meta:` block's `model = ` in the discovered package) and
check whether any member satisfies the filter. Zero matches today = the finding.

```
pkgutil\.iter_modules|apps\.get_models\(|importlib\.import_module
```
paired with a nearby comment/docstring admitting the target is presently absent:
```
no\s+\w+.*(targets?|implements?|defines?|references?)\b.*\btoday\b
this guards against a future
```

Exclude: discovery-loop tests whose FIRST assertion checks the discovery itself
succeeded (`assert len(discovered) > 0`) before any per-item filter — that shape fails
loudly if discovery breaks; tests explicitly marked `@pytest.mark.xfail` / skipped with
a reason.

Severity: HIGH — same false-green cost as §4.22, novel enough mechanism (empty filter,
not missing assert) to need its own entry. CRITICAL when the test's name/docstring
markets itself as a security or data-exposure guard, since the false-green signal masks
exactly the incident the test claims to prevent.

Added by: oss-reviewer self-mutation on 2026-08-01 after observing
`tests/models/test_psyduck_user.py::test_public_id_not_writable_through_any_serializer`
in the psyduck-cdk PR (issue #33 branch, commit 1d251a4): the loop's `if model is not
User: continue` skips all eight serializers under `psyduck/api/serializers/` (none has
`Meta.model = PsyduckUser`, confirmed by grep), so `instance = serializer_class(); assert
"public_id" not in instance.fields or ...` never executes; the test's own docstring says
"No serializer in the package targets PsyduckUser as its Meta.model today" without
flagging that this makes the assertion presently unreachable.

### 4.84 Partial test-mocking-architecture migration leaves the conventions doc describing only the old approach (HIGH)

A PR swaps the mocking strategy (module mock -> network-layer mock, e.g. `vi.mock('../services/api')`
-> MSW request handlers; or manual stub -> fixture factory) for a **subset** of test suites,
while the project's own conventions doc (`CLAUDE.md` / `CONTRIBUTING.md` / a `## Testing`
README section) has a "key testing patterns" or "toolchain" listing that states the old
approach as *the* pattern, singular, with no mention that a second approach now coexists.
Because the migration is partial (N of the repo's suites converted, the rest untouched), both
descriptions are simultaneously true of some file in the tree — which is exactly why the drift
survives review: nobody's claim is outright false, just incomplete. A contributor reading the
doc before writing suite N+1 reaches for the documented (old) pattern and either fights the new
per-suite convention or duplicates tooling. The doc's own numeric test-count claim (`"52 test
suites, 275 tests"`-shaped prose) is a cheap tripwire: a migration PR that adds or nets any
`it(`/`test(` blocks makes that literal number provably wrong the moment it's counted.

Detection rule: when a diff touches `**/tests/**` in a way that adds a new mocking dependency
(check the manifest diff for a newly-added test-mocking package: `msw`, `nock`, `sinon`,
`responses`, `httpretty`, `respx`, `vcrpy`) or introduces a new `support/`-style helper module
for it, grep the project's conventions doc for the *old* pattern's literal invocation
(`vi\.mock\(`, `jest\.mock\(`, `unittest\.mock\.patch\(`) inside prose that frames it as
universal ("Key testing patterns", "Mocking approach", a single bullet with no "for suites not
yet migrated" qualifier). If the old-pattern prose exists with no companion mention of the new
dependency/approach, and the diff's newly-converted suites now coexist with untouched suites
still on the old pattern, that's the finding. Separately, diff any test-count literal in the doc
(`\d+\s+test suites?`, `\d+\s+tests?\b` near "passing") against an actual count of `it(`/`test(`
blocks in the tree at HEAD — a mismatch confirms the doc predates this PR's test delta.

```
vi\.mock\(|jest\.mock\(|unittest\.mock\.patch\(
```
paired with a manifest diff adding one of:
```
"msw"|"nock"|"sinon"|"responses"|"httpretty"|"respx"|"vcrpy"
```
and no corresponding mention of that new package anywhere in the conventions doc's toolchain
list.

Exclude: docs that already frame the old pattern as scoped ("suites not yet on MSW use
`vi.mock(...)`") rather than universal; migrations that convert every suite in the same PR
(nothing left half-described); READMEs that explicitly disclose the migration is in flight
(e.g. "MSW adoption ... still ahead" — but flag this phrasing itself as the finding once a PR
actually lands the first tranche, since "still ahead" becomes false the moment adoption starts).

Severity: HIGH. The doc is the primary onboarding surface for "how do I write a test here," and
a next-suite author following it reaches for the wrong (or now-secondary) pattern. Escalate to
CRITICAL if the doc's stale numeric test count is off by more than the diff's own claimed delta
(a sign the doc was already stale before this PR, not just newly outdated by it).

Added by: oss-reviewer self-mutation on 2026-08-01 after observing psyduck_frontend PR
(head 8bb04d3, "MSW for the six API-mocking page suites"): `CLAUDE.md:191` still reads
"**52 test suites, 275 tests** all passing" and `CLAUDE.md:205` still documents
`vi.mock('../services/api', ...)` as a "Key testing pattern" with zero mention of MSW anywhere
in the toolchain list (`CLAUDE.md:52`), while the diff converts six suites
(App/Index/Dashboard/Group/Profile/PublicProfilePage) to MSW network-layer mocking, adds `msw`
to `package.json`, and the tree's actual `it(`/`test(` count is 277, not 275. Separately,
`README.md:60` states "MSW adoption ... still ahead" — a claim this exact PR falsifies by
landing the first tranche of it.

### 4.85 New env var documented as prose, omitted from the repo's own "Environment Variables" table(s) (HIGH)

A diff introduces a new `process.env['X']` / `os.environ.get('X')` read and documents it with a
one-off prose sentence tucked into a feature-specific section (e.g. an "End-to-End" or "Auth"
subsection), while the same doc — or a sibling doc that mirrors it, such as a `CLAUDE.md`/
`README.md` pair — already maintains a dedicated `## Environment Variables` (or equivalently
named) markdown table that is the established structured home for exactly this kind of fact.
The new var never becomes a row in that table, in either doc. Because the prose sentence is
independently true, the drift survives review: nothing written is false, it's just filed in the
wrong place, and a reader who jumps straight to the reference table (the normal skim path for
"what env vars does this repo use") never learns the knob exists at all.

Detection rule: for each newly-introduced `process\.env(\[.?['"]?\w+['"]?\]?|\.\w+)` or
`os\.environ\.get\(['"]?\w+['"]?` in the diff, extract the var name, then grep every doc in the
repo for a heading matching `^#+\s*Environment Variables?` followed by a markdown table
(`\|.*\|` block). If such a table exists anywhere in the repo (in the same doc or a sibling one)
and the new var's name does not appear as a table cell in it, flag. Doubly notable when a sibling
doc's table already lists other vars of the *same feature family* (e.g. other `E2E_*` vars) —
that's direct proof the new var belongs there by the repo's own precedent, not just a general
convention.

```
process\.env(\[['"]?\w+['"]?\]|\.\w+)|os\.environ\.get\(['"]?\w+['"]?
```
cross-referenced against
```
^#+\s*Environment Variables?
```
with no matching table row for the extracted var name.

Exclude: vars intentionally scoped out of the table with an explicit note (e.g. "internal/CI-only,
not for local use"); docs where the "Environment Variables" section is prose-only throughout (no
table convention established, so a prose addition matches existing style); the var already
appearing in at least one such table anywhere in the repo.

Severity: HIGH. Not a functional blocker — the knob still works and is documented somewhere — but
it fragments the one place a user or contributor actually checks, and when two docs each keep
their own copy of the table (as is common in a `CLAUDE.md`/`README.md` pair), landing the addition
in neither leaves both silently incomplete.

Added by: oss-reviewer self-mutation on 2026-08-01 after observing psyduck_frontend PR (head
0ba2c77, "Add PW_VIDEO env knob for opt-in E2E video recording"): `playwright.config.ts:101`
introduces `process.env['PW_VIDEO']`, and `CLAUDE.md:266-267` documents it in a prose sentence
inside `### End-to-End (Playwright)`, but neither CLAUDE.md's own `## Environment Variables`
table (`CLAUDE.md:279-283`, format `| Variable | Description | Example |`) nor README.md's
parallel `## Environment Variables` table (`README.md:164-171`, format
`| Variable | Description | Default |`) gained a row for it — despite README's table already
listing the sibling E2E-family vars `E2E_EMAIL`, `E2E_INVITEE_EMAIL`, and `E2E_PASSWORD`.

### 4.86 Cross-repo "no-op until #N lands" caveat left stale by the referenced issue actually landing (HIGH)

A script or doc in repo A defers to unfinished work in a sibling repo B by name-and-number
("no-op until psyduck_frontend#85 lands", "not yet supported — see backend#42"), phrased as a
present-tense fact rather than a dated snapshot. The two repos are developed in the same
polyrepo workflow, often by the same orchestrator dispatching parallel PRs, so the referenced
issue can close *minutes* after the caveat is written — sometimes before the caveat's own PR
even merges. Nothing in repo A re-checks repo B's state afterward: there is no CI link, no
issue-tracker webhook, no test that would fail once #N lands. The caveat is accurate at the
moment of authorship and silently false forever after, misdirecting exactly the debugging
session it was written to help (a user sees no output and reads the comment's excuse instead
of investigating the real cause, now that the dependency is actually satisfied).

Detection rule: grep the diff (comments, doc prose, `usage()`/`--help` text) for a forward
reference combining an issue/PR-shaped token with deferral language:

```
(no-op|not (yet )?(supported|wired|implemented)|todo)\b.{0,40}\b(until|before)\b.{0,40}#\d+
#\d+\b.{0,40}\b(lands?|merges?|ships?)\b
```

For each match, extract the repo (if named) and issue number, then check that issue/PR's
actual current state (GitHub host: `gh issue view N --repo <owner>/<repo> --json state,closedAt` or the
linked closing PR's `mergedAt`). If the state is CLOSED/merged, the caveat is stale now,
regardless of whether it was true when written — flag it. Also spot-check the claimed
downstream effect still holds (e.g. does the dependent file the caveat describes now actually
contain the wired-through behavior) rather than trusting the issue tracker alone, since a
closed-as-wontfix issue would need different handling.

Exclude: caveats already qualified with a checked-at date ("as of 2026-08-01, not yet...") —
those are honest snapshots, not standing claims; CHANGELOG-style historical narration where
past-tense framing makes the staleness obvious to the reader.

Severity: HIGH. Not a functional blocker on its own — the feature usually still degrades
gracefully (a no-op stays harmless even if it secretly isn't one anymore) — but it actively
misleads triage once the dependency lands, and unlike most doc drift it is self-inflicted by
design: the caveat's whole premise is an external, unmonitored state that the author had no
way to keep in sync.

Added by: oss-reviewer self-mutation on 2026-08-01 after observing psyduck_cdk
`scripts/dev-stack.sh:338-340,363` (head 9d1598c): the script's `copy_videos()` comment and its
runtime log message both say video collection is "a no-op ... until psyduck_frontend#85 wires
PW_VIDEO through to Playwright's video option." `gh issue view 85 --repo ksco92/psyduck_frontend`
showed the issue CLOSED via merged PR #86, and `playwright.config.ts:101` on that repo's default
branch already reads `video: process.env['PW_VIDEO'] ? 'on' : 'off'` — the dependency landed
about 51 seconds after this script's commit, making the caveat stale before the review even ran.

Also match any future-tense condition in a comment, checked against the tree and the tracker (case-insensitive):
```
\buntil (CI|it|this)\s+(exists|lands|ships)\b|#[0-9]+\s+will\b|will need once
```

### 4.87 "An earlier version did X, empirically confirmed" debugging-session narration in an implementation comment (HIGH)

A comment inside application/script source (not a CHANGELOG, ADR, or PR description) narrates
its own prior iteration and how that iteration was tested and falsified — "an earlier version
did X, on the theory that Y; empirically confirmed [with a harness] that Y doesn't hold" — as
the justification for the current code. This is dev-diary content: it documents the *authoring
session*, not the invariant the reader needs going forward. Git history (`git log -p`) already
carries the superseded version and the commit message already carries the rationale; restating
both permanently in the file is the same "show my work" reflex as §4.79, but landing in an
executable script instead of a living spec doc, and reads unmistakably as a model narrating a
debugging session rather than a person documenting a constraint.

```
\ban earlier version\b.{0,80}\b(on the theory that|attempted|tried|assumed)\b
\b(empirically confirmed|confirmed empirically)\b
```

Exclude: files whose entire purpose is a decision log / ADR with dated entries; a regression-test
comment tied to a specific issue/CVE number ("regression test for the bug fixed in v1.2, see
#123") where the reference is a stable external anchor, not a narrated debugging session.

Severity: HIGH. Doesn't mislead about current behavior on its own (the constraint being
documented — e.g. a language runtime's signal/trap re-entrancy semantics — is often genuinely
non-obvious and worth a comment), but the debugging-session framing is exactly the pattern the
user's own global comment discipline rules out ("don't reference the current task, fix... those
belong in the PR description and rot as the codebase evolves"): it will read as stale narration
the moment a third iteration supersedes the "earlier version," since nothing updates it then.

Added by: oss-reviewer self-mutation on 2026-08-01 after observing psyduck_cdk
`scripts/dev-stack.sh:192-202` (head 2fa246f): the `request_teardown` comment reads "An earlier
version called do_teardown ... on the theory that a second signal arriving during the
grace-period sleep would re-enter this handler... Empirically confirmed with an isolated harness
(this script's skeleton against dummy TERM-ignoring "servers")... the same run confirmed
empirically: total teardown dropped from the full double grace period to stopping as soon as the
second signal landed." The underlying WHY (bash 3.2 trap dispatch semantics) is legitimate and
worth keeping; the "earlier version / empirically confirmed" framing is the debugging session,
not the invariant, and belongs in the commit message (which already has it, per this diff's own
`9d1598c..2fa246f` history).

Also match revert-and-rerun proofs (case-insensitive):
```
confirmed by temporarily|by temporarily (forcing|reverting)|reverting .{0,60}reproduces|tried while developing|smallest size found|confirmed by applying .{0,40} by hand
```

### 4.88 Extraction diff omits itself from the conventions doc's own established per-sibling subtree pattern (HIGH)

A conventions doc (`CLAUDE.md`, `ARCHITECTURE.md`) carries a component/module hierarchy
diagram where SOME entries are expanded into a nested subtree (children listed one per
line, sometimes two levels deep) while sibling entries at the same tier are left as a bare
leaf or a grouped one-liner. A PR extracts a leaf entry's monolithic implementation into
exactly the shape the doc already uses for its expanded siblings (a new subdirectory, N
named sub-components) — but doesn't add itself into the diagram at the same fidelity the
diagram already demonstrates for analogous siblings. The doc doesn't need new invention;
the pattern to follow is already sitting three lines above in the same file.

Detection: for any diff introducing a new subdirectory of named sub-units under an existing
page/module directory (`src/components/<new-dir>/`), locate that parent's entry in the
repo's own hierarchy/architecture doc. If sibling entries at the same nesting level are
expanded into sub-bullets/subtrees and this one is left as a bare leaf (or lumped into a
plural "static pages" grouping) post-diff, that's the drift — the diagram's own left-hand
column already establishes the expected level of detail.

Exclude: docs that explicitly mark some entries as "not broken down" or cap tree depth by
stated policy; hierarchy diagrams generated from source at build time.

Severity: HIGH. The precedent for the correct doc shape is in the same file the PR's author
had open — this isn't inventing a new convention, it's finishing applying an existing one.

Added by: oss-reviewer self-mutation on 2026-08-01 after observing `CLAUDE.md:132-159` in
psyduck (Component Hierarchy section): `<ProfilePage>` and `<GroupPage>` are both expanded
two levels deep (down to `<AddAllergyForm>`, `<GroupHeader>`, etc.) while PR #91 extracted
`HelpPage.tsx`'s monolith into `src/components/help/{GroupsSection,ProfileSection}.tsx` —
the identical shape as the already-documented siblings — yet line 157 still reads
`├── <AboutUs>, <HelpPage>, <WhatsNewPage> — Static content pages` with no subtree added.

### 4.89 First-of-its-kind test technique added with zero line in the conventions doc's own exhaustive pattern list (HIGH)

A conventions doc enumerates the repo's testing patterns in detail and reads as exhaustive
(it lists every mocking convention in use, coverage exclusions, dependency-pinning
rationale, etc. — the kind of doc a new contributor is expected to trust as complete). A
diff introduces a testing *technique* that has zero prior instances in the repo (first
snapshot test, first fixture-factory pattern, first visual-regression assertion, first use
of a new test utility) — the technique compiles and asserts something real, but the
enumerable doc gains no corresponding bullet, so the only trace of the convention is a
comment inside the one test file that uses it. The next contributor who wants to add a
second instance has no doc to consult and either reinvents the convention differently or
greps for prior art.

Detection: for a diff touching `**/tests/**` or `**/*.test.*`, check whether it introduces
an assertion primitive/matcher not already used elsewhere in the suite (`grep -rc` the
matcher/utility name across the test tree pre-diff; a diff introducing the first non-zero
count is a first-of-its-kind add). Cross-check the repo's conventions doc's testing section
for a line naming that technique and its update workflow (e.g. "run X to regenerate").
Absence is the finding.

Exclude: techniques that are self-evidently standard for the stack and require no
project-specific workflow knowledge (a first `expect().toBeInTheDocument()` call needs no
doc line); doc sections explicitly scoped to a subset of patterns ("selected examples").

Severity: HIGH when the technique has a non-obvious regeneration/maintenance workflow (a
snapshot needs `-u` to intentionally update vs. hand-editing meaning a silently-wrong
baseline; a fixture factory has a "when to add a new fixture vs reuse" judgment call) —
that's exactly the tribal knowledge a conventions doc exists to prevent. Downgrade to INFO
if the workflow is self-documenting (no update step, no judgment call).

Added by: oss-reviewer self-mutation on 2026-08-01 after observing psyduck PR #91: CLAUDE.md's
"Key testing patterns" section (lines 202-238) exhaustively documents MSW-vs-`vi.mock`
conventions, `mockReset` behavior, and jsdom pinning, but the PR adds the repo's first-ever
`toMatchSnapshot()` call (`src/tests/pages/HelpPage.test.tsx`) with no corresponding doc
line — the only explanation of the convention and its update workflow (`vitest -u` per the
test's own comment, though the repo's own documented entry point is `npm test`, not bare
`vitest`) lives in a comment inside the one file that uses it.

### 4.90 Single-call-site exception generalized into a system-wide doc rule (HIGH)

A diff adds an early-return/special-case at exactly ONE call site of a shared mechanism
(an interceptor, middleware, event bus, decorator) that suppresses a normally-universal
side effect (a toast, a log line, a retry) for that one caller. The doc is then updated
with a general "except" clause on the existing rule — "X happens for every caller, except
[condition], which does Y instead of X" — phrased as if the shared mechanism itself now
enforces the exception for everyone. It doesn't: the shared mechanism still fires its own
effect and still lets the rejection/event propagate to every OTHER caller's un-modified
handler, so at every other call site both the old behavior (X) and the new one (Y) fire
together. The doc reads as accurate because the author verified it against the one call
site they touched; the overclaim is invisible unless every other consumer of the shared
mechanism is traced.

Detection: when a diff adds a bypass/early-return around a shared interceptor's normal
effect at one call site, grep the shared mechanism's other call sites (other callers of
the same service/hook whose error paths still run their original catch-and-notify logic)
and confirm the doc's "except" clause is scoped to the specific call site, not stated as a
property of the shared mechanism. Trace whether the shared mechanism's own error path
still re-throws/re-rejects past the point the doc claims the effect is suppressed —
if it does, every other caller keeps its original side effect and the general claim is
false for them.

Exclude: doc language explicitly scoped to the modified call site by name ("ProfilePage's
own whoami call detects this and redirects directly" is fine; "a session-expiry 401
redirects instead of toasting" with no site qualifier is the violation).

Severity: HIGH — a wrong invariant about error-handling behavior that the next contributor
will trust when adding a new page/caller, reproducing the same silent-toast-plus-redirect
bug instead of the (falsely) documented redirect-only behavior.

Added by: oss-reviewer self-mutation on 2026-08-01 after observing psyduck PR (CLAUDE.md
diff af2b15b..e7e972a) `CLAUDE.md:185-187`: the amended "Error Handling" bullet claims a
session-expiry 401 "clears auth and redirects home instead of toasting" as a blanket rule,
but the toast-suppression is implemented only inside `ProfilePage.tsx`'s
`fetchAllProfileData` catch block (an explicit early `return` before `showToast`). Every
other page's own catch block (e.g. `GroupPage.tsx`'s `fetchAllData`, which unconditionally
calls `showToast('Failed to load group data.', 'error')`) is unmodified, and `api.ts`'s
response interceptor re-rejects after invoking the redirect handler
(`return Promise.reject(error);`) rather than suppressing propagation — so those pages
show the toast AND redirect together, contradicting the doc.

### 4.91 Component-hierarchy diagram in a wholly-untouched conventions doc names a component this PR renamed (HIGH)

A rename+restructure PR deletes a component file and adds a differently-named replacement
(`git diff` shows `deleted file mode` on the old path and a new file at a new path, with the
exported component/function name changed to match), and the replacement is a like-for-like
architectural swap — same slot in the render tree, same or overlapping children — not a
new, additional component. The project's conventions doc (`CLAUDE.md` / `ARCHITECTURE.md`)
carries a component/module hierarchy tree (a fenced block with `├──`/`└──` connectors naming
components by their exported identifier, e.g. `<GroupDetails>` in a React tree, a package
tree naming a Python class) that still nests the OLD name under its old parent. Unlike §4.75
(which requires the SAME doc to have a sibling prose passage the author demonstrably edited,
proving attention touched the file and just missed the second copy), this shape has the doc
untouched in the diff entirely — `git diff <doc-path>` between the PR's base and head is
empty — so there's no internal self-contradiction to grep for, only a diagram-vs-code
mismatch. It also differs from §4.82 (build-tool mechanism prose) in subject: this is a
structural map of the codebase's own component tree, the thing a coding agent reads first
to decide where a new prop or child belongs, so a stale node sends the next change to a
dead file name.

Detection rule: for every file the diff deletes (`deleted file mode`) whose default/named
export is a component or module, extract its exported identifier (the old name). Confirm a
new file in the same diff exports a differently-named identifier that (a) is imported by the
same call sites the old export was imported by (`git diff` on those call sites shows the
import specifier changing from old to new) and (b) renders the same or a superset of the old
component's children. Then grep every conventions doc UNCHANGED by this diff (`git diff
<base>...<head> --name-only` excludes it) for the old identifier inside a fenced tree block.
A hit is the finding. Secondary check: if the new component also grew children the old one
didn't have (a decomposition landed in the same PR, not just a rename), confirm those new
children appear as tree nodes too — their total absence compounds the finding rather than
being a second one.

```
# doc's tree block still naming the old, now-deleted component
[├└]──\s+<OldComponentName>
```
Then confirm via `git log --diff-filter=D --name-only <base>..<head>` that the old path was
deleted, and via `git diff <base>...<head> --name-only` that the doc's path is absent from
the changed-file list.

Exclude: tree diagrams explicitly marked historical/illustrative; renames where the doc was
touched but a different part of it was left stale (that's §4.75, not this); genuinely new
sibling components added alongside an unchanged original (no rename occurred, nothing stale).

Severity: HIGH. The doc is the first thing a future contributor or coding agent reads before
touching this subtree, and it now names a file that does not exist — worse than silence,
because it actively misdirects the next edit.

Added by: oss-reviewer self-mutation on 2026-08-01 after observing psyduck_frontend PR #98
("[FE] Phase 7c: GroupPage architecture refactor"): the diff deletes
`src/components/group/GroupDetails.tsx` and `src/tests/components/group/GroupDetails.test.tsx`,
adding `src/components/group/GroupCard.tsx` (same import call sites in `OwnedGroupsList.tsx`/
`JoinedGroupsList.tsx`, confirmed via `git diff` on both) plus two new children,
`GroupPendingInvitations.tsx` and `InvitationsTableShell.tsx`. `CLAUDE.md` does not appear in
`git diff origin/main...HEAD --name-only` at all, yet its Component Hierarchy tree
(`CLAUDE.md:151-155`) still reads `└── <GroupDetails> — Accordion orchestrator` with the
pre-refactor four children and no `<GroupPendingInvitations>` node; the Type System table
(`CLAUDE.md:181`) separately describes `GroupInvitationSmall` as "Compact shape for
GroupDetails," the identical stale name in a second table in the same file.

### 4.92 New exported type lands in the barrel but not in the conventions doc's closed Type System table (HIGH)

A diff adds a new `export interface`/`export type` in `src/types/*.ts` (or the language
equivalent — a new Pydantic model, a new dataclass) and re-exports it through the module's
barrel file (`index.ts` / `__init__.py`), so it's now a first-class part of the public type
surface. The project's own conventions doc maintains a closed enumeration table for exactly
this surface (`CLAUDE.md`'s `## Type System` — `| Type | File | Key Fields |`, one row per
type). The new type never gains a row, even though the doc IS touched elsewhere in the same
diff for an unrelated reason (proving the file was open and edited, not merely stale) — the
addition simply wasn't checklist-driven the way a table update needs to be. This is the
type-system sibling of §4.85 (env-var table) and §4.46 (closed-inventory table): the reader
who jumps straight to the reference table to answer "what types does this app have" never
learns the new one exists.

Detection rule: diff `src/types/*.ts` for new `export (interface|type) (\w+)` declarations;
confirm each new identifier is added to the barrel's re-export list (`export type { ... }
from './x'` gains the name). Then check whether the conventions doc's Type System table (or
equivalent) gained a matching row. Doubly notable when the same diff DOES touch that doc
(other tables/sections in it change) — proof the file was open, not simply forgotten in
isolation.

```
^\+\s*export (interface|type) (\w+)
```
cross-referenced against the doc's `## Type System` (or equivalent) table for a row naming
that identifier.

Exclude: internal/non-exported types; types intentionally excluded from the table because
they're trivial aliases of another listed type; docs with no established type-table
convention.

Severity: HIGH. Same rationale as §4.85 — the knob works, the type is real and typed
correctly, but the one place a contributor checks "what does this app model" silently
under-counts.

Added by: oss-reviewer self-mutation on 2026-08-01 after observing psyduck_frontend PR #100
(head 1e9c5be): `src/types/user.ts` adds `export interface WhoAmIResponse { ... }` and
`src/types/index.ts` re-exports it (`export type { UserProfile, WhoAmIResponse,
UserAllergyRow } from './user';`), consumed by `AuthContext.tsx`. The same commit edits
`CLAUDE.md`'s Service Layer table and test-count line, so the file was demonstrably open —
but its `## Type System` table (`CLAUDE.md:188-202`) gained no `WhoAmIResponse` row.

### 4.93 Intra-repo extraction backstory cites an exact pre-refactor call-site/copy count instead of documenting current behavior (INFO)

A newly-extracted helper's file-header or leading docstring justifies its own existence by
narrating the refactor that produced it — "extracted once these were copy-pasted at N call
sites", "pulled out after this shape was pasted across X and Y" — instead of (or in addition
to) documenting what the function does and why a future caller would reach for it. The tell
is citing a specific count or an enumerated list of prior call sites: that number is a fact
about the moment of the commit, not about the function, and it silently goes stale the first
time a fifth caller adopts the helper or one of the original four is deleted — a reader has
no way to know the "four" is now wrong without git-archaeology. This is the intra-repo cousin
of §4.44 (predecessor-repo diff narration): same changelog-content-in-a-docstring's-clothing
shape, but the "before" state being narrated lives in this repo's own history instead of a
repo the reader can't see.

```
\bextracted\s+(once|after|because)\b.{0,60}\b(call sites?|copies|places)\b
\bcopy-?pasted\s+(at|across)\s+\w+\s+(call\s+sites?|places)\b
\bpulled\s+out\s+once\b.{0,60}\bcopy-?pasted\b
```

Exclude: a commit message or PR body narrating the same fact (changelog content belongs
there, not in this catalog's scope); a CHANGELOG.md entry; a one-time migration-notes doc
explicitly scoped as historical.

Severity: INFO. Not misleading today and often genuinely useful context for the next reader
deciding whether to extend the helper further, but it's the specific shape this project's own
CLAUDE.md prohibits ("Don't reference the current task, fix, or callers... since those belong
in the PR description and rot as the codebase evolves") — flag so the count can be dropped or
moved to the PR description.

Added by: oss-reviewer self-mutation on 2026-08-01 after observing psyduck_frontend PR #100
(head 1e9c5be) `src/utils/withPendingId.ts:1-6`: "Shared shape behind every per-id
double-submit guard in this app (allergy level-change, allergy delete, dietary-preference
toggle, logout)... Extracted once these guards' 'add to Set / try / finally remove from Set'
bodies were copy-pasted at four call sites." The enumerated four-caller list and exact count
will silently drift the next time a fifth guard adopts the helper.

### 4.94 README run-book command hardcodes an infra resource name the source since renamed (HIGH)

A README (or other copy-pasteable run-book doc) embeds a literal AWS/infra CLI flag —
`--environment-name`, `--bucket`, `--stack-name`, `--function-name`, a `Name=tag:...,Values=`
filter, etc. — built from the same naming template the IaC source uses (e.g.
`` psyduck-eb-env-${STAGE} ``), while the CDK/Terraform/source construct that actually
creates that resource has since diverged (e.g. `` psyduck-eb-env-${cfg.stage}-2 ``). A unit
test asserting the same name is an easy, visible red — CI catches it. The README command has
no such tripwire: it silently keeps returning "no such environment" / an empty result set /
worse, quietly targets a different, wrong resource, and nobody notices until someone actually
runs the run-book.

Detection: for each hardcoded resource-name literal in README/runbook shell blocks, find the
matching `environmentName:` / bucket-name / stack-name construction in `lib/**/*.ts` (or
equivalent IaC source) that uses the same stage-templated prefix, and diff the literal
template against the current source construction. A mismatch (missing suffix, different
literal, different casing) is the tell. Grep starting point:

```
--(environment|stack|bucket|function)-name[= ]\S*\$\{?\w+\}?
Name=tag:[\w:.-]+,Values=\S+
```

Exclude: docs that explicitly say "replace with your own resource name" (placeholder intent
is clear); commands that look the resource up dynamically (e.g.
`$(aws ... describe-stacks --query ...)`) rather than hardcoding it — those can't go stale
this way.

Severity: HIGH; escalate to BLOCKER if the doc is the *only* place this operational command
is written down (no script/Makefile wraps it), since it silently sends an operator at the
wrong AWS resource with no test or CI to catch the drift.

Added by: oss-reviewer self-mutation on 2026-08-02 after observing README.md:132,166
(psyduck-cdk, head 3132015) still reading `psyduck-eb-env-${STAGE}` /
`psyduck-eb-env-dev` after `lib/psyduck-stack.ts` and `lib/pipeline-stack.ts` were updated
across commits 4f0e512/52d0dc3/2b1405c/4f7bdca to `` psyduck-eb-env-${stage}-2 ``. The unit
test assertion (`test/psyduck-stack.test.ts:373`) was caught by CI and fixed by commit
3132015 the same day; the two README run-book commands, which have no test coverage, were
not.

### 4.96 PR's own "proof of completeness" grep excludes the file type the survivor lives in (HIGH)

A PR that renames/retires a filename across the repo backs its completeness claim with a
literal grep command pasted into the PR body or commit message (e.g. "`grep -rn
'old\.ext' --include='*.md' --include='*.ts' . | grep -v new` returns zero hits"). The
`--include` list is scoped to the file types the author actually touched (docs, `.ts`
comments) and omits a sibling type — typically `.json` (tsconfig, package manifests),
`.yml`/`.yaml` (CI), or `.mjs`/`.cjs` config — where a comment or string referencing the
old name still survives untouched. The stated grep is technically true and returns zero
hits for its own scope, so it reads as verified due diligence, but it never had a chance
to find the survivor because that file extension was never in the include list. This is
higher-signal than a bare unverified claim (§4.74 sibling) because the PR *shows its
work* — the fabricated rigor is the tell.

Detection: for any PR/commit claiming a repo-wide rename sweep with a pasted verification
command, (1) run that exact command against the post-diff tree to confirm it does return
zero hits (it should — that's not the bug), then (2) re-run it with the `--include` list
widened to every text extension present in the repo (`git ls-files | sed -E 's/.*\.//' |
sort -u`) and compare. Any new hit is a survivor the author's own filter structurally
could not see.

```
--include=['"][^'"]*['"]
```
(locate every `--include`/`--type` flag in a pasted shell command inside a PR body/commit
message; diff its extension set against `git ls-files`'s actual extension set)

Exclude: sweeps that grep without an include filter (`grep -rn old . | grep -v
node_modules`) — no scope gap possible; PRs that explicitly scope the sweep to "docs
only" in prose and stay inside that scope.

Severity: HIGH. The PR closes the tracking issue on the strength of a verification
command that could not have found the counterexample; a fresh contributor hits the
survivor and has no PR to explain it since the issue reads closed.

Added by: oss-reviewer self-mutation on 2026-08-02 after observing psyduck_frontend PR #101
(head 07fcc71, "Fix stale vite.config.ts docs refs and complete route table", closing #68):
PR body pastes `grep -rn 'vite\.config\.ts[^x]' --include='*.md' --include='*.ts' . |
grep -v node_modules | grep -v mts` and reports zero hits — true for that include list, but
`tsconfig.json:41`'s comment ("`vite.config.ts`'s `globals: true` provides") survives
because `.json` was never in the filter; it predates this PR (from the original Vite
migration, commit e48bf91) and is the sole remaining stale reference in the repo.

### 4.97 Doc refresh adds a specific pointer to a companion doc file that was never committed (CRITICAL)

A "fix doc drift" / "docs refresh" PR adds prose that cites a specific sibling document by
path and section anchor for further detail ("see `docs/plans/<name>.md` §3", "full rationale
in `docs/adr/0007-...md`") as the authoritative source for a claim the PR itself is making.
The cited file does not exist anywhere in the repo — not on the PR's head, not on any
ancestor commit (`git log --all --full-history` for that path returns nothing) — so the
pointer is either a hallucinated citation (the model invented a plausible-looking plan-doc
filename to lend the claim an air of "this was researched and written down") or a dangling
reference to a doc that was drafted elsewhere and never actually committed. Either way, a
reader who follows the pointer for "the commands" or "the full rationale" hits nothing. This
is the doc-PR sibling of §4.16 (dead GitHub fragment) and §4.91 (stale component-tree node):
same "reference outlives/precedes its target" shape, but the target here never existed at
all, and the detection is a plain file-existence check rather than an API call. It is
especially damaging when the PR's own commit message claims exhaustive verification ("every
claim was checked against X") — the file-existence check is the cheapest possible diligence
step and it was skipped — and doubly so when the content the pointer promises ("commands in
...") already lives in-repo under a different, real path (e.g. the project's own README),
meaning the fabricated pointer sends the reader away from an answer that was one file over.

Detection rule: in the diff's added lines, extract path-shaped tokens inside backticks or
plain prose that look like repo-relative doc paths (`docs/.../*.md`, `docs/adr/*.md`,
`design/*.md`, `RFCS/*.md`, optionally followed by a `§N` / `#section` anchor). For each,
check `git cat-file -e <head>:<path>` (exists on the PR head) and, if absent, `git log --all
--full-history -- <path>` (ever existed anywhere). Absent from both is the finding. As a
secondary check, grep the rest of the repo (README, other docs) for the same subject matter
the pointer claims to cover — if the real content already lives elsewhere, note that in the
finding as the fix.

```
`docs/[\w./-]+\.md`(?:`\s*§\d+)?
`(?:design|adr|rfcs?)/[\w./-]+\.md`
```
Then: `git cat-file -e <head>:<matched-path>` and `git log --all --full-history -- <matched-path>`.

Exclude: paths that resolve on the PR head or in git history (real, just not yet merged to
this branch — check the actual target branch history, not just HEAD); paths inside a
`## Roadmap` / `## Future docs` section explicitly framed as "not yet written"; paths that
are clearly placeholders inside a template (`docs/adr/NNNN-title.md`).

Severity: CRITICAL. A citation is supposed to be more trustworthy than an unsupported claim;
one pointing at nothing is worse than no citation, because it advertises diligence that
didn't happen and actively misdirects the next reader.

Added by: oss-reviewer self-mutation on 2026-08-02 after observing psyduck_cdk PR
(worktree `gates-pr41`, head 53ecffc, "Docs refresh: pipeline files, removed NLB, Python
3.13, DB access via SSM"): `CLAUDE.md:68-69` adds "commands in
`docs/plans/2026-08-02-infra-cost-pipeline-plan.md` §3" as the pointer for RDS SSM
port-forwarding commands. `git log --all --full-history -- 'docs/*'` returns nothing for
this repo — no `docs/` directory has ever been committed. The actual SSM port-forwarding
commands already live in this same repo at `README.md`'s "Connect to RDS via SSM Session
Manager" section (README.md:166-199), pre-dating this PR. The commit message claims "every
claim was verified against lib/, bin/, and cdk.json in this repo before being written" —
true for the CDK-source claims, but the doc-file pointer itself was never checked against
the repo's actual file tree.

### 4.99 IAM-scope doc claim falsified by a co-located unscoped statement added to the same policy (HIGH)

A code comment or conventions doc (CLAUDE.md, module docstring) makes a specific,
falsifiable claim about an IAM policy's scope — "scoped to this stage's EB environment
ARN [only]", "least privilege: role has only N managed policies" — anchored to a named
construct (an `AwsCustomResourcePolicy`, a `Role`, a `PolicyStatement` block). A PR then
adds a SECOND statement to that same policy object granting one or more actions on
`Resource: '*'` (because the new actions genuinely don't support resource-level ARNs)
without touching the nearby claim. The new statement is often correctly justified in its
OWN adjacent comment (documents the AWS Describe-action ARN limitation, cites precedent
elsewhere in the repo) — the code change itself is sound — but the PRE-EXISTING claim one
statement up, or the doc's summary of the same construct, still asserts the narrower
scope as if it were still the whole story. A reviewer who reads only the new statement's
local comment sees a well-justified addition; a reader who trusts the older claim (or the
doc, which nobody re-reads on an IAM diff) walks away believing the policy is still
single-ARN-scoped.

Detection: for a diff that adds a `new PolicyStatement(...)` / equivalent with
`resources: ['*']` (or `Resource: '*'` in synthesized/raw IAM) to an `AwsCustomResourcePolicy.fromStatements([...])`
/ `Policy` / `Role` that ALREADY had a narrower-scoped statement, read (a) any comment
immediately above the construct's declaration and (b) any conventions-doc section
describing that specific construct by name (grep the construct's id / a distinctive noun
phrase like the resource name across `CLAUDE.md` / `README.md`). If either says
"scoped to X [only]" / "least privilege" / enumerates a closed set of grants, and the
new unscoped statement isn't folded into that enumeration, it's the finding — even when
the new statement's own local justification is completely correct.

Exclude: claims explicitly scoped to a named sibling statement, not the whole policy
("the `DescribeEnvironmentResources` grant is ARN-scoped" is fine and stays true); a
project's "least privilege" doc bullet that already names a DIFFERENT principal (e.g. an
EC2 instance role) than the one the new statement modifies (a Lambda custom-resource
execution role) — then the bullet isn't literally falsified, only silent about the new
principal, which is a softer (INFO, not HIGH) gap.

Severity: HIGH. The security-relevant invariant a future reader trusts ("this policy only
touches one ARN") is now false for the policy as a whole, and IAM scope claims are
exactly the kind of thing nobody re-verifies against the live template — they're taken on
faith from the comment.

Added by: oss-reviewer self-mutation on 2026-08-02 after observing psyduck-cdk PR #50
(commit a76ec118): `lib/monitoring-stack.ts:102-105`'s pre-existing comment — "Resolve
both dynamically at deploy time via DescribeEnvironmentResources, scoped to this stage's
environment ARN only" — sits four statements above a new `PolicyStatement` granting
`autoscaling:DescribeAutoScalingGroups`, `elasticloadbalancing:DescribeLoadBalancers`,
`ec2:DescribeInstances`, and `cloudformation:DescribeStackResources` on `Resource: '*'`
to the exact same `AwsCustomResourcePolicy.fromStatements([...])` the comment describes.
The new statement's own local comment (added by the same PR) correctly explains why
`Resource: '*'` is required for those four actions — the addition is technically sound —
but the older "scoped ... only" claim four lines up was never touched, and
`CLAUDE.md:85-87` describes the same construct project-wide with the identical
now-incomplete "scoped to this stage's EB environment ARN" language.

### 4.98 Unqualified cross-repo script/command reference in a multi-repo doc set (HIGH)

New README/CLAUDE.md prose that names a script or command (`foo.sh`, `make bar`, a CLI
invocation) which is not tracked in the current repo, and does not say which *other*
repository it lives in — in a project where the same document (or the same PR's other
files) otherwise consistently qualifies cross-repo references by name (e.g. every other
pointer reads `other_repo/path/to/thing`, or a sibling source file already says "the X
script in other_repo").

Detection rule: for each inline-code span matching a script/command shape
(`` `[\w-]+\.sh` ``, `` `[\w-]+\.py` ``, a bare `make <target>` / `<tool> <subcommand>`) added
in the diff to `README.md` / `CLAUDE.md` / other top-level docs, check `git ls-files` for a
tracked file of that name in the current repo. If absent, grep the same file (and the rest
of the diff) for a repo-name qualifier in the same sentence or the surrounding paragraph
(`\b[a-z][a-z0-9_]*_?(backend|cdk|frontend|infra)\b` or an explicit "lives in `<repo>`"
phrase). No qualifier + the doc set's own established convention elsewhere DOES qualify
similar references = finding.

```
`([\w-]+\.sh)`
```
Then: `git ls-files --error-unmatch <name>` (repo root) to confirm it's not tracked locally,
and grep the same paragraph for a repo-name qualifier.

Exclude: scripts that resolve within the current repo (`scripts/<name>.sh` present); a
document's very first cross-repo mention, where no convention yet exists to break; generic
shell built-ins (`ls`, `curl`) that aren't project scripts.

Severity: HIGH. Not a blocker — the reader can usually still find the script by searching,
and it doesn't break the current repo's own quickstart — but it silently breaks the doc
set's own promise that a cross-repo pointer says where to look, and a reader relying on
grep/`find` inside just this repo hits a dead end.

Added by: oss-reviewer self-mutation on 2026-08-02 after observing psyduck-cdk-scoped PR
(worktree `gates-pr111`, head e93c876, "Add E2E_BASE_URL deployed-target mode for the
Playwright suite"): `README.md:59,125-126` and `CLAUDE.md:320` introduce `` `dev-stack.sh
--e2e` `` as the canonical way to run local-mode E2E, with zero mention of which repository
it lives in. `git ls-files | grep dev-stack` in the frontend repo returns nothing — the
script is not tracked there, `scripts/` has no such file. It actually lives at
`psyduck_cdk/scripts/dev-stack.sh`. The same PR's own `playwright.config.ts:119-120`
(pre-existing comment, untouched by this diff) already says "the dev-stack script in
psyduck_cdk" — proving the convention of naming the source repo was established and simply
not followed in the two new doc mentions. Every other cross-repo reference this same PR adds
(`psyduck_backend/psyduck/throttle_config.py`, `psyduck_backend/psyduck/utils/stage_guard.py`)
is correctly repo-qualified.

### 4.101 Commit-message rationale duplicated near-verbatim into the same diff's inline comment (INFO/HIGH)

A PR's commit message contains a multi-sentence investigation/rationale narrative, and the
same diff adds an inline source comment that restates large stretches of that narrative
almost verbatim (shared multi-word phrases, matching structure, same specific facts cited
twice). The commit message is the correct, session-scoped home for "how I investigated /
why I ruled out X"; the source comment should carry only the durable WHY a future reader
needs. When both carry the same paragraph, the code comment reads as a copy-paste of the
model's own commit-message draft rather than an authored, economical comment — the "show my
work" reflex from §4.87, generalized beyond the "empirically confirmed" phrasing to any
high-phrase-overlap commit⟷comment pair (structural, not phrase-specific, so it catches
cases §4.87's regex misses).

Detection rule: for a diff's added comment lines (contiguous comment block adjacent to a
changed line), extract lowercase word 5-grams. Extract the same from `git log -1
--format=%B` (or the PR body). If ≥2 five-word-or-longer phrases are shared verbatim between
the two, flag the file:line of the comment.

Exclude: short (`# see commit message for rationale`)-style cross-references; comments in
CHANGELOG.md / commit templates; single shared proper nouns / identifiers (issue numbers,
function names) — the trigger is shared *prose*, not shared *terms*.

Severity: INFO when the overlap is 2-3 phrases and the comment is otherwise well-scoped;
HIGH when the comment is a near-full restatement (>50% of comment sentences have a
commit-message counterpart) — at that point the comment is redundant scaffolding, not
documentation. Either way the underlying WHY may be legitimate and worth keeping in the
file (per the "hidden constraint" bar) — the finding is the duplication, not the comment's
existence.

Added by: oss-reviewer self-mutation on 2026-08-16 after observing psyduck_cdk
`jest.config.js:3-11` (head 8980edb): the added comment restates, almost phrase-for-phrase,
content already in the same commit's message body — "hashes only the uid, never the
project" / `getCacheDirectory` (comment ≈ commit paragraph 1), "shared blast radius" /
"fully self-contained" (comment ≈ commit paragraph 3), and "(see #39)" mirroring the
commit's own "Closes #39" — a substantial restatement of the commit-message narrative
inside a 9-line comment justifying a 1-line config change. Distinct from the
already-cataloged §4.87 ("empirically confirmed" / "an earlier version" phrasing, also
first observed in this repo at `scripts/dev-stack.sh`) since this comment doesn't use
debugging-session phrasing — it's a plain WHY-comment that happens to duplicate its own
commit message almost verbatim, a different manifestation of the same reflex.

### 4.100 Numbered pipeline/workflow-stage doc enumeration omits a step the PR adds (HIGH)

`CLAUDE.md` / `README.md` documents an orchestration flow (CI pipeline, CD pipeline, state
machine, DAG) as a numbered or ordered prose list — "1. Source, 2. Synth, 3. Dev stage
(steps X, Y), 4. Approval, 5. Prod stage" — enumerating the concrete steps/stages by name.
A PR then adds a new step to the actual flow definition (a new `CodeBuildStep` in a CDK
Pipelines `post`/`pre` array, a new job in a GitHub Actions workflow, a new state in a Step
Functions definition, a new task in an Airflow DAG) without touching the doc file. The doc
still reads as a complete, accurate description of the flow, but a stranger (or a future
agent that reads the doc *before* touching the code, per a read-before-write convention)
now has an incomplete mental model — critically, the omitted step is very often a **gate**
(a test/approval/validation step that can block the flow), so the doc's omission isn't just
incomplete, it hides new blocking behavior between two stages the doc says are adjacent.

Detection rule: find the numbered/ordered flow-description section in `CLAUDE.md`/`README.md`
(heading matching `## (Pipeline|Workflow|CI|CD|Deployment flow)`, followed by an ordered
list or numbered paragraphs naming concrete step/stage identifiers). Extract the set of
step/stage names it enumerates for the stage the diff touches. Separately, extract the set
of step/stage identifiers actually wired into that stage in the diff (new construct id
passed to `new CodeBuildStep(...)`, a new `jobs.<name>:` key, a new state name) — for CDK
Pipelines specifically, a new entry added to a stage's `post`/`pre` array. If the diff adds
an identifier to the executable flow that does not appear in the doc's enumeration, AND the
diff does not also touch the doc file, that's the finding.

```
# In CLAUDE.md / README.md — ordered flow enumeration
^\d+\.\s+\*\*[\w -]+\*\*\s+—
# In the diff — new step added to an existing stage's pre/post array
post:\s*\[[^\]]*\n\s*\w+,\s*\n\s*\]
pre:\s*\[[^\]]*\n\s*\w+,\s*\n\s*\]
```

Exclude: docs with no enumerated flow section at all (nothing to drift against); PRs whose
diff already includes an edit to the doc file (even a partial one — judge that edit on its
own accuracy instead); steps added to a stage the doc describes only in generic/collective
terms ("post-deploy steps run automatically") rather than by an exhaustive named list.

Severity: HIGH. Not a blocker — the pipeline itself is correct and ships working
infrastructure — but the doc actively misleads: it was accurate before the PR and is now
silently wrong about the shape of a live, deployed system. Escalate to CRITICAL if the repo's
own CLAUDE.md carries a binding "read this before touching related code" instruction (as a
read-before-write convention would compound the staleness into future incorrect work).

Added by: oss-reviewer self-mutation on 2026-08-02 after observing psyduck-cdk PR (worktree
`gates-pr51`, head 39166e9, "Add E2EGate-dev CodeBuild step"): `lib/pipeline-stack.ts:110-118`
adds a third post-deploy step (`e2eGateDev`) to the dev stage's `post` array — a real gate
that can now block the pipeline from ever reaching `PromoteToProd` — while `CLAUDE.md:114-117`
("Pipeline" section, written in PR #41) still describes the dev stage as exactly two
post-deploy steps (`DeployBackend-dev` + `DeployFrontend-dev`) followed directly by
`PromoteToProd`. The same PR also left `CLAUDE.md:71-75`'s enumeration of the
`psyduck-e2e-dev` secret's consumers one entry short — it still lists only the EB postdeploy
hook, not the new E2EGate-dev CodeBuild role that now also reads the secret's `email`/
`invitee_email`/`password` keys.

### 4.102 README quality-gate table drifts behind the local merge-gate script it documents, hiding an undocumented prerequisite tool (BLOCKER-class)

A README documents a project's local merge gate (`make check`, `npm run verify`, `tox -e all`)
as a table or enumerated list of named sub-checks — "Target | Command | Bar", one row per
step. The actual orchestration target (a Makefile `check:` recipe, a package.json composite
script) is a superset: a later commit appends more steps (`docs`, `deny`, `machete`, a second
linter) to the target *without* adding matching rows to the README table. This is §4.100's
sibling for a *local dev/CI gate* instead of a deploy pipeline, and it compounds into something
§4.100 doesn't: because the README's "Setup from scratch" section derives its prerequisite-tool
list from the same (now-incomplete) mental model of what the gate runs, an undocumented step
that needs its own installed binary (`cargo-deny`, `cargo-machete`, a second formatter) becomes
an undocumented prerequisite too. The README's own documented verification command — the thing
a stranger runs to confirm the clone worked — fails on a genuinely fresh machine with a bare
"command not found" for a tool the Setup section never told them to install, even though the
gate passes fine on the author's machine where the tool happens to already be on `PATH`.

Detection rule: parse the orchestration target's actual step list (Makefile `check:`
prerequisite targets, or the composite script's `&&`-chained/`npm-run-all`-listed sub-scripts).
Separately parse the README's enumerated table/list of what that gate runs. Diff the two sets.
For each step present only in the real target, check whether its command invokes a binary not
already required by an enumerated step (e.g. `cargo deny`, `cargo machete`, a second linter
binary) — if that binary is also absent from the README's "Prerequisites"/"Setup" section, the
gap is BLOCKER-class per Phase 1 ("references a tool not documented as a prerequisite"),
independent of whether `make check` happens to pass on the reviewer's own machine (which may
already have the tool installed from unrelated work).

```
# Makefile: full prerequisite chain of the gate target
^check:\s*(.+)$
# README: enumerated gate table/list — collect the step names it names
\|\s*`make\s+(\w+)`\s*\|
```
Then: `<Makefile step set> - <README step set>` is non-empty => doc-drift finding; for each
extra step, grep its recipe body for a binary invocation and check the README's Prerequisites
section for that binary's name.

Exclude: README enumerations explicitly scoped as partial ("the primary checks; see the
Makefile for the full gate"); gates whose extra steps invoke only binaries already covered by
an enumerated step (no new prerequisite, just an undocumented row — INFO, not BLOCKER).

Severity: BLOCKER when an extra, undocumented step requires a binary absent from the
Setup/Prerequisites section (the documented quickstart's own verification command fails on a
bare machine); HIGH when every extra step's binary is otherwise covered (doc completeness gap
only, no quickstart failure).

Added by: oss-reviewer self-mutation on 2026-08-31 after observing the `onix` repo review:
`README.md`'s "Quality gates" table (added in commit `b200eeed`) enumerates exactly four `make`
targets (`fmt`, `clippy`, `test`, `coverage`), and the "Setup from scratch" section's
prerequisite list covers only `curl`/`make`/`git` plus `cargo-llvm-cov` — but the very next
commit (`cbaaec07`, "Gates: forbid unsafe, docs -D warnings, cargo-deny, cargo-machete") widens
the Makefile's `check: fmt clippy test coverage docs deny machete` to six targets, wiring in
`cargo deny check` and `cargo machete`, and never revisits the README. Both tools happened to
already be installed on the review machine (from unrelated work), so `make check` passed
clean — but a genuinely fresh clone following the README's own documented `cargo build && make
check` verification step would hit `error: no such command: `deny`` on first run, for a tool
the Setup section never mentions.

### 4.103 Milestone checklist item left unchecked by the very commit that completes it (HIGH)

A `TODO.md` / `ROADMAP.md` tracks milestone deliverables as `- [ ]` items under a
dated/tagged section header (e.g. `## M3-pre — Recursion depth guard`). A commit
whose message names that same milestone tag ships every sub-deliverable the
item's own text enumerates — the named symbols, behaviors, and test classes all
land in the diff — but the commit never touches the tracking doc, so the
checkbox stays `- [ ]` even though the work it describes is now on `main`. The
project's own established practice (every prior milestone in the same file
checked off in the commit/PR that shipped it) makes the omission a regression
against its own convention, not merely "docs are always a little behind": the
next contributor scanning the tracker for "what's left before M3" sees the
depth-guard as outstanding work when it's already shipped and tested.

Detection rule: from the commit message, extract a milestone/section tag.
Find the matching `## <tag>` header in `TODO.md`/`ROADMAP.md`. For each `- [ ]`
item under that header, extract the concrete deliverable nouns (function/type
names in backticks, named error variants, "e.g." examples). Grep the commit's
diff for those names. If all (or nearly all) are present in the diff's added
code — and, ideally, the diff's own test names confirm the described behavior
(e.g. a "depth-5000 non-crash test" deliverable matched by an actual
`depth_...` test in the diff) — but the tracking doc is absent from the
commit's changed-file list, that's the finding.

```
# commit message
^[A-Za-z0-9_-]+:\s  # e.g. "M3-pre: recursion depth guard closing stack-overflow DoS"
# matching TODO.md header
^##\s+M[0-9]+(-pre)?\s+—
# unchecked item under that header
^-\s+\[\s\]\s
```

Exclude: sections whose item text is aspirational/open-ended (no concrete
symbol names to grep for — nothing falsifiable); repos where checklist state
is known to be batch-updated in a separate housekeeping commit (verify via
git history: if a prior milestone's checkbox flip happened in its own commit
across every previous milestone, that's the convention and this PR should
follow it too — the exclusion is for repos where it never happens at all).

Severity: HIGH. Nothing breaks, but the project's own status document —
the thing a future implementer or reviewer trusts to answer "is this done" —
silently disagrees with `main`, and the gap is invisible to `make check`.

Added by: oss-reviewer self-mutation on 2026-08-31 after observing
`onix` commit `94b54cd` ("M3-pre: recursion depth guard closing stack-overflow
DoS"): the diff fully implements `TODO.md`'s M3-pre item (`diff_at` depth
tracking, configurable max via `DEFAULT_MAX_DEPTH`, `Error::MaxDepthExceeded`,
a depth-5000-class non-crash test — actually shipped as depth-100_000 and
depth-`DEFAULT_MAX_DEPTH + 1` tests, a superset of what was asked), all
verified present and green under a fresh `make check`, yet `TODO.md:46`'s
`- [ ] \`diff_at\` tracks depth; ...` line is untouched by the commit and
still reads unchecked, while the sibling M3-pre bullet (`deny.toml` escalation)
and every M0/M1/M2 item in the same file were checked off in the commits that
shipped them.

### 4.104 Milestone-tagged doc comment revised while a nested/sibling doc comment stating the same superseded fact is left untouched (HIGH)

A source doc comment (rustdoc `///`, Python docstring, JSDoc, etc.) attached to a
type/variant is rewritten to reflect a milestone/version change (e.g. "as of M2,
only X" -> "M2 and M3 both ... unreachable now"), but a nested doc comment on a
field/member of that SAME declaration, sitting a few lines below and describing
the same superseded fact from the reader's-eye view, is left as-is. The two
comments now contradict each other under a close read: the outer says the case
can no longer occur; the inner still asserts a fact ("always X") that presupposes
the case fires routinely. This is the source-doc-comment sibling of §4.64 (schema
column vs table description) — same shape, different medium: a PR that edits one
doc comment about a fact should scan sibling doc comments on the same declaration
that state the same fact, and often doesn't, because a diff review reads only the
hunk that changed.

Detection: for a diff that rewrites a type/variant-level doc comment to drop or
supersede a milestone/version marker ("as of M<N>", "arrives in M<N>", "not yet
implemented"), read every doc comment on that type's own fields/variants in the
same file (not just the touched hunk) for the same marker or a claim that depends
on the pre-change behavior. A field comment repeating the same "as of M<N>,
always <value>" framing that the enclosing comment just retired is the finding.

```
as of M[0-9]+,?\s+(always|only|still)\b
```

Exclude: field comments that make a claim independent of the milestone context
(e.g. describing a type's general shape rather than "when this fires").

Severity: HIGH — the inner comment now asserts something false (or at best
misleading) about when/whether the field is populated, and a reader who trusts
the field-level doc over the enclosing one draws the wrong conclusion.

Added by: oss-reviewer self-mutation on 2026-08-31 after observing `onix`
`crates/onix-core/src/error.rs:18-25` (commit 351484f, M3): the diff rewrites
`UnsupportedContainerDiff`'s own doc comment to say the variant "is currently
unreachable through the public API" (M2 and M3 are both fully implemented, both
always recurse), but leaves the nested `container_type` field's doc comment
reading "The Python type name of the container (as of M2, always `\"list\"`)" —
unrevised since the M2-era text, and now doubly stale: it still assumes the
variant fires routinely for lists, contradicting the enclosing comment edited
two lines above in the same commit.

### 5.21 Absolute repo-URL links in publishable package metadata point at a currently-private repository (INFO / HIGH once actually published)

A README embedded verbatim into a package's registry-facing metadata (PyPI wheel `METADATA`/sdist `PKG-INFO`, npm tarball README, crates.io `readme`) is fixed to use absolute `https://github.com/<owner>/<repo>/...` links instead of repo-relative ones — the correct fix for relative links having no base outside the repo (§4.37). But the fix's correctness depends on the target repo being reachable: if `<owner>/<repo>` is still private, every link 404s for non-collaborators. Pre-publish this is inert; the moment the package is published while the repo stays private, the links go live and broken simultaneously.

Detection: for each absolute repo link in a README that a manifest embeds into publishable metadata, extract `(owner, repo)` and check visibility (GitHub host: `gh api repos/<owner>/<repo> --jq .visibility`); cross-check against the package's actual registry publish state (§4.18/§4.33).

```
https?://github\.com/([^/\s)]+)/([^/\s)]+)/(blob|tree|issues|pull)/
```

Exclude: links to a different public repo than the one being published; private mono-repos that never publish externally-readable docs.

Severity: INFO when confirmed not-yet-published (sequencing reminder: repo public no later than first registry upload). HIGH when the package is live on the registry with the repo still private.

Added by: oss-reviewer on 2026-09-01 (onix PR #2 round 2): 5 links correctly absolutized for the wheel long_description, but the repo was still private at review time.

### 4.105 Mutation-testing "fully caught" claim contradicted by a deterministically-unviable mutant in the tool's own enumeration (CRITICAL)

A committed mutation report or README section claims a crate/module is "fully caught" / "zero gaps", backed by a specific run's caught/missed/unviable table. `cargo mutants --list` (enumeration only — no build or test) includes a mutant substituting `Default::default()` (or another trait-bound-requiring value) for a type that implements no `Default` anywhere in the tree: a compile-time fact, so the mutant is unviable — non-caught — in every possible run, and any report omitting it from the unviable set (or claiming its crate "fully caught") is provably wrong in seconds.

Detection: for each `replace ... with (Ok(|Some()?Default::default()` line in the enumeration, grep the target type for `derive(...Default...)` or `impl Default`; for std types, one-line standalone `rustc` check (`let _: T = Default::default();`). No `Default` → cross-check the committed unviable list; absence plus a "fully caught"/"N/N" claim for that crate is the finding.

```
replace .* with (Ok\()?(Some\()?Default::default\(\)
```

Exclude: types that do implement Default (genuinely viable — must be run to classify); reports already listing the mutant as unviable.

Severity: CRITICAL for a headline "fully caught"/"zero survivors" claim (a trust signal falsifiable without running the suite); HIGH if buried but the totals don't add up. Related trap on the report side: caught/missed/timeout splits are wall-clock-dependent, so a rewritten "representative run" that drops deterministic unviables while keeping headline claims is how this arises.

Added by: oss-reviewer on 2026-09-01 (onix PR #2 round 3): "onix-cli is fully caught (18/18)" while the enumeration contained a `Default::default()` mutant for a struct deriving no Default, plus an `Ordering: Default` mutant — both previously counted as unviable and silently dropped by a reframing rewrite.

### 4.106 Mutation-report "verified caught" triage claim for a named survivor is directly falsifiable (CRITICAL)

A committed mutation report names a specific missed mutant (file:line, exact substitution) and asserts a specific reproduce command "makes the suite fail" / "is in fact caught," attributing the tool's MISSED label to a build-caching or wall-clock artifact. Mutation classification is deterministic for a given (mutant, suite) pair modulo genuine flakiness, so the claim is falsifiable in one command: apply the named mutation by hand (or `cargo mutants -F '<file>:<line>'`) and run exactly the cited test command. A pass (mutant survives) contradicts the claim.

Exclude: claims hedged as "observed caught in a separate run" without asserting deterministic catch; genuinely flaky mutants where the report documents non-determinism rather than asserting definitiveness.

Severity: CRITICAL — structurally §4.105's sibling, but triggered by the report's own directed reproduce step rather than a static enumeration cross-check; the fastest catch is to do exactly what the report tells the reader to do.

Added by: oss-reviewer on 2026-09-02 (onix PR #2 round 4): "applying that mutation and running `cargo test -p onix-core` directly makes the suite fail" for `diff/array.rs:82`'s `>`→`>=` mutant; running exactly that command gave 266/266 passing (survivor), confirmed by a scoped `cargo mutants -F` run.

### 4.107 De-jargoning PR silently bundles a fixture/data-generation code change that invalidates published benchmark numbers (CRITICAL)

A PR framed as prose/label cleanup also changes the code that generates a benchmark fixture or golden dataset (removing a workaround, changing a data shape) — and rewrites the results doc's prose to describe the new behavior without regenerating its numbers. The text diff looks safe (no numeric literal changed), but the table's values no longer match what the current code produces on a fresh run.

Detection: when a diff touches both (a) a fixture/dataset generator and (b) a results/benchmark doc, check whether the generator's diff changes the shape or size of what it writes (data-type change, changed count/range/field set) beyond comments. If so, never trust "doc diff shows no numeric changes" — run the generator and re-derive at least one headline number (input size, record count) against the doc.

Exclude: generator diffs that are comment/docstring-only (verify by stripping comments); results docs explicitly marked illustrative rather than reproducible measured claims.

Severity: CRITICAL when the results doc is cited elsewhere as a published performance claim and the repo's own reproduction instructions would produce different numbers. Fix: regenerate the doc in the same PR as the generator change, or split the generator change into its own PR with regenerated results (or revert it and keep the numbers valid).

Added by: oss-reviewer on 2026-09-02 (onix PR #4): fixture unwrapping changed api_payloads from 51.63 MB (documented) to 46.62 MB (fresh run) — confirmed by running the generator, not by reading the diff.

### 4.108 Jargon-removal rewrite replaces an honest scope note with a fabricated technical justification (HIGH)

De-jargoning a comment that cited an internal-only reason ("out of scope for M6", "predates this module") sometimes invents a plausible-sounding general technical rule as the replacement — and the invented rule doesn't hold elsewhere in the same file or repo. The tell: the new sentence makes a categorical claim ("X can never do Y because Z") that nearby, unremarked code visibly contradicts.

Detection: for every hunk changing from specific/historical framing to a general causal claim, check whether the claim is falsifiable against the rest of the repo — grep the stated mechanism against the files the sentence claims are subject to or exempt from it.

Exclude: rewrites keeping the same specificity (milestone label → still-checkable historical fact); mechanisms the reviewer cannot independently verify.

Severity: HIGH — a wrong "why" is worse than a vague "why": contributors generalize from it and avoid valid refactors or assume nonexistent constraints.

Added by: oss-reviewer on 2026-09-02 (onix PR #4): "PEP-723 dependency isolation means they cannot import a sibling module" — contradicted two sentences earlier by three PEP-723 scripts doing exactly that; the real mechanism was directory placement (uv run prepends only the running script's dir to sys.path).

### 4.109 Numbered internal roadmap slice/milestone tag leaked into application source comments (CRITICAL)

A newly-added source comment (not a commit message, tracked TODO/ROADMAP, or IaC metadata — §4.45 covers that sibling) cites a numbered delivery-plan unit from the project's internal decomposition ("Temporary slice-2 bridge", "Slice 4 migrates...", "Phase 3 removes this") as if the reader can access the plan that numbers it. When that plan is deliberately untracked, the leak is a policy violation, not just an orphaned reference: the tag points at a document that by design never ships with a clone.

```
\b(slice|phase|milestone)[\s-]?\d+\b.*\b(bridge|migrat|remov|revert)
```

Exclude: TODO/ROADMAP/CHANGELOG files; commit messages; PR bodies; citations of an external, tracked doc section.

Severity: CRITICAL when the project's conventions explicitly ban referencing the untracked plan from tracked files; HIGH otherwise (unresolvable reference for a stranger).

Added by: oss-reviewer on 2026-09-02 (onix PR #8): four new comments citing "slice-2"/"Slice 4" from the untracked plan, in run.rs, guard.rs ×2, and an example binary.

Also match a short milestone tag in a comment or a cited filename; "temporary" and "interim" need no digit (§4.142). Exclude also identifiers, hardware names and units.
```
(^|[^A-Za-z0-9])[mM][0-9]+($|[^A-Za-z0-9])
```

### 4.110 Doc regeneration deletes its own migration caveat while renderer-hardcoded prose still describes the pre-migration architecture (HIGH)

A results doc is regenerated by a renderer script after an architecture change. The regeneration correctly removes the transitional "these figures predate X" caveat (the numbers are now fresh) — but the renderer itself carries hardcoded narrative prose describing the OLD architecture, which the regeneration faithfully reprints. With the caveat gone, the stale claim reads as asserted fact and contradicts sibling docs updated in the same commit.

Detection: when a regeneration commit removes a transitional caveat, grep the RENDERER's string literals (not just the rendered doc) for architecture claims, and diff the rendered doc's prose paragraphs against the sibling docs the same commit updated — any disagreement between two files in one commit about what the system does is the finding.

Severity: HIGH — the caveat's deletion is what converts stale-but-shielded prose into a false published claim.

Added by: oss-reviewer on 2026-09-03 (onix PR #11): summarize_results.py's hardcoded GO-verdict paragraph still said "parsed into serde_json::Value" two slices after the engine migrated off it; regeneration deleted the pre-migration caveat and reprinted the stale claim.

In full-scope mode, diff a renderer's string literals against the document it generates, and open every pointer of this shape, intra-file included (case-insensitive):
```
[Ss]ee\s+(the\s+)?[A-Za-z0-9_./-]+'s\s+(module\s+)?(doc|docstring)\b
```

### 4.111 Wiring-presence regression test asserts names/markers, never the call site (HIGH)

A test guards a feature's wiring via substring markers (`grep -qF "$marker" "$file"` or equivalent) matching function names, variable names, or source-import lines — all of which stay satisfied by the callee's *definition* after the actual dispatch/invocation is deleted or reverted. Detection: in a scratch copy, delete only the call site (keep the function body, the source line, and internal helper references) and re-run the test; if it stays green, the guard has a blind spot at exactly the spot a refactor is most likely to silently regress. The fix is a marker on the literal invocation line and/or its gating condition. Especially notable when the test's own doc comment states the "literal call expressions, not bare names" principle but doesn't apply it to the one call that gates the feature.

Exclude: tests asserting behavioral output (exit codes, produced files, counted log entries) rather than textual presence.

Severity: HIGH — a later refactor can revert the whole feature to a no-op with the suite green.

Added by: oss-reviewer on 2026-09-02 (seedling PR #384): all four "Runner wiring" markers survived replacing the sharded-dispatch `if` block with a bare unsharded call, because each matched text inside the dead function definition or a parsing block.

### 4.112 Review-pipeline vocabulary or citation shorthand shipped in a source comment (HIGH)

A source/test comment cites the review process itself instead of the repo's tracker: gate/agent shorthand as a citation (`oss #384`), or phrasing lifted verbatim from a review brief ("mutation-proven", "per the finding"). Tells: (1) the citation prefix matches no convention used elsewhere in the tree (grep for it); (2) the phrase is meaningless to a contributor who never saw the review tooling's prompts. Fix-cycle commits are the prime source — sweep the fix delta specifically, not just the original diff.

```
\boss\s*#\d+\b
\bmutation-proven\b
per (the )?(review|finding|brief)
```

Exclude: CHANGELOG/commit messages/PR bodies; citations that resolve under the repo's established `issue #N` / `PR #N` convention.

Severity: HIGH — ships an artifact of a private review pipeline into public source; unresolvable by any external reader.

Added by: oss-reviewer on 2026-09-02 (seedling PR #384 round 2): a fix commit added `(mutation-proven, oss #384)` to a test comment; `grep -rn "oss #"` showed the format existed nowhere else.

Also match the §4.144 vocabulary.

### 4.113 PR body acknowledges a review finding where the repo bans review vocabulary in PR bodies (CRITICAL)

§4.112 exempts PR bodies by default. A repo whose own CLAUDE.md or policy states that PR bodies
carry no gate/agent/review/AI vocabulary removes that exemption: a phrase naming itself as an
answer to a review ("(finding on ...)", "addresses the finding that", "per review", "flagged by
review") in the PR body is a public violation of the project's own policy and direct evidence
that a private review pipeline shaped the change.

```
\(finding on\b
\bper (the )?(review|finding)\b
\breview(er)?'?s? (comment|feedback|flag(ged)?)\b
\b(previous|this|last|first|next) round\b
```

Exclude: repos with no explicit PR-body policy (§4.112's default exemption stands); ordinary
engineering senses already idiomatic in the repo's own docs ("coverage gate", "gated off").

Severity: CRITICAL when the repo's own policy bans the vocabulary in PR bodies; otherwise §4.112's HIGH.

Added by: oss-reviewer on 2026-09-04 (onix PR #45 round 4): the PR body's Notes opened a bullet
with "Worker cost (finding on the unconditional spawn):" in a repo whose policy names PR bodies.

### 4.114 README delegates detail to a linked file that does not carry it (HIGH)

Trimming a README paragraph to "the full rules live in `<path>`" is the single-home policy's
intended move, and its failure mode: the content sits on a private item's doc comment in a
sibling file, so neither `cargo doc` nor a reader opening the linked file finds what was
promised. For every sentence of the shape "the full X (and Y) live in `<path>`", open `<path>`
and grep it for X and Y; a miss, or a hit only on a private item when the phrasing says "crate
docs", is the finding.

Exclude: links to a module or directory when the content is in a sibling file inside it; links
to "the source" when the reader is expected to read past the linked file.

Severity: HIGH when the delegated fact is behavior- or safety-relevant (an accepted false
negative, a bound) and the same diff introduced the delegation.

Added by: oss-reviewer on 2026-09-04 (onix PR #45 round 5): README linked lib.rs for the
normalization rules and their one documented cost; both lived only in schema.rs private docs.

Applies to code as well: a "see X's doc for why" pointer between items is opened, and the target must carry the reason. A README pointer names a public item or a heading, never "the hashing functions in <file>".

### 4.115 Doc-comment variant enumeration left stale by the commit that widens the match arm (HIGH)

A doc comment enumerates the variants a rule covers ("applies to `List` and `LargeList`
alike"); a commit adds variants to the `|`-chained match arm and updates the arm's inline
comment but not the function doc a few lines above, so the two disagree inside one diff. For
any diff that widens a match arm, grep the doc comment above the function for a closed
enumeration of the old variant list and compare it with the new arm.

```
This applies to `[A-Za-z]+`(/`[A-Za-z]+`)? alike
the specific `[A-Za-z<>:, ]+`
the enclosing `[A-Za-z]+`(/`[A-Za-z]+`)? is
```

Exclude: docs that describe the rule generically ("any list variant carrying the signature");
widenings whose diff also touches the doc comment.

Severity: HIGH when a README or other doc delegates to this exact doc comment as the source of
truth; INFO otherwise.

Added by: oss-reviewer on 2026-09-05 (onix PR #45, f85dc9f): the map arm gained ListView and
LargeListView; `normalized_type`'s and `map_entries`'s docs still named List/LargeList only,
in the same commit that pointed the README at them.

In full-scope mode, diff every closed type enumeration in a doc against the match arms it documents, and "both" or "the two" against the enum's variant count.

### 4.116 PR or commit body cites an untracked agent-tooling path as justification (CRITICAL)

"per `.claude/rules/<topic>.md`" in a PR body, commit message or review reply names the private
mechanism by path, and the path does not exist in any clone. Detect with
`\.(claude|cursor|windsurf|continue|aider)/[\w./-]+\.md`, then confirm the path is absent from
`git ls-tree -r <base> --name-only`. A tracked, intentionally public agent directory is not a hit.

Severity: CRITICAL when the repo's own policy bans process vocabulary in PR bodies; HIGH otherwise.

Added by: oss-reviewer on 2026-09-05 (onix PR #54): the Notes section cited the untracked rule
file that prescribed the bullet's form.

### 4.117 Known-limitations trigger shape narrower than the code's gate (HIGH)

A caveat says the expensive path runs "whenever <shape>", and the gate function its `See` link
points at accepts more arms than the shape names. Open the linked file, find the boolean gate
nearest the description, and list every accepted arm against the doc's enumeration; a missing
accepted arm is the finding (the doc undersells the risk surface a caller sizes a bound from).
Exclude: a generic term defined precisely elsewhere in the same doc.

Added by: oss-reviewer on 2026-09-05 (onix PR #54): "all JSON scalars" versus
`all_basic_scalars`, which also accepts datetime and date values.

### 4.118 Pipeline synonym for "future PR" in public prose ("next slice", "this slice") (CRITICAL under a PR-body policy)

"slice", "tier", "round" or "gate" used as plain English for a future PR or increment, in a repo
whose policy bans pipeline vocabulary from PR bodies. The tell is structural: the same document
uses the ordinary phrasing ("a later version") elsewhere. Scope the check to prose, not code.

```
\b(next|this|the)\s+slice\b(?!\s*(::|\[|\.))
\bdeferred\s+to\s+(the\s+)?next\s+slice\b
```

Exclude: `std::slice`, `.as_slice()`, prose about an actual array slice; repos with no such policy
(INFO at most).

Added by: oss-reviewer on 2026-09-05 (onix PR #55): "deferred to the next slice (#40); this slice
returns the changed key set internally".

Also match the that/each/a determiners and the plural or possessive, outside code spans (case-insensitive):
```
\b(next|this|that|the|each|a)\s+slice'?s?\b
```

### 4.119 Agent-tooling path cited in shipped source or docs (CRITICAL)

The source-comment sibling of 4.116: a doc comment, code comment or docstring cites
`.claude/rules/<topic>.md` (or `.cursor/`, `.windsurf/`) as if it were part of the repo's
documentation graph. The sentence usually already carries its justification, so the citation is
decorative, and the path is absent from `git ls-files`.

```
\((see|per|documented in)\s+`?\.(claude|cursor|windsurf|continue)/[\w./-]+`?\)
`\.(claude|cursor|windsurf|continue)/(rules|commands|skills)/[\w./-]+`
```

Exclude: `.gitignore` or CI entries naming the directory; repos that track the directory publicly.

Added by: oss-reviewer on 2026-09-05 (onix PR #55 round 2): `is_hashable`'s doc ended with
"(see `.claude/rules/arrow-nesting-depth.md`)".

Also grep the bare basename of every untracked agent-rule file against the tracked tree (§4.143).

### 4.120 List-ified paragraph swallows its trailing sentence (HIGH when the sentence is a caveat)

A PR turns a single-paragraph explanation into a bullet list and leaves the sentence that
continues past the list directly under the last item with no blank line; CommonMark's lazy
continuation renders it as part of that item. For a Markdown hunk that introduces a list, check
the first non-blank line after the last item; if it lacks a marker and a separating blank line,
compare with the pre-PR passage to confirm it was independent prose.

```
(?m)^[-*]\s.*[.)]\s*\n(?!\n|[-*]\s|\s)\S
```

Exclude: text meant to continue the last item's own point.

Added by: oss-reviewer on 2026-09-05 (onix PR #57): perf/MUTANTS.md's "not reproducible run to
run" caveat became part of the third mutant bullet.

### 4.121 Versioned-data crate's cross-language parity claim has no runtime assertion (HIGH)

A dependency exists to match another runtime's version of the same data (a Unicode crate versus
CPython's `unicodedata`, tzdata versus the system table) and the "pinned to the same version"
claim lives only in prose. Grep for the claim, then for the paired assertion (the crate's version
constant compared against the reference's reported version) and for an interpreter pin in CI;
absence is the finding. Exclude data generated from the reference at build time, or an exhaustive
differential test over the whole domain.

Added by: oss-reviewer on 2026-09-05 (onix PR #67): `unicode-general-category` 16.0.0 "matching
CPython 3.14 on this machine", no assertion, no Python pin in CI.

### 4.122 Stale numeral in "the N items above" after the list shrank (HIGH in a source-of-truth doc)

```
(?i)\bthe\s+(one|two|three|four|five|six)\s+[a-z][a-z\s-]{2,40}\s+(above|below|just described)\b
```
When a diff removes an item from an enumerated set, recount and compare with the summary
sentence's numeral. Added by: oss-reviewer on 2026-09-05 (onix PR #67): "The two path-rendering
exceptions above" after one was deleted.

Also match a bare numeral before quirks, exceptions, divergences, differences or consequences, a numeral summarising another file's list, and "Step N" or "section N" pointers; recount each in its target (case-insensitive):
```
\b(one|two|three|four|five)\s+[a-z-]+\s+(quirks|exceptions|divergences|differences|consequences)\b
\b(Step|section)\s+[0-9]+\b
```

### 4.123 Reintroduction of an AI-tell a prior commit in the same file explicitly scrubbed (HIGH)

Git-history-relative, not single-snapshot: `git log -p -- <file>` for a prior commit whose message documents removing a named prose tell ("scrubbed AI tells", "removed every em dash"), confirm the pattern's count dropped to ~0 and held across later commits, then check whether the PR reintroduces that exact pattern — especially confined to newly-added text. Exclude: reintroduction by the same author with explicit rationale (editorial reversal). Severity HIGH: the repo's own history already declared this signal an AI tell in this exact file.

Added by: oss-reviewer on 2026-09-05 (seedling PR #388): commit 7df1228 "removed every em dash (the most-common AI tell)" drove the count to 0 across three release cycles; the PR's new Compare Kids copy reintroduced 3, all in its own added sentences.

### 4.124 Verbatim clause duplicated across sibling copy fields meant to read independently (HIGH)

Two copy surfaces meant to complement, not copy, each other (release notes vs long description, CHANGELOG vs release notes) share an identical run of 8+ consecutive words for the same feature callout — the fingerprint of one generated sentence pasted into two fields. Detect with a shingled n-gram overlap (8-grams) between the two files; a plain diff won't surface it. Exclude: literal product/feature names, legal boilerplate, taglines under ~5 words. Severity HIGH.

Added by: oss-reviewer on 2026-09-05 (seedling PR #388): "actual weight or height side by side, or their percentile bands" appeared verbatim, identically dash-wrapped, in both release_notes.txt and description.txt.

### 4.125 Cache or memo key type widened without restating its per-lookup cost (HIGH)

A map keyed by a flat comparable (`String`, a scalar) is widened to a recursive type (an enum
wrapping a nested value) for a new input shape; the variant docs say what changed, but the doc
that states the table's per-lookup cost or security posture elsewhere in the module is untouched.
For each hunk that changes a `BTreeMap<K, _>`/`HashMap<K, _>` key from flat to recursive, grep the
module and its posture doc for a same-diff update; absence is the finding. Exclude internal caches
with no stated cost claim.

Added by: oss-reviewer on 2026-09-05 (onix PR #69): `MemberContent::UnhashableDict`'s key went
`String` → `ItemKey` on a default-path BTreeMap while memo.rs and fxhash.rs stayed unchanged.

### 4.126 Closing "only documented exceptions" sentence omits an item added earlier in the same section (HIGH)

```
(?i)\b(are|is)\s+the\s+only\b[^.]{0,80}\b(exceptions?|divergences?|differences?|quirks?)\b
```
When a diff adds a named divergence or quirk to a section that closes with such a sentence, grep
the sentence for the new item's keyword; absence is the finding. The inverse of 4.122 (a count going
stale after a list shrinks). Added by: oss-reviewer on 2026-09-05 (onix PR #71): the time
seconds-of-day hashing quirk joined the section but not its closing enumeration.

Also match:
```
\bthe (one|only) place\b
```

### 4.127 "Panics: Never" doc section laundering a production `.expect()`/`.unwrap()` (CRITICAL)

A public Rust function carries a rustdoc `# Panics` section whose content asserts the function
cannot panic ("Never: ..."), directly above an `.expect()`/`.unwrap()` in its body. It satisfies
clippy's `missing_panics_doc` (which checks presence, not truth) and reads at a skim like a reviewed
invariant, so it launders a §4.30.c CRITICAL past review. The fix is propagation through a typed
error, never a better sentence.

```
/// # Panics
///
/// Never
```

Exclude: a `# Panics` section documenting a real, caller-triggerable panic; an `.expect()` preceded
by a `// SAFETY:`/`// INVARIANT:` comment already excluded by §4.30.c.

Refinement to §4.87: the narration also appears as "verified empirically, not assumed" and
"verified with X genuinely blocked, rather than assumed"; match
`\b(verified?|proven?)\s+(empirically|with\b.{0,60}\b(blocked|genuinely))\b.{0,40}\b(not assumed|rather than assum)`.

### 4.128 PR-body test count for a multi-binary workspace states a number the tool never emits (CRITICAL)

A multi-binary test runner (`cargo test --workspace`, `go test ./...`, a multi-project Jest
config) prints one `N passed` line per binary or doctest group, never a combined total. A PR body
that states one hedged figure for that command ("498+ passed (Rust workspace)") beside an exact
sibling count for a single-binary tool was never computed by summation. Sum the per-binary lines
from a real run at the cited head (the PR's own CI log is the cheapest source) and flag a mismatch.

```
\d+\+?\s+passed\s*\([^)]*workspace[^)]*\)
```

Exclude: a body that pastes the per-binary breakdown verbatim; a single-binary crate whose runner
emits one line. Severity: CRITICAL when a run at the cited head gives a different total; HIGH when
unverifiable but the hedge beside an exact sibling count shows it was never summed.

### 4.129 Pipeline role noun in a tracked results or methodology doc (CRITICAL)

A committed RESULTS.md or benchmark methodology note describes what else was running on the machine
using the development pipeline's own role names ("two implementer sessions", "a reviewer session",
"the orchestrator") instead of a plain description ("two other builds of unrelated branches").
It reads as unresolvable jargon to an outside reader and names the agentic setup in tracked
content, which the repo's attribution policy forbids beyond PR bodies and commit messages.

```
\b(implementer|reviewer|orchestrator|subagent)\s+sessions?\b
```

Exclude: dictionary uses in a standards context ("the implementer of RFC 1234 MUST"). Fix: state
the confound in plain terms (what ran, what was checked before timing) with no role noun.

### 4.130 A wall-clock timing assertion added to a repo that already removed one as flaky (HIGH)

A new unit test bounds measured wall-clock time (`Instant::now()`, `time.perf_counter()`) to guard a
complexity class, in a repository whose own history holds a commit that removed the same shape for
spurious CI failures and replaced it with a deterministic operation or byte counter. The fix pattern
is already in the repo: instrument the count under test and assert the bound with no clock in the loop.

```
git log --all -i --grep='flaky.*timing\|timing.*flaky\|noise-dominated\|wall.clock'
```

Exclude: `#[ignore]`/opt-in benchmarks and criterion-style suites with committed baselines.

### 4.131 A narration cleanup commit that fixed some sibling phrases and missed others (HIGH)

A later commit rewords doc comments to drop development-history narration ("an earlier revision",
"before this variant existed", "no longer pre-filters") in named files, while the same PR introduced
the same phrase family elsewhere (a test's rationale comment, a docstring edit) that the sweep missed.
After such a commit, re-grep the whole PR diff for the phrase family, not only the files it names.

```
earlier (revision|version)|before this (variant|feature|type) existed|no longer (pre-filters|does|is)|used to (be|do|call)
```

Also match, and flag test names containing `_now_` or `_old_`:
```
\b[Uu]sed to (be|do|call|return|have|get|give|raise|fail|crash|report|emit)\b|\b[Pp]reviously [a-z]+|\bthe old (path|algorithm|form|port|ceiling)\b|pre-fix|before the fix|\bpre-#?[0-9]+\b|Regression (test|for)\b|has always (had|given)|predates|now also|is now (covered|match)|stored exactly as before|this replaces|keeps working unchanged|switched to|(grew|shrank|went) from [0-9]+ to [0-9]+|earlier ([a-z]+ ){0,3}version|at the time this crate landed
(fn|def) test_[a-z0-9_]*_(now|old)_
```

### 4.132 Unanchored "the regression for X" incident reference in a shipped test docstring (HIGH)

A test docstring or comment names a specific input value or scenario as a past "crash", "regression"
or "bug" with no stable external anchor (issue, PR or CVE number) a future reader could resolve. The
invariant under test is usually already stated in the same docstring; the incident clause is
narration of the session that produced the test. Distinct from §4.76 (an actual `PR #N` citation)
and from §4.87's exclusion (a regression comment anchored to a real identifier).

```
\b(the regression for|the crash for|a regression from|used to crash)\b
```

Exclude: CHANGELOG.md and decision records; a regression comment anchored to a real issue, PR or CVE.

Severity: HIGH. The invariant is stated correctly beside it, but the clause is undecodable without
the review thread and never un-references itself once merged. Fix: keep the invariant sentence, drop
the incident clause, or justify the magnitude in its own terms ("a value far past the ceiling").

Also match:
```
doubles as the .{0,40}regression|the fix targeted|the bug this|the reported repro|headline defect|once already|Accepting it produced
```

### 4.133 Pipeline role noun as a possessive or adjectival modifier (CRITICAL)

§4.129 catches "a reviewer session" but not the same leak in other grammatical forms: a possessive
("the reviewer's probe", "the implementer's fix"), an adjective ("a reviewer-injected fault"), or a
bare role noun standing in for a person or for "manually" ("verified by the reviewer"). The rule is
§4.129's: any of implementer, reviewer, orchestrator, subagent or agent naming who performed an
action in a PR body, commit message or tracked doc, in place of a plain description of the action.

```
\b(implementer|reviewer|orchestrator|subagent)('s|-(injected|found|added|verified))\b
\bverified by the (reviewer|implementer|orchestrator)\b
```

Exclude: standards usage ("the implementer of RFC 1234 MUST"). Severity: CRITICAL, matching
§4.129. Fix: state the method ("verified by injecting an assert in the spawn loop, which hung
45 s before the fix").

### 4.134 Internal review-gate name cited as justification in a public PR or commit body (CRITICAL)

A PR body justifies a claim by naming an internal pipeline gate ("the security review's item
6", "per code-health") instead of restating the substance. It leaks the pipeline and leaves an
unresolvable index. Grep the body with `-i review`, not only for role nouns.

```
\b(the\s+)?(security[\s-]review|code[\s-]health|pr[\s-]review(er)?|oss[\s-]review(er)?)\b['’]?s?\s+(item|finding|note)
```

Exclude: a repo whose CONTRIBUTING documents a human review team by that name. Severity:
CRITICAL under a binding no-gate-terminology policy; HIGH otherwise.

### 4.135 Doc comment orphaned above the wrong declaration by an extract refactor (HIGH)

An extract-struct or extract-function refactor moves the code and writes the new item a fresh
doc, but leaves the original function's doc (and adjacent cast or invariant `//` notes) above
the new declaration. Tell: two stacked doc comments above one item, the first opening with an
action verb ("Streams", "Routes") over a plain data struct, and a cast note with no cast nearby.

```
///[^\n]*\b(Streams?|Routes?|Renders?|Compares?)\b[^\n]*\n(///[^\n]*\n)*(//[^\n]*\n)*struct\s+\w+\s*\{
```

Exclude: a struct that itself implements the described behavior (an Iterator). Severity: HIGH.

### 4.136 Version-bump narrative survives a rebase without relabeling (HIGH)

A commit message, PR body table header or results document names a bump written against the
old base ("Bumps to 0.10.1") after the branch was rebased onto a base that shipped a higher
version and the manifest was re-bumped relative to it. Check every version claim against
`git show <sha>:<manifest>` at that commit and its parent, especially when the parent SHA
changed between rounds.

```
[Bb]umps? to `?[0-9]+\.[0-9]+\.[0-9]+`
```

Exclude: a version used as a provenance anchor tied to a git SHA. Severity: HIGH; a squash
merge lands it in permanent history as authored.

### 4.137 The same measured figure rounded two ways in one prose section (INFO)

A results doc states a value in a table and restates it rounded differently in two nearby
sentences; a PR body inherits one of the two. Detection: for each prose numeral that restates
a table cell in the same file, recompute the cell's rounding and compare. Exclude legitimately
different quantities (mean vs median). Severity: INFO; fix by using the table's rounding once.

### 4.138 Companion doc restates a script's single-home rationale beyond its pointer (HIGH)

A README or results doc adds the one-line pointer to a script's or example's module doc and
then restates the same causal clause ("so every pass re-reads exactly as X does") as prose.
Diff the sentences around each pointer against the target's own text; a near-paraphrase beyond
the pointer is the finding. Severity: HIGH where the repo's convention forbids restatement.

### 4.139 A version bump adds measurements without refreshing the results doc's version stamp (HIGH)

When a diff bumps the manifest version and adds a measured section to a results doc whose own
history pairs every prior bump with an update to its version cell, an untouched cell
misattributes the new numbers. Check `git log -p` on that cell before flagging.

### 4.140 Sub-item ordinal cited against a real issue whose body has no such numbering (HIGH)

A source or test comment cites a real issue by number plus a sub-item ordinal ("issue #66 item
19", "issues #66 items 4, 9"). The outer reference resolves, so a shallow existence check passes,
but the issue body's checklist is unordered or shorter than the ordinal, so the citation is
unresolvable for a contributor who follows it. The numbering leaked from a review round's or a
brief's own item list, not from the tracker. Distinct from 4.109, where the whole plan is
untracked.

```
\b(issue|issues)\s+#\d+\s+items?\s+[\d,\s]+
```

Detection: fetch the cited issue's body (Read ticket operation; GitHub host: `gh issue view <n> --json body`) and count its entries
under the continuous and per-section schemes; the ordinal must exist under at least one. Exclude a
numbered list the body actually carries at that ordinal, and a tracked roadmap's own numbering.
Fix: drop the ordinal and keep `(issue #<n>)`, or describe the requirement in words.

Severity: HIGH; CRITICAL when the repo bans citing internal-only artifacts and the ordinal is
confirmed to come from one.

### 4.141 A docstring or comment trim strands a companion doc's pointer to a named artifact (CRITICAL)

A README, RESULTS or CONTRIBUTING sentence names a specific artifact inside a source file's
docstring or comment block ("see the module docstring for the verification command", "the file's
docstring lists every case"), and a trim PR removes exactly that artifact while the pointing
sentence, outside the PR's diff, stays. A topic-level pointer ("explains its subprocess
isolation") tolerates paraphrase; an artifact-level pointer (a literal command, table or
enumerated list) breaks when the artifact goes.

Detection: for every file a PR trims, grep the tracked tree for the file name near "docstring",
"module doc", "see" or an artifact noun (command, table, schema, list), then confirm the named
artifact is literally present at the target after the PR, not merely prose on the same topic.

Severity: CRITICAL: a reader follows a live breadcrumb in a shipped doc to text that asserts a
guarantee and withholds the means to check it, across a file boundary ordinary diff review never
crosses.

Full-scope mode opens every such pointer (§4.110).

### 4.142 Roadmap-phase vocabulary in shipped prose (HIGH)

A comment, doc or README sentence dates itself to an internal plan: "MVP", "POC", "in this version",
"for now", "later versions add", "implemented so far", "would be added the same way", "temporary
bridge", "interim", "stopgap". The sentence is true on the day it is written and silently false after
the next release; a stranger cannot tell which version "now" means.

```
\b(MVP|POC|in this version|for now|this phase|temporary bridge|interim|stopgap)\b
\b(later|future) versions?\b|(implemented|supported) so far|would be added the same way
```

Exclude: CHANGELOG, ROADMAP and TODO files; a limitation anchored to a tracker number (§4.36
territory); "interim" as a finance or standards term. Case-insensitive.

Severity: HIGH; CRITICAL when the repo bans references to its untracked plan from tracked files.
The text goes false silently and the plan it points at never ships with a clone.

Added by: oss-reviewer self-mutation on 2026-10-07 after observing convert.rs:6 and ignore_order/mod.rs:45.

### 4.143 Untracked-plan or private-rule authority cited in tracked prose (CRITICAL)

Tracked prose justifies a choice by an authority the reader cannot open: "this harness's own rule",
"per the brief" (including across a line break), "marked nice-to-have, not required", "originally
envisioned", a private rule file named by basename ("the <name> convention"), or a coding guide named
by file name. §4.1 and §4.119 catch the path and the short form; this entry catches the paraphrases.

```
(this|the) harness's own (rule|design|principle|fairness rule)|per\s+(the\s+)?brief|nice-to-have, not required|originally (envisioned|suggested|anticipated)|[a-z]+-coding-guide(\.md)?
for f in .claude/rules/*.md; do [ -e "$f" ] || continue; git grep -n -- "$(basename "$f" .md)"; done
```

Join lines first (`tr '\n' ' '`) for the first line; a generic basename needs each hit read. Case-insensitive. Exclude: a guide the repo
tracks and links; CONTRIBUTING text that names a tracked rule file.

Severity: CRITICAL where the repo bans untracked-file references; HIGH otherwise.

Added by: oss-reviewer self-mutation on 2026-10-07 after observing summarize_results.py:526 and gen_goldens.py:712.

### 4.144 Agent-harness and review vocabulary in tracked prose (CRITICAL)

Beyond the role nouns of §4.129 and §4.133: session and review-process terms leak into comments, test
docs and results docs ("foreground session", "fix round", "Round-2", "found during review", "review
follow-up", "this fix's reviewed scope", "merged head", "the <x> finding" naming a behaviour).

```
\b(foreground|background) session\b|\bfix round\b|\bround[- ]?[0-9]+\b|found during review|review follow-up|\bthis fix('s)?\b|reviewed scope|\bmerged head\b|\bthe [A-Za-z/-]+ finding\b
```

Case-insensitive. Exclude: CHANGELOG, commit messages; "session" as an HTTP or login term; "finding"
in research prose; "round-trip". Fix: state the behaviour or the invariant in plain words.

Severity: CRITICAL under a binding no-pipeline-terminology policy; HIGH otherwise.

Added by: oss-reviewer self-mutation on 2026-10-07 after observing bench_tables.py:11-12 and diff/tests.rs:872.

### 4.145 Results document grades the change against its own target (HIGH)

A tracked results or benchmark doc reports whether "the target of this change is met" or a figure is
"within the 4x-of-<tool> target". The target is the originating ticket's, not the reader's; it dates
the doc to one change and goes stale when the next one moves the number.

```
\b(target|goal) of this (change|PR|work)\b|\b[0-9]+x[- ]of[- ][A-Za-z]+ target\b
```

Case-insensitive. Exclude: a target the README publishes as a standing guarantee; a CI threshold
quoted from the config that enforces it. Fix: state the measurement, and the standing bound if one exists.

Severity: HIGH; CRITICAL where the ticket is untracked.

Added by: oss-reviewer self-mutation on 2026-10-07 after observing perf/arrow/RESULTS.md:630-632, where the change is graded against the ticket's goal.

### 4.146 Config file that is mostly the tool's template comments (HIGH)

A tool config (`deny.toml`, `rustfmt.toml`, `.eslintrc`, `tsconfig.json`) keeps the commented-out
output of the tool's `init` command, so comments outnumber settings. Threshold: more than 50% of
non-blank lines are comments and those comments match the tool's `init` output. Cross-reference
beyond-source §5.11, which states the same threshold.

```
awk 'NF{n++} /^[[:space:]]*(#|\/\/)/{c++} END{if (n && c/n > 0.5) print FILENAME, c"/"n}' FILE
```

Exclude: a config whose comments are repo-specific rationale; generated lockfiles.

Severity: HIGH. Scaffold left untrimmed; the settings that matter are buried.

Added by: oss-reviewer self-mutation on 2026-10-07 after observing deny.toml:198 of 248 lines.
