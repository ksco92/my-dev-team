# Python Coding Standards Guide\

This document defines the Python coding standards for Rodrigo's projects. These standards are enforced through automated
linters and formatters configured in the codebase.

---

## Table of Contents

1. [General Coding Standards](#general-coding-standards)
2. [Unit Testing Standards](#unit-testing-standards)

---

## General Coding Standards

### Module Structure

#### Module Docstrings

Every Python file must contain a top-level module docstring on the first line after any shebang or encoding
declarations.

**Format**:

- Triple quotes must be on the same line as the text
- Use imperative mood
- Keep it concise and descriptive, at most ten physical lines counted by
  `ast.parse(src).body[0]`'s `end_lineno - lineno + 1` (the closing quotes count); a diff
  hunk that looks short can still land one line over

**Example**:

```python
"""Client for S3 operations."""
```

**Not**:

```python
"""
Client for S3 operations.
"""
```

### Imports

#### Import Organization

Imports are automatically organized by `isort` into three groups with blank lines between:

1. **Standard library imports**
2. **Third-party imports**
3. **Local/internal imports**

**Example**:

```python
"""Client for Athena operations."""

import json
import logging

import boto3
from pyathena import connect
from typing_extensions import Self
```

#### Import Style

- Use absolute imports for internal packages
- Import specific items when only a few are needed
- Import the module when many items are needed
- Never use wildcard imports (`from module import *`)

### Type Hints

#### Required Type Hints

All function parameters and return types must have type hints.

**Required**:

- Function parameters
- Function return types
- Class attributes (when not obvious from initialization)

**Example**:

```python
def run_query(self: Self, query: str, fetch_size: int = 1000) -> list[dict]:
    """Run a SQL query in Athena."""
    pass
```

#### Type Hint Style

**Use native types** (Python 3.10+):

- ✅ `dict`, `list`, `tuple`, `set`
- ❌ `Dict`, `List`, `Tuple`, `Set` (from `typing`)

**Use `collections.abc` for ABC-based generics** (PEP 585 — same migration as above, just a
different source module):

- ✅ `from collections.abc import Iterator, Callable, Iterable`
- ❌ `from typing import Iterator, Callable, Iterable`

**Use union operator for optional types**:

- ✅ `str | None`
- ❌ `Optional[str]`

**Use `Self` for instance methods**:

- ✅ `def __init__(self: Self, ...) -> None:`
- ❌ `def __init__(self, ...) -> None:`

**Import `Self` from `typing_extensions`**:

```python
from typing_extensions import Self
```

**No `typing.Any`** (flake8-annotations ANN401): a third-party client gets a `Protocol` with exactly
the methods used, a JSON payload a recursive type alias.

#### Complex Type Hints

For complex return types, use full type specifications:

```python
def initialize_job() -> tuple[
    SparkSession,
    str,
    str,
    str,
    int,
    GlueContext,
    GlueClient,
    str,
    S3Client,
    str,
    str,
    int,
    str,
    str,
    list[str],
    str,
    str,
]:
```

### Docstrings

#### Function and Method Docstrings

A function is public when its name has no leading underscore and it lives outside a test module;
every function in a test module follows the private rule.

- **`:param:`, `:return:` and `:raises:` lines appear only on a public function or method of more
  than three statements**, in the Sphinx form below.
- **A `_private` helper, or any function of three or fewer statements**, takes a one-line docstring
  or none.
- **No docstring is longer, in physical lines, than the body it documents.** When the Sphinx form
  would be, keep the summary line and only the lines that state a constraint the signature cannot.

**Format**:

- First line: Brief description in imperative mood
- Blank line
- Parameter descriptions (if any)
- Return description (if not None)
- Raises descriptions (if applicable)

The bodies below are elided; each stands for more than three statements and outruns its docstring.

**With Parameters and Return Value** (no `:param query:`: it would paraphrase the name):

```python
def run_query(self: Self, query: str, fetch_size: int = 1000) -> list[dict]:
    """
    Run a SQL query in Athena and return every row.

    :param fetch_size: Rows requested per page; Athena caps it at 1000.
    :return: One dictionary per row, keyed by column name.
    """
    ...
```

**With Optional Parameters**:

```python
def __init__(
        self: Self,
        workgroup_name: str | None = None,
        catalog_name: str = "AwsDataCatalog",
        profile_name: str | None = None,
) -> None:
    """
    Create the client.

    :param workgroup_name: Workgroup to run queries in; None uses the account's primary workgroup.
    :param profile_name: Credentials profile; None uses the default credential chain.
    """
    ...
```

**With Raises**:

```python
def download_files(self: Self, bucket_name: str, prefix: str, local_path: str) -> None:
    """
    Download every object under a key prefix to a local directory.

    :param local_path: Directory to write into; it must already exist.
    :raises ValueError: When local_path does not exist.
    """
    ...
```

**Three or Fewer Statements, or Private**:

```python
def sum_nums(a: int, b: int) -> int:
    """Sum two numbers."""
    return a + b
```

#### Docstring Rules

- **All parameter descriptions must end with a period**
- **Use imperative mood**: "Create the client" not "Creates the client"
- **Be concise but descriptive**, sized to the budget in `${CLAUDE_PLUGIN_ROOT}/context/agent-baseline.md`
  (Comment, docstring, and helper budget): the contract plus at most one constraint the signature
  cannot show. No test evidence, no "confirmed against X", no rationale essays, no `:raises:` for
  an exception that cannot fire.
- **No single-use one-statement helpers**: a private `_helper()` with one call site and one
  statement (`if pred(x): raise`, a renamed stdlib call) is inlined at the call site, not written,
  typed, and given a docstring longer than its body.
- **Structure first**: a docstring that describes more than one step is a numbered list of what
  happens, with rationale at most one trailing clause per step; deep rationale belongs at the line
  it justifies or in the PR.
- **A `:param:` line carries what the name and type hint cannot** (a unit, an accepted range, what
  `None` means); omit it when it would paraphrase the name, as `:param bucket_name: Name of the
  bucket.` does.
- **In the Sphinx form, document the return value unless it is None**
- **In the Sphinx form, document exceptions that can be raised**: only the exceptions a function
  raises with a literal `raise` statement in its own body. Don't tag exceptions that merely propagate
  from a function it calls (e.g. a thin wrapper around a call that itself raises) — that
  reading would eventually require `:raises:` on most functions in the codebase, since
  exceptions propagate by default. Document propagation-only cases, if ever needed, at the
  function that actually raises.

### Classes

#### Class Docstrings

Classes should have a brief docstring describing their purpose.

```python
class AthenaClient:
    """Client for Athena operations."""

    def __init__(self: Self, ...) -> None:
        """Create the client."""
        pass
```

#### Class Attributes

Initialize all instance attributes in `__init__` for clarity:

```python
def __init__(self: Self, workgroup_name: str | None = None) -> None:
    """Create the client for one Athena workgroup."""
    self.workgroup_name = workgroup_name
    self.catalog_name = "AwsDataCatalog"
    self.profile_name = None
```

### Code Formatting

#### Line Length

- **Maximum line length**: 130 characters
- Lines exceeding this are ignored after `black` formatting
- Break long lines naturally at logical points

#### String Formatting

**Prefer f-strings** for string interpolation:

```python
logging.info(f"Downloading {key} from bucket {bucket_name} to {local_file_path}...")
```

**For long strings**, break them across lines:

```python
error_message = (
    "This is a very long error message that exceeds "
    "the maximum line length allowed by the linter configuration"
)
```

#### Whitespace

- **No whitespace before colons** in slices, type hints, or dict literals (enforced by `black`)
- **Line breaks before binary operators** (enforced by `black`)
- **Consistent indentation**: 4 spaces (never tabs)

#### Blank Lines Around Multi-line Statements

This is a pure readability aid for a human scanning the function top to bottom — it has
no effect on behavior. Three rules, in order of precedence:

1. **`return` always gets a blank line above it**, regardless of what precedes it or
   whether the return itself is a single line.
2. **A `for`/`if`/`while`/`with` block always gets a blank line above it** (when it isn't
   the first statement in its enclosing block) **and a blank line below it** (when
   something follows in the same block) — this holds regardless of whether its neighbor
   is itself single- or multi-line.
3. **Any other statement that spans multiple physical lines** (a call, collection
   literal, etc. whose closing token isn't on the line it opens) **gets a blank line on
   any side bordering a different statement** — whether that neighbor is single-line or
   itself multi-line. Two multi-line statements sitting back to back still each read as
   their own paragraph, so they still get a blank between them. A multi-line statement
   bordering a `for`/`if`/`while`/`with` block is already covered by rule 2 from that
   block's side.

Never add a blank line immediately after a block header and its first body line (e.g.
between `for x in y:` and its first statement) — the indentation already marks that
boundary. Not required when the multi-line statement is the only statement in its
enclosing block, or when nothing precedes/follows it to separate from.

**`try`/`except` is exempt from rule 2.** A stacked `except` ladder (e.g. several
`except SomeError:` clauses in a row handling related failure modes) is commonly kept
dense on purpose — don't force blank lines between `except` clauses or around a
`try`/`except` block the way `for`/`if`/`while`/`with` require them.

**A stacked `if`-guard-clause ladder is exempt too.** Several `if condition: return X`
early exits in a row (a validation chain) are a single logical unit, same spirit as the
`try`/`except` exemption above — don't force blank lines between consecutive guard
clauses. This is distinct from an `if` that gates a larger body (that still follows rule
2 normally); the exemption is specifically for a run of short, single-purpose early
returns.

**Example** (drawn from `build_earnings_rows` and `get_data_frame`):

```python
rows: list[tuple] = []

for record in records:
    report_date = as_optional_date(record.get("report_date"))

    if report_date is None:
        continue

    rows.append(
        (
            symbol,
            report_date,
            ...
        ),
    )

return rows
```

```python
universe_size = symbols.count()

rows = symbols.rdd.mapPartitions(
    lambda partition: fetch_earnings_for_partition(partition, api_token, to_date),
)

df = drop_duplicates(spark.createDataFrame(rows, schema=earnings_schema), pk_columns).persist()

if universe_size and is_df_empty(df):
    raise EODHDError(
        "eodhd.earnings_calendar fetched zero rows for a non-empty symbol universe; "
        "the calendar/earnings response shape may have changed.",
    )

return df
```

### Comments

#### When to Comment

- **Do**: Comment complex logic, non-obvious decisions, or workarounds
- **Don't**: Comment obvious code
- **Don't**: Leave placeholder comments like "Add this line" or "NEW LINE"

#### Comment Redundancy

Don't restate reasoning that's already captured elsewhere at the right altitude — the
function's own docstring, the message of an exception it's about to raise, or the code
itself. A comment earns its place only when it adds information nothing else in the file
already states.

**Not** (the ordering rationale is already the docstring's own numbered step):

```python
def get_data_frame(spark: SparkSession) -> DataFrame:
    """
    ...
    5. Deduplicates on the primary key, caches the frame, and guards it against a
       silent empty fetch before returning it (the cache precedes the guard so the
       guard does not re-run the fan-out).
    """
    df = drop_duplicates(...).persist()
    # Cache precedes the guard so the emptiness probe does not re-run the fan-out.
    if universe_size and is_df_empty(df):
        ...
```

**Do**: drop the comment — the docstring's numbered step already carries that rationale.

Likewise, don't preserve a past implementation trade-off ("did X instead of Y because Z
was cheaper") as a permanent inline comment once the decision is made and the code reads
clearly on its own. That reasoning belongs in the PR or issue that made the call, not as a
comment every future reader carries forward:

**Not**:

```python
    # Second PK lookup in the run (JobHandler resolves it too, for the MERGE):
    # get_data_frame(spark) receives no PK, and one extra GetTable per run is
    # cheaper than widening the module contract.
    glue_client = GlueClient()
    pk_columns = glue_client.get_table_pk("eodhd", "earnings_calendar")
```

**Do**: drop the comment — the two-line call is self-explanatory, and the trade-off lives
in the PR description.

A comment or docstring explaining why code is copied rather than imported is itself the finding:
fix the import path (a `pythonpath` entry, a shared module) and delete both the copy and the
explanation.

#### Comment Style

- Use `#` for inline comments
- Keep comments concise and developer-friendly
- Avoid AI-generated phrasing

#### Comments on Constants

- A constant's comment states its purpose in two lines or fewer and annotates the thing it is
  attached to.
- Never alias a shared constant (`LOCAL = SHARED`) to have something to hang a comment on.

#### Section Separators

Multiline comment separators are used for readability and **must not be removed**. Apply
them uniformly to every **job module** under `src/charmander/databases/` — one labeled
banner before its constants block (if any) and one before each top-level function or
logical method group, regardless of the file's size. A short, 3-function job module gets
the same treatment as a large one; don't size-gate this on line count or perceived
necessity within that population — consistency across every job module is the point:

```python
##############################################
##############################################
##############################################
##############################################
# Initialize

# ... code here ...

##############################################
##############################################
##############################################
##############################################
# ETL Logic

# ... code here ...
```

**Exceptions to the uniform mandate**:

- **Small utility files** (roughly 1-3 functions, no distinct logical groups to
  signpost — e.g. a single parser or a single small helper class) don't need banners at
  all. A banner earns its keep dividing multiple logical groups in a larger file; a
  19-line single-function file has nothing to divide, and the banner would outsize the
  code it labels. A multi-function or multi-group utils file (several unrelated helpers,
  or a class with a clear public/private split) still gets the full treatment. **This
  exemption does NOT extend to job modules under `databases/`, regardless of function
  count** — job modules get the uniform banner treatment even at their smallest (a single
  `get_data_frame` plus a constants block still gets one banner per group). Consistency
  across every job module was an explicit, deliberate choice, not an oversight.
- **Test files keep their existing, lighter `# <category> tests` single-line grouping
  comment** (see Test Organization below) instead of full banners — that convention
  already predates this rule and is universal across the whole test suite, not just a
  per-file choice.
- **Files with many small private helpers** (e.g. several single-purpose functions like
  `_parse_utc`, `_build_sentiment`) group those helpers under one shared banner (e.g.
  `# Helpers`) rather than giving each its own — one banner per **public**
  function/entry point, not per function. Mirrors the `job_handler.py` convention of a
  `Public API` / `Internals` split.

### Error Handling

#### Raising Exceptions

Be specific about error conditions:

```python
def cpc_predictor(query_text: str | None = None) -> dict:
    """Predict CPC codes based on query text."""
    if query_text is None:
        raise ValueError("query_text is None.")

    if len(query_text) > 1000:
        raise ValueError("query_text is too long, max is 1000 characters.")

    # ... rest of function
```

#### Exception Messages

- Be clear and specific
- Include relevant context
- End with a period

#### Exception Clauses

Python 3.14 (PEP 758) accepts `except A, B:` without `as`. It is a readability finding, fixed with
stacked single-exception clauses, each a branch with its own test. black with a py314 target
rewrites `except (A, B):` into that form, so neither a tuple nor a formatter directive is a fix, and
a request to collapse two clauses into one is declined on that ground.

#### Defensive Code

A guard, retry or fallback needs an observed, recurring failure class; a guard for a case nothing
has produced is removed, not documented.

### Logging

#### Logging Style

Use the standard `logging` module:

```python
import logging

logging.info(f"Executing query -> {query}")
logging.info(f"Downloaded {len(all_keys)} files!")
```

#### Log Levels

- `logging.info()`: Normal operational messages
- `logging.warning()`: Warning messages
- `logging.error()`: Error messages
- `logging.debug()`: Detailed debugging information

### Function Parameters

#### Parameter Ordering

1. Required positional parameters
2. Optional parameters with defaults
3. `*args` (if needed)
4. Keyword-only parameters (after `*`)
5. `**kwargs` (if needed)

#### Default Values

- Use `None` for optional parameters that need validation
- Use meaningful defaults when appropriate
- A docstring states what a default means when the value alone does not (`None` meaning the default
  credential chain); it never restates a value the signature shows

**Example**:

```python
def __init__(
        self: Self,
        aws_region: str | None = None,
        aws_access_key_id: str | None = None,
        aws_secret_access_key: str | None = None,
        aws_session_token: str | None = None,
        profile_name: str | None = None,
) -> None:
    """Create S3 client."""
    pass
```

### Return Values

#### Return Type Consistency

Functions should return consistent types:

```python
def list_files(self: Self, bucket_name: str, prefix: str) -> list[dict]:
    """List all the files in a prefix."""
    return get_all_results(...)
```

#### Early Returns

Use early returns for error conditions:

```python
def run_query(self: Self, query: str, fetch_size: int = 1000) -> list[dict]:
    """Run a SQL query in Athena."""
    cursor = self._create_cursor()
    cursor.execute(query)

    if cursor.description is not None:
        # ... process results
        return results
    else:
        return []
```

### Naming Conventions

#### General Rules

- **Modules**: `snake_case` (e.g., `athena_client.py`)
- **Classes**: `PascalCase` (e.g., `AthenaClient`)
- **Functions**: `snake_case` (e.g., `run_query`)
- **Variables**: `snake_case` (e.g., `bucket_name`)
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `TOP_K_RESULTS`)
- **Private methods**: Prefix with single underscore (e.g., `_create_cursor`)

#### Descriptive Names

Use clear, descriptive names:

- ✅ `bucket_name`, `query_text`, `fetch_size`
- ❌ `bn`, `qt`, `fs`

### Code Organization

#### Method Ordering in Classes

1. `__init__` method
2. Public methods
3. Private methods (prefixed with `_`)

#### Logical Grouping

Group related functionality together:

```python
class S3Client:
    """Client for S3 operations."""

    def __init__(self: Self, ...) -> None:
        """Create S3 client."""
        pass

    # File listing methods
    def list_files(self: Self, ...) -> list[dict]:
        """List all the files in a prefix."""
        pass

    # Download methods
    def download_file(self: Self, ...) -> None:
        """Download a specific file from S3."""
        pass

    def download_files(self: Self, ...) -> None:
        """Download the contents of an S3 key."""
        pass

    # Upload methods
    def upload_file(self: Self, ...) -> None:
        """Upload a single file to S3."""
        pass

    def upload_data(self: Self, ...) -> None:
        """Upload data directly to S3."""
        pass
```

### Project Version and Lockfile

After bumping the project version in `pyproject.toml`, run `uv lock` and commit `uv.lock` in the
same commit. Verify by grepping the committed file, not the working tree.

### Linter Configuration

A repository with tracked `.py` files runs a linter and a format check over them in its merge gate
(`make check` or the CI equivalent). `ruff check` plus `ruff format --check` is an accepted
single-tool equivalent of the Black, isort and Flake8 set below.

The following linters are used and their rules must be followed:

#### Black (Code Formatter)

- Automatically formats code
- Handles line length, whitespace, and string quotes
- **Do not fight black's formatting decisions**

#### isort (Import Sorter)

- Automatically organizes imports into three groups
- Maintains consistent import ordering

#### Flake8 (Style Checker)

**Ignored Rules**:

- `E203`: Whitespace before ':' (conflicts with black)
- `W503`: Line break before binary operator (conflicts with black)
- `E501`: Line too long (handled by black)

**Enforced Rules**:

- Docstring style: Sphinx
- Maximum line length: 130 characters
- Flake8-commas: Enforces trailing commas
- Flake8-multiline-containers: Enforces multiline formatting for lists, dicts, sets, tuples

#### Mypy (Type Checker)

- Enforces type hint correctness
- Runs with `--no-incremental` flag
- All type errors must be resolved

### Coverage Requirements

**Minimum code coverage**: 95%

All code must be tested to at least 95% coverage. This is enforced during the build process.

---

## Unit Testing Standards

### Test Framework

**Use pytest** for all tests. Do not use `unittest`.

### Test File Structure

#### Directory Structure

Test directory structure must mirror the source code structure:

```
src/
└── utils/
    └── aws/
        └── athena/
            └── athena_client.py

test/
└── utils/
    └── aws/
        └── athena/
            └── test_athena_client.py
```

#### Test File Naming

- Test files must be named `test_<module_name>.py`
- Test files must be in the same relative path as the source file

### Test Function Structure

#### Test Function Naming

- Test functions must start with `test_`
- Use descriptive names that explain what is being tested
- Use `snake_case`

**Examples**:

```python
def test_init() -> None:
    pass


def test_create_cursor_with_profile() -> None:
    pass


def test_run_query_empty() -> None:
    pass
```

#### Test Function Signature

All test functions must:

- Have a return type hint of `-> None`
- Not be grouped into classes (use module-level functions)

**Example**:

```python
def test_list_files() -> None:
    # ... test code
```

### Test Docstrings

A test's docstring carries only what its name cannot, such as the boundary its input sits on; omit
it when it would paraphrase the name. A test never documents its fixtures as `:param:` lines.

**No docstring** (the name says everything):

```python
def test_run_query_returns_an_empty_list_for_an_empty_result(athena_client: AthenaClient) -> None:
    ...
```

**A docstring that states a boundary the name cannot**:

```python
def test_run_query_reads_past_the_first_page(athena_client: AthenaClient) -> None:
    """1,001 rows: Athena pages at 1,000, so this is the smallest two-page result."""
    ...
```

### Fixtures

#### Fixture Definition

Use `@pytest.fixture` decorator for reusable test objects:

```python
@pytest.fixture
def athena_client() -> AthenaClient:
    return AthenaClient(workgroup_name="test_workgroup", catalog_name="test_catalog")
```

#### Fixture Usage

Pass fixtures as function parameters:

```python
def test_init(athena_client: AthenaClient) -> None:
    assert athena_client.workgroup_name == "test_workgroup"
```

### Mocking

#### Mock Import

Use `unittest.mock` for mocking:

```python
from unittest.mock import MagicMock, patch
```

#### Patch Context Managers

**Always use context managers** (`with` statements) for patches, never decorators:

```python
def test_create_cursor() -> None:
    with patch("utils.aws.athena.athena_client.connect") as mock_connect:
        mock_cursor = MagicMock()
        mock_connect.return_value.cursor.return_value = mock_cursor

        # ... test code
```

#### Multiple Patches

For multiple patches, use tuple syntax to avoid deep indentation:

```python
def test_create_cursor_with_profile() -> None:
    with (
        patch("utils.aws.athena.athena_client.connect") as mock_connect,
        patch("utils.aws.athena.athena_client.boto3.Session") as mock_session,
    ):
        mock_cursor = MagicMock()
        mock_connect.return_value.cursor.return_value = mock_cursor
        mock_session.return_value.region_name = "us-west-2"

        # ... test code
```

#### Boto3 Mocking

For boto3 operations, create a top-level mock function:

```python
def boto3_mock_make_api_call(
        self: botocore.client.BaseClient,
        operation_name: str,
        kwarg: dict,
) -> dict:
    """Answer ListObjectsV2 and GetObject; raise on any other operation."""
    if operation_name == "ListObjectsV2":
        return {
            "Contents": [
                {"Key": "prefix/file1.txt"},
                {"Key": "prefix/file2.txt"},
            ],
        }
    elif operation_name == "GetObject":
        return {"ContentLength": 10, "Body": StreamingBody(io.BytesIO(b"0123456789"), 10)}
    else:
        raise ValueError(f"Mock for {operation_name} not implemented.")


def test_list_files() -> None:
    with patch("botocore.client.BaseClient._make_api_call", new=boto3_mock_make_api_call):
        s3_client = S3Client()
        response = s3_client.list_files(bucket_name="test_bucket", prefix="prefix/")

        assert len(response) == 2
```

#### ArenalLogger Mocking

**Do not mock `ArenalLogger`** unless the test is specifically testing the logger itself.

### Test Assertions

#### Assertion Style

Use clear, specific assertions:

```python
def test_init(athena_client: AthenaClient) -> None:
    assert athena_client.workgroup_name == "test_workgroup"
    assert athena_client.catalog_name == "test_catalog"
    assert athena_client.profile_name is None
```

#### Testing Exceptions

Use `pytest.raises` for exception testing:

```python
def test_cpc_predictor_with_none_query_text() -> None:
    with pytest.raises(ValueError, match="query_text is None."):
        cpc_predictor(query_text=None)
```

#### Testing Mock Calls

Verify mocks were called correctly:

```python
def test_run_query(athena_client: AthenaClient) -> None:
    with patch("utils.aws.athena.athena_client.connect") as mock_connect:
        mock_cursor = MagicMock()
        mock_connect.return_value.cursor.return_value = mock_cursor

        query = "SELECT * FROM test_table"
        athena_client.run_query(query)

        mock_cursor.execute.assert_called_once_with(query)
```

Use `ANY` for flexible argument matching:

```python
from unittest.mock import ANY


def test_cpc_predictor_successful_prediction() -> None:
    with patch("cpc_predictor.cpc_predictor_handler.BedrockClient") as mock_bedrock_class:
        mock_bedrock = MagicMock()
        mock_bedrock_class.return_value = mock_bedrock

        result = cpc_predictor(query_text="test query")

        mock_bedrock.invoke_model.assert_any_call(
            "global.anthropic.claude-opus-4-5-20251101-v1:0",
            ANY,
            temperature=0,
            max_tokens=100,
        )
```

### Test Coverage

#### What to Test

**Test all code paths**:

- Success cases
- Error cases
- Edge cases
- Boundary conditions

**Example**:

```python
def test_cpc_predictor_with_none_query_text() -> None:
    with pytest.raises(ValueError, match="query_text is None."):
        cpc_predictor(query_text=None)


def test_cpc_predictor_with_long_query_text() -> None:
    long_query = "a" * 1001
    with pytest.raises(ValueError, match="query_text is too long"):
        cpc_predictor(query_text=long_query)


def test_cpc_predictor_successful_prediction() -> None:
    # ... test successful case
```

#### Coverage Threshold

- **Minimum**: 95% code coverage
- Tests must cover all branches and conditions
- Use coverage reports to identify untested code

### Test Organization

#### Test Grouping

Group related tests together in the file:

```python
"""Tests for the S3 client."""


# ... imports ...

# Initialization tests
def test_init_default() -> None:
    pass


def test_init_with_credentials() -> None:
    pass


# List operations tests
def test_list_files() -> None:
    pass


# Download operations tests
def test_download_file() -> None:
    pass


def test_download_files() -> None:
    pass


def test_download_files_invalid_path() -> None:
    pass


# Upload operations tests
def test_upload_file() -> None:
    pass
```

#### Test Independence

Each test should be independent:

- Don't rely on test execution order
- Don't share state between tests
- Clean up any created resources
- Never import a sibling test module; shared helpers are `conftest.py` fixtures or live in a support
  module whose name does not start with `test_`. A test module that
  imports a sibling inherits its module-level `importorskip` through the re-raised `Skipped`, its
  skip line merges into the sibling's, and the file vanishes from interpreter-coverage accounting;
  each file carries its own guard.

### Test Suite Structure

- Three or more test functions, in one module or across the suite, whose bodies are identical after
  replacing literal constants are one `pytest.mark.parametrize` test. A test that loops over a
  literal list of independent cases with an `assert` inside the loop is parametrized the same way.
- Split a test module over about 500 lines that covers more than one feature into one module per
  feature; a `# noqa: E402` import below a test function is the tell.
- A deterministic, read-only artifact built identically by three or more tests in one module is a
  module-scoped fixture (`scope="module"`, with `tmp_path_factory` for files).
- A `_underscored` name imported by another module is renamed public. Replace `from conftest import`
  with a fixture or with a support module whose name does not start with `test_`.
- A duplicate-test-name guard compares names across the whole suite, not per module.
- Three or more keyword arguments forwarded unchanged through two or more functions become one
  frozen dataclass parameter.
- Inline a module constant read once at its use, unless its name documents an external contract (a
  vendor limit, a protocol value).

### Environment Variables

#### Setting Environment Variables in Tests

Set environment variables within the test:

```python
def test_cpc_predictor_successful_prediction() -> None:
    os.environ["sensitive_info_guardrail_arn"] = "gr_arn"
    os.environ["sensitive_info_guardrail_version"] = "1"

    # ... rest of test
```

### Test Data

#### Mock Data

Create realistic mock data:

```python
mock_kb_response = [
    {
        "content": {
            "text": "42992|Base metal fittings|Metal products|Fabricated|Other|Fittings",
        },
        "score": 0.72,
    },
    {
        "content": {
            "text": "42190|Other structures|Metal products|Fabricated|Structural|Other",
        },
        "score": 0.68,
    },
]
```

#### Test Constants

Define a test constant read two or more times at the module level:

```python
"""Tests for the CPC predictor handler."""

TEST_ACCOUNT = "123456789012"
TEST_MODEL_ID = "global.anthropic.claude-opus-4-5-20251101-v1:0"
```

---

## Summary

### Key Principles

1. **Type everything**: All parameters and return values must have type hints
2. **Document the contract**: every module and class has a docstring; a function's follows the
   three shapes in Docstrings
3. **Test everything**: Maintain 95%+ code coverage
4. **Use modern Python**: Native types, union operator, `Self` type hint
5. **Follow the formatters**: Don't fight black, isort, flake8, or ruff
6. **Be consistent**: Follow established patterns in the codebase
7. **Be explicit**: Clear names, clear error messages, clear documentation

### Enforcement

These standards are enforced through:

- **black**: Code formatting
- **isort**: Import organization
- **flake8**: Style checking (with plugins for docstrings, commas, multiline containers)
- **mypy**: Type checking
- **pytest**: Testing with 95% coverage requirement

A rule in this guide that an available linter rule could enforce (the type-hint style, import order,
an import below code) but the repository's configuration does not enable is reported as a finding
against the merge gate, not only against the code that breaks it.

## Self-mutation rule

Maintained by the orchestrating session only, never by a delegated subagent or headless worker,
even one instructed to read this file; a subagent that notices something worth adding reports it
under `Proposed learned pattern:` in its own output. Lessons here are stack-specific and true in
any repo of this stack; repo-specific facts go to that repo's `.claude/rules/`. Append an
imperative bullet under `## Learned patterns` (one sentence, two at most; no date, no repo name,
no "added after" tail), refine near-duplicates in place, keep the section under ~25 entries, and
open a PR against the plugin repository (`ksco92/my-dev-team`). A lesson that only fires in a
Django or DRF project goes to `django-coding-guide.md`; one about the Python face of a native
extension goes to `python-bindings-coding-guide.md`; a lesson that matures into a standing
convention becomes a section above and leaves this list.

## Learned patterns

- Prefer a shared boolean primitive (`is_df_empty`) with the raise inlined at the call site over a
  per-job `_guard_x` wrapper; emptiness probes use `take(1)`, never `count()`.
- Hardware-resource numbers derive from the current machine at import (`os.cpu_count()`,
  `os.sysconf`) with the ratio as the named constant; server-side limits stay literals.
- Guard non-finite JSON numerics before a `Decimal` conversion: `json.loads` accepts bare
  `NaN`/`Infinity`.
- A differential test whose oracle is the interpreter (`repr()`, `unicodedata`, `json`) pins the
  interpreter (`.python-version`, `uv python install` in the workflow) and reads the CI log for
  the one `uv sync` picked.
- When rewriting a Python file by line ranges taken from `ast` line numbers, build the line array
  with `readlines()` or `split("\n")`, never `str.splitlines()`: it also splits on U+2028/U+2029,
  which a string literal can carry, and the array desyncs from the compiler's `\n`-only numbering.
- Measure a file's comment ratio with `tokenize` COMMENT tokens plus docstrings found by AST
  position (the first string statement of a module, class or function); a scan for `#` lines or
  triple quotes counts an embedded script or fixture string as prose.
