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
    """
    Run a SQL query in Athena.
    
    :param query: Variable definition.
    :param fetch_size: Variable definition.
    :return: A list of dictionaries with the results.
    """
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

Use Sphinx-style docstrings for all functions and methods.

**Format**:

- First line: Brief description in imperative mood
- Blank line
- Parameter descriptions (if any)
- Return description (if not None)
- Raises descriptions (if applicable)

**With Parameters and Return Value**:

```python
def sum_nums(a: int, b: int) -> int:
    """
    Sum two numbers.

    :param a: First number.
    :param b: Second number.
    :return: Sum of the two numbers.
    """
    return a + b
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

    :param workgroup_name: Name of the workgroup to run the queries with.
    :param catalog_name: Name of the AWS catalog to use.
    :param profile_name: Name of the credentials profile to use.
    """
    pass
```

**With Raises**:

```python
def download_files(self: Self, bucket_name: str, prefix: str, local_path: str) -> None:
    """
    Download the contents of an S3 key to a local directory.

    :param bucket_name: Name of the bucket to download files from.
    :param prefix: Prefix to download files from.
    :param local_path: Local path to put the files in.
    :raises ValueError: When the local file doesn't exist.
    """
    pass
```

**Simple Functions (No Parameters, Returns None)**:

```python
def some_function() -> None:
    """Brief description of what the function does."""
    pass
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
- **Document all parameters, even obvious ones**
- **Document return values unless returning None**
- **Document exceptions that can be raised**: only the exceptions a function raises with a
  literal `raise` statement in its own body. Don't tag exceptions that merely propagate
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
    """
    Create the client.

    :param workgroup_name: Name of the workgroup to run the queries with.
    """
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

#### Comment Style

- Use `#` for inline comments
- Keep comments concise and developer-friendly
- Avoid AI-generated phrasing

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
- Document default values in docstrings

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

### Linter Configuration

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
    """Test the initialization of the AthenaClient."""
    pass


def test_create_cursor_with_profile() -> None:
    """Test the _create_cursor method when using a profile."""
    pass


def test_run_query_empty() -> None:
    """Test the run_query method with an empty result set."""
    pass
```

#### Test Function Signature

All test functions must:

- Have a return type hint of `-> None`
- Have a docstring
- Not be grouped into classes (use module-level functions)

**Example**:

```python
def test_list_files() -> None:
    """Test listing files in a bucket and prefix."""
    # ... test code
```

### Test Docstrings

#### Simple Test Docstrings

For tests without parameters, use a single-line docstring:

```python
def test_init() -> None:
    """Test the initialization of the AthenaClient."""
    assert True
```

#### Test Docstrings with Fixtures

For tests with fixtures, use Sphinx-style docstrings:

```python
def test_init(athena_client: AthenaClient) -> None:
    """
    Test the initialization of the AthenaClient.

    :param athena_client: The AthenaClient instance to test.
    """
    assert athena_client.workgroup_name == "test_workgroup"
```

### Fixtures

#### Fixture Definition

Use `@pytest.fixture` decorator for reusable test objects:

```python
@pytest.fixture
def athena_client() -> AthenaClient:
    """
    Fixture to create an AthenaClient instance for testing.

    :return: An AthenaClient instance.
    """
    return AthenaClient(workgroup_name="test_workgroup", catalog_name="test_catalog")
```

#### Fixture Usage

Pass fixtures as function parameters:

```python
def test_init(athena_client: AthenaClient) -> None:
    """Test the initialization of the AthenaClient."""
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
    """Test the _create_cursor method."""
    with patch("utils.aws.athena.athena_client.connect") as mock_connect:
        mock_cursor = MagicMock()
        mock_connect.return_value.cursor.return_value = mock_cursor

        # ... test code
```

#### Multiple Patches

For multiple patches, use tuple syntax to avoid deep indentation:

```python
def test_create_cursor_with_profile() -> None:
    """Test the _create_cursor method when using a profile."""
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
    """
    Mock the boto3 make_api_call function.

    :param self: The boto3 client.
    :param operation_name: The name of the operation.
    :param kwarg: The keyword arguments.
    :raises ValueError: If the mock API call is not implemented.
    :return: The response.
    """
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
    """Test listing files in a bucket and prefix."""
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
    """Test the initialization of the AthenaClient."""
    assert athena_client.workgroup_name == "test_workgroup"
    assert athena_client.catalog_name == "test_catalog"
    assert athena_client.profile_name is None
```

#### Testing Exceptions

Use `pytest.raises` for exception testing:

```python
def test_cpc_predictor_with_none_query_text() -> None:
    """Test that ValueError is raised when query_text is None."""
    with pytest.raises(ValueError, match="query_text is None."):
        cpc_predictor(query_text=None)
```

#### Testing Mock Calls

Verify mocks were called correctly:

```python
def test_run_query(athena_client: AthenaClient) -> None:
    """Test the run_query method."""
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
    """Test successful CPC code prediction flow."""
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
    """Test that ValueError is raised when query_text is None."""
    with pytest.raises(ValueError, match="query_text is None."):
        cpc_predictor(query_text=None)


def test_cpc_predictor_with_long_query_text() -> None:
    """Test that ValueError is raised when query_text exceeds 1000 characters."""
    long_query = "a" * 1001
    with pytest.raises(ValueError, match="query_text is too long"):
        cpc_predictor(query_text=long_query)


def test_cpc_predictor_successful_prediction() -> None:
    """Test successful CPC code prediction flow."""
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
    """Test default initialization."""
    pass


def test_init_with_credentials() -> None:
    """Test initialization with credentials."""
    pass


# List operations tests
def test_list_files() -> None:
    """Test listing files."""
    pass


# Download operations tests
def test_download_file() -> None:
    """Test downloading a file."""
    pass


def test_download_files() -> None:
    """Test downloading multiple files."""
    pass


def test_download_files_invalid_path() -> None:
    """Test downloading files with invalid path."""
    pass


# Upload operations tests
def test_upload_file() -> None:
    """Test uploading a file."""
    pass
```

#### Test Independence

Each test should be independent:

- Don't rely on test execution order
- Don't share state between tests
- Clean up any created resources

### Environment Variables

#### Setting Environment Variables in Tests

Set environment variables within the test:

```python
def test_cpc_predictor_successful_prediction() -> None:
    """Test successful CPC code prediction flow."""
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

Define test constants at the module level:

```python
"""Tests for the CPC predictor handler."""

TEST_ACCOUNT = "123456789012"
TEST_MODEL_ID = "global.anthropic.claude-opus-4-5-20251101-v1:0"
```

---

## Summary

### Key Principles

1. **Type everything**: All parameters and return values must have type hints
2. **Document everything**: All modules, classes, and functions must have docstrings
3. **Test everything**: Maintain 95%+ code coverage
4. **Use modern Python**: Native types, union operator, `Self` type hint
5. **Follow the formatters**: Don't fight black, isort, or flake8
6. **Be consistent**: Follow established patterns in the codebase
7. **Be explicit**: Clear names, clear error messages, clear documentation

### Enforcement

These standards are enforced through:

- **black**: Code formatting
- **isort**: Import organization
- **flake8**: Style checking (with plugins for docstrings, commas, multiline containers)
- **mypy**: Type checking
- **pytest**: Testing with 95% coverage requirement

## Self-mutation rule

Maintained by the orchestrating session only — never by a delegated subagent or headless worker,
even one instructed to read this file; a subagent that notices something worth adding reports it
under `Proposed learned pattern:` in its own output. Lessons here are stack-specific and true in
any repo of this stack; repo-specific facts go to that repo's `.claude/rules/`. Append an
imperative bullet under `## Learned patterns` (one sentence, two at most; no date, no repo name, no "added after" tail),
refine near-duplicates in place, keep the section under ~25 entries, and open a PR against the
plugin repository (`ksco92/my-dev-team`).

## Learned patterns

- `typing.Any` is banned (flake8-annotations ANN401); a third-party client gets a `Protocol` with
  exactly the methods used, a JSON payload a recursive alias.
- Docstrings are structure-first: a numbered list of what happens, rationale at most one trailing
  clause per step, deep rationale at the line it justifies or in the PR.
- Prefer a shared boolean primitive (`is_df_empty`) with the raise inlined at the call site over a
  per-job `_guard_x` wrapper; emptiness probes use `take(1)`, never `count()`.
- A constant's comment states purpose in two lines or fewer and annotates the thing it is attached
  to; never alias a shared constant to hang a comment on it; defensive code needs an observed,
  recurring failure class.
- Hardware-resource numbers derive from the current machine at import (`os.cpu_count()`,
  `os.sysconf`) with the ratio as the named constant; server-side limits stay literals.
- DRF binds `THROTTLE_RATES` at first import, so `override_settings` cannot change it; use
  `patch.object(<ThrottleClass>, "THROTTLE_RATES", {...})` as a context manager.
- After bumping the project version in `pyproject.toml`, run `uv lock` and commit `uv.lock` in the
  same commit; verify by grepping the committed file, not the working tree.
- Python 3.14 (PEP 758) accepts `except A, B:` without `as`; it is a readability finding, fixed
  with stacked single-exception clauses, each a branch with its own test. black with a py314
  target rewrites `except (A, B):` into that form, so neither a tuple nor a formatter directive
  is a fix, and a request to collapse two clauses into one is declined on that ground.
- Guard non-finite JSON numerics before a `Decimal` conversion: `json.loads` accepts bare
  `NaN`/`Infinity`.
- A fix that validates each side of a comparison independently at a conversion boundary also
  rejects structurally equal pairs the reference reports as unchanged; test that case and never
  write "strictly safer than the reference" without checking it per input shape.
- A differential test whose oracle is the interpreter (`repr()`, `unicodedata`, `json`) pins the
  interpreter (`.python-version`, `uv python install` in the workflow) and reads the CI log for
  the one `uv sync` picked.
- In a project whose extension is built with `maturin develop`, run tests with `uv run --no-sync`:
  a plain `uv run` re-syncs the environment and reinstalls the package from uv's version-keyed
  build cache, silently replacing the freshly built extension with a stale one, so tests pass or
  fail against code that is not the checkout's.
- When validating a fix on a constrained-stack thread (threading.stack_size()), separate two variables the repro tends to conflate: whether the library's own native operation is safe at that stack size, vs whether the CALLER's own object construction/destruction is safe there — CPython's container deallocation is itself natively recursive and crashes a small-stack thread with zero extension involvement. Isolate by building the deep object on a normal-stack thread and passing it by reference into the constrained one, keeping it alive until after join, so only the call under test and its error/cleanup path run on the small stack.
- A stub or surface "cannot drift" test must parse both sides: `dir(module)` on the runtime side
  and every declared name on the stub side, including module-level `AnnAssign` constants, never a
  literal set. Prove it in both directions: monkeypatch a new symbol onto the module, and delete a
  declaration from a copy of the `.pyi`; each must fail the test.
- When a PR widens which Python types or subclasses a binding accepts, enumerate every conversion
  entry point for the same base type before trusting the PR's own scope list: value converters and
  dict-key or set-member converters are separate paths, and one left on the old exact-type check
  turns a supported input into a crash where the ported tool succeeds.
- When a fix widens dict or set key acceptance to subclasses, test a subclass with a deliberately
  overridden `__eq__`/`__hash__`: the ported tool's key matching runs native Python equality while
  its element matching is a structural walk, so a port that unifies both is right for every
  plain subclass and silently wrong for the overridden one; classify and document that boundary.
- A test module that imports a sibling test module inherits the sibling's module-level
  `importorskip` through the re-raised Skipped during collection: behaviorally right, but its
  skip line merges into the sibling's and the file vanishes from any interpreter-coverage
  accounting. The importing file carries its own explicit guard.
- When a binding widens an accepted type through a slow path, check that the slow path reads the
  value the same way the fast path does: a virtual call (`str()`, `__index__`, `__int__`) on the
  object lets a subclass control the value compared, while the fast path reads the machine
  value; a subclass with a lying override is the probe, on values, keys and set members.
- When a binding converts a host big value through its decimal `str()`/`repr()`, probe the
  host's own conversion limits before accepting an "any magnitude" claim: CPython caps int-to-str
  and str-to-int at 4,300 digits by default, so a text round-trip caps the feature far below its
  advertised range and raises the interpreter's error without the binding's path; the
  byte-oriented accessor is uncapped and cheaper.
- When a PR widens a conversion fallback (custom objects, generic containers), sweep every
  builtin that previously raised through it: a type with nothing for the fallback to enumerate
  (bytes, memoryview, an `__iter__`-only class, a class object) turns a loud refusal into silent
  equality, and the invariant to assert is that nothing that raised before now reports {} for
  two values Python considers unequal.
- When rewriting a Python file by line ranges taken from `ast` line numbers, build the line array
  with `readlines()` or `split("\n")`, never `str.splitlines()`: it also splits on U+2028/U+2029,
  which a string literal can carry, and the array desyncs from the compiler's `\n`-only numbering.
- Measure a file's comment ratio with `tokenize` COMMENT tokens plus docstrings found by AST
  position (the first string statement of a module, class or function); a scan for `#` lines or
  triple quotes counts an embedded script or fixture string as prose.
- With a soft-delete default manager, Django's uniqueness validation and `get_by_natural_key` see
  hidden rows as free while the unique index does not; validate against the all-rows manager in
  `validate_unique`, and give `create_superuser` its own check, since `createsuperuser --noinput`
  runs no model validation and would surface a raw `IntegrityError`.
- DRF answers an anonymous request with 401 or 403 according to the first class in
  `authentication_classes` (`SessionAuthentication` first gives 403); an endpoint that promises
  401 lists a challenge-issuing class first, and tests assert the code they mean. `initial()` runs
  authentication, permissions and throttles before the handler is resolved, so a throttle may skip
  exactly the requests the handler rejects before work (unregistered name, wrong method) without
  opening an uncounted path; check that pairing, not the skip alone.
- A length limit applies to the value that is persisted: lower-casing can lengthen a string
  (`İ` becomes two code points), so a 254-character email passes the raw check and overflows the
  column after normalisation; the rejection fixture lands exactly one unit over the limit.
- Middleware that stores request or response text decodes and parses bytes exactly as the
  consuming parser does (`request.encoding` for the body, the query string and `parse_qsl`
  percent-escapes; `response.charset` for the response) or stores a placeholder; Django accepts
  any charset `codecs.lookup` resolves, including `base64`, `quopri`, `idna` and `undefined`,
  and a lone-surrogate JSON escape survives a `json` round trip and raises at `.encode()`.
  Under `DEBUG=True` it placeholders every non-JSON error body: `technical_500_response` also
  serves a bad `Host` at status 400 with `POST` fields unfiltered, as `text/html` unless the
  `Accept` header prefers `text/plain`.
- A redactor over text a downstream tokenizer splits (form fields at `&` and `=`) cannot redact by
  key once a secret spans a split: store a placeholder for any field that opens as JSON (`{`, `[`
  or `"` after a byte-order mark and JSON whitespace) but does not parse, and for a body declared
  or opening as JSON that fails to parse or is too deep, never the raw scrubbed text. Parse JSON
  found inside JSON strings and inside object keys the same way, recursively; clients encode twice.
- Match a secret-key name on the key as received, as stored, and on each decoded layer of a
  JSON-string key: re-serialisation keeps quotes so an anchored name never matches the stored
  spelling, and parsing can delete text (duplicate keys collapse) so the received spelling stays;
  redact the value whenever the stored key gained a placeholder. Charge every re-serialised string
  to one budget shared across the request, checked at every level: nested escapes grow output
  geometrically, and decode depth is set by the escape the attacker chooses, not the encoder.
- A limit enforced in `INSERT ... ON CONFLICT DO UPDATE ... WHERE count < limit` never applies to the
  fresh insert, so a limit of zero still admits one request; refuse limits below 1 where the class is
  defined, and drive 0, a negative and an oversized value end to end.
- A soft-delete manager declared as `objects` does not make `Model._base_manager` soft-deleting:
  unless `Meta.base_manager_name` is set it is Django's plain `Manager`, whose queryset `delete()`
  issues a real `DELETE`, so a purge needs no raw SQL; verify by printing the manager's class.
