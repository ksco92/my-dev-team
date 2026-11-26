# AI-generated-code tells — structural pattern catalog (Phase 3)

Companion reference for the `oss-reviewer` skill. Loaded during Phase 3 **after** running
`${CLAUDE_PLUGIN_ROOT}/bin/preflight-scan`.

Deterministic/regex tells (`AI001`–`AI009`: task/PR leftovers, `TODO`/`FIXME`/`XXX`/`HACK` and
deferral crumbs, chat-leak/narration comments and status-emoji logs, banned prose vocabulary,
committed agent transcripts, committed build artifacts, personal machine paths, placeholder
author/README metadata, absent-language configs; plus `CH001`–`CH006` and `DOC001`–`DOC004`) are
enforced mechanically by `preflight-scan` and are not repeated here. Correctness bugs belong to
`pr-reviewer`; comment ratios, doc-comment budgets, and single-use helpers belong to `code-health`.

This catalog covers only the **structural and judgment tells** a static regex cannot decide.

### 4.1 Whole-file read pass (BINDING)

Read every source file in scope in full (in `--scope=full`, sample only above ~200 files: all entry
points, all shared utilities, and a stratified sample of the rest; state what was sampled). Ask:
does this read like a human engineer's module or an unedited AI transcript? Flag unnatural
uniformity, copy-pasted scaffolding across sibling modules, and logic duplicated instead of shared.

### 4.2 Configuration scatter (HIGH)

Multiple `os.environ.get(...)` / `process.env.*` reads scattered across more than 3 files without a
central config module, or identical magic defaults (`max_retries=3`, `timeout=30`) and URLs repeated
in 3+ files.

### 4.3 Tight-coupling refactor blockers (HIGH)

Direct instantiation of concrete backends/clients in 5+ places where an interface or registry
belongs, or cross-module imports that invert layering (for example a low-level connector importing
from the CLI layer).

### 4.4 Test-suite anti-patterns (CRITICAL)

- Tests that only mock the unit under test and assert the mock was called, proving nothing about
  real behavior.
- Constant-echo tests that assert a module constant equals itself or its own derivation expression
  (HIGH when 3+ appear in a suite).
- Unfalsifiable downstream-invariant tests whose assertion passes even when the feature under test
  is reverted.
- Cross-test-file private helper duplication (same 10+ line fixture builder copy-pasted across test
  files instead of living in `conftest.py` or a shared test helper).
- Tests that read the developer's ambient environment variables or home directory for "default"
  assertions instead of isolating them.

### 4.5 Noun-suffix class proliferation (HIGH)

Unjustified `FooManager` / `BarHelper` / `BazHandler` / `QuxService` wrapper classes that hold no
state and wrap 1–2 functions (Java-shaped boilerplate in Python/TypeScript).

### 4.6 Identical file-header docstring templates (HIGH)

Every file in a package opens with the same multi-line boilerplate template (`Module: ...`,
`Author: ...`, `Description: ...`, `Created: ...`) stamped by a generation prompt.

### 4.7 Hardcoded developer identity in IaC or scripts (BLOCKER)

Hardcoded AWS account IDs, developer IAM user ARNs, personal S3 bucket names, or personal domains
baked into reusable IaC constructs or quickstart scripts instead of parameters/config.

### 4.8 README install command for an unpublished package (CRITICAL)

`pip install <pkg>`, `npm install <pkg>`, or `cargo install <pkg>` shown as a working install step
when `<pkg>` is not yet published on that registry (or is squatted by an unrelated existing
package).

### 4.9 Stale or fabricated transcripts and broken GitHub fragments (CRITICAL)

- Pasted test-output or CLI transcripts in docs whose counts, flags, or formatting contradict the
  current code.
- GitHub URLs carrying `#issuecomment-...` / `#discussion_r...` / commit-hash fragments that do not
  resolve to a real object.

### 4.10 Version and exclusion drift (HIGH)

- Runtime `__version__` / version constant drifting behind `pyproject.toml` / `package.json` /
  `Cargo.toml` on a version-bump PR.
- In-repo consumer pins (`examples/`, `e2e-consumer/`) drifting behind the parent package version.
- Coverage-exclusion lists (`omit` / `--ignore-filename-regex`) silently growing past the documented
  exclusion set.
- Linter configs tied to a `tsconfig` that excludes lintable source files, or CI running an
  auto-fixing lint command without `--check` / `git diff --exit-code`.

### 4.11 Mixed-style tells within a single file (INFO)

Mixing competing idioms inside the same file: f-strings + `%`-formatting + `.format()`; `@dataclass`
and `attrs.define`; `Optional[T]` and `T | None`; mixed quote/naming styles that suggest spliced
generations.

### 4.12 Prose tells beyond vocabulary (INFO / HIGH at cluster)

- High em-dash density (>0.8 per 100 words in docs; >1.5 is HIGH).
- Repeated contrastive-negation cadence ("It's not just X — it's Y", 3+ occurrences in one doc).
- Universal-appeal closing phrasing ("Whether you're a seasoned X or just getting started...").
- Delivery-plan or internal-review vocabulary leaking into deployed descriptions, public docs, or
  unresolvable bare item ordinals ("issue #N item 13" when the issue has no such numbered list).
- Docstring or comment trims that strand another tracked doc's pointer to a specific artifact
  (command, table, or enumerated list).
