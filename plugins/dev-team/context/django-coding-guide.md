# Django Coding Guide

Standards for Django and Django REST Framework services on PostgreSQL. Read with
`python-coding-guide.md`, which holds the language-level rules; this file holds only what is true
because the framework is Django. Binding for any repo where Django is written unless the repo's own
CLAUDE.md overrides.

---

## 1. Managers and Soft Delete

- With a soft-delete default manager, Django's uniqueness validation, `get_by_natural_key` and any
  `objects.filter(...).exists()` check see hidden rows as free while the unique index does not. An
  existence check that guards a unique column runs on the all-rows manager; `validate_unique`
  validates against it; `create_superuser` gets its own check, since `createsuperuser --noinput`
  runs no model validation and would surface a raw `IntegrityError`.
- A soft-delete manager declared as `objects` does not make `Model._base_manager` soft-deleting:
  unless `Meta.base_manager_name` is set it is Django's plain `Manager`, whose queryset `delete()`
  issues a real `DELETE`, so a purge needs no raw SQL. Verify by printing the manager's class.
- Guards in `save()` and the default queryset's `update()` are bypassed by any write not through the
  model's `save()` or its default querysets (`bulk_create`, `bulk_update`, which reaches the
  queryset's `update()` only with `Case`/`When` expressions a value check cannot evaluate, a reverse
  `RelatedManager.add()` through `_base_manager`, `save_base()`, deserialization, a hand-built
  `QuerySet`), so `base_manager_name` names the guarded manager and the remaining unguarded set is
  stated as that class, never as a list.
- A `ModelAdmin` that overrides `has_add_permission` but not `has_delete_permission` still lets
  staff reach the delete action, which soft-deletes through the model. A claim that "nothing
  deletes X today" is checked against the admin as well as the application code.

## 2. Authentication, Permissions and Throttles

- DRF answers an anonymous request with 401 or 403 according to the first class in
  `authentication_classes` (`SessionAuthentication` first gives 403). An endpoint that promises 401
  lists a challenge-issuing class first, and tests assert the code they mean.
- `initial()` runs authentication, permissions and throttles before the handler is resolved, so a
  throttle may skip exactly the requests the handler rejects before doing work (unregistered name,
  wrong method) without opening an uncounted path. Check that pairing, not the skip alone.
- The same order holds inside the handler: decide an authorization refusal before calling a
  `get_or_create` resolver, and have the 403 test assert the row count of every table it touches.
- DRF binds `THROTTLE_RATES` at first import, so `override_settings` cannot change it; use
  `patch.object(<ThrottleClass>, "THROTTLE_RATES", {...})` as a context manager.

## 3. Limits Enforced in SQL

- A limit enforced in `INSERT ... ON CONFLICT DO UPDATE ... WHERE count < limit` never applies to
  the fresh insert, so a limit of zero still admits one request. Refuse limits below 1 where the
  class is defined, and drive 0, a negative and an oversized value end to end.
- Bound an accumulated numeric column inside the same conditional UPDATE that moves it and raise a
  typed error on zero rows; a per-call `max_digits` check passes while the running total overflows
  into a `DataError` 500. Test at the ceiling with two back-to-back calls and with threads behind a
  barrier.

## 4. Persisted Values

- A length limit applies to the value that is persisted: lower-casing can lengthen a string (`İ`
  becomes two code points), so a 254-character email passes the raw check and overflows the column
  after normalisation. The rejection fixture lands exactly one unit over the limit.

## 5. Request and Response Text

- Middleware that stores request or response text decodes and parses bytes exactly as the
  consuming parser does (`request.encoding` for the body, the query string and `parse_qsl`
  percent-escapes; `response.charset` for the response) or stores a placeholder. Django accepts
  any charset `codecs.lookup` resolves, including `base64`, `quopri`, `idna` and `undefined`, and
  a lone-surrogate JSON escape survives a `json` round trip and raises at `.encode()`.
- Under `DEBUG=True` such middleware placeholders every non-JSON error body:
  `technical_500_response` also serves a bad `Host` at status 400 with `POST` fields unfiltered, as
  `text/html` unless the `Accept` header prefers `text/plain`.
- A redactor over text a downstream tokenizer splits (form fields at `&` and `=`) cannot redact by
  key once a secret spans a split: store a placeholder for any field that opens as JSON (`{`, `[`
  or `"` after a byte-order mark and JSON whitespace) but does not parse, and for a body declared
  or opening as JSON that fails to parse or is too deep, never the raw scrubbed text. Parse JSON
  found inside JSON strings and inside object keys the same way, recursively; clients encode
  twice.
- Match a secret-key name on the key as received, as stored, and on each decoded layer of a
  JSON-string key: re-serialisation keeps quotes so an anchored name never matches the stored
  spelling, and parsing can delete text (duplicate keys collapse) so the received spelling stays.
  Redact the value whenever the stored key gained a placeholder.
- Charge every re-serialised string to one budget shared across the request, checked at every
  level: nested escapes grow output geometrically, and decode depth is set by the escape the
  attacker chooses, not the encoder.

## 6. Management Commands

- `call_command` never turns a `CommandError` into an exit code, so a test through it proves the
  message, not the contract. Verify a command's refusal once through the real CLI
  (`manage.py <command> ...`): non-zero exit, message on stderr, nothing on stdout.

## Self-mutation rule

Maintained by the orchestrating session only, never by a delegated subagent or headless worker,
even one instructed to read this file; a subagent that notices something worth adding reports it
under `Proposed learned pattern:` in its own output. Lessons here are true in any Django repo;
repo-specific facts go to that repo's `.claude/rules/`. Append an imperative bullet under
`## Learned patterns` (one sentence, two at most; no date, no repo name, no "added after" tail),
refine near-duplicates in place, keep the section under ~25 entries, promote a lesson that matures
into a convention to a numbered section above, and open a PR against the plugin repository
(`ksco92/my-dev-team`).

## Learned patterns

- Prove a `transaction.atomic()` block by mutating it to `if True:` and running the suite: a
  threaded lost-update test passes on that mutant, so a rollback needs its own test that patches the
  dependent insert to raise and asserts the first write is undone.
- A guard behind `if not self._state.adding` in `save()` never fires for a fresh instance built with
  a stored pk, because Django tries an UPDATE first; pass `force_insert=True` when adding so a
  reused pk raises `IntegrityError`.
- A conditional `F()` update that feeds a dependent insert checks that it touched exactly one row
  inside the transaction; a zero-row update on a filtered-out row otherwise commits the insert
  alone.
- On Postgres, Django writes a `Decimal` unrounded and the column's `numeric(p, s)` coercion is the
  only rounding, so a guard justified by the ORM and the database rounding differently is false; the
  real divergence is the unrounded value left on the returned instance. Write the value through both
  paths before accepting a rounding rationale.
- DRF renders the body after the view returns, so a side effect placed after building the `Response`
  (a charge, a counter) commits before a render failure turns the call into a 500. Render inside the
  view first, as `finalize_response` then `response.render()`, which dispatch's second
  `finalize_response` leaves idempotent.
- An assertion that response header names are unique is vacuous: `HttpResponse.headers` is a
  case-insensitive mapping, so `serialize_headers()` cannot repeat a name.
- DRF's `JSONEncoder` turns a bare `Decimal` into a float; a fixed-point string in a response goes
  through a serializer `DecimalField` or `str()`.
- To assert that a DRF view answers 500 (status, headers, absence of a side effect), drive the real
  URL with `APIClient(raise_request_exception=False)`; `View.as_view()` called on an
  `APIRequestFactory` request re-raises the uncaught exception instead of rendering the 500.
- A rollback test asserts inside the injected failure, before it raises, that the earlier write
  exists; one that only checks absence afterwards still passes with the write moved after the
  injection point.
- A lock that serialises a rule check is mutated for position (below each lookup it protects) as
  well as for presence, and each lookup read under it gets its own waits-on-the-lock case.
- Prove a row lock deterministically: the test thread holds it in its own transaction, sends each
  request from a thread, polls `pg_locks` after `pg_stat_clear_snapshot()` until the request is
  waiting, then releases. Build every authenticated client before taking the lock, because a
  test-client login writes the user row.
- A handler authorised by a permission class that then takes a lock re-reads the caller's
  authorisation under that lock, and each clause of the re-check (tenant, role, active) has a test
  driven from the lock holder's transaction.
- Lock a parent row with `select_for_update(no_key=True)` when concurrent transactions insert
  children that reference it; plain `FOR UPDATE` conflicts with the `FOR KEY SHARE` of their
  foreign-key checks and deadlocks once the locker waits on a row they hold.
- A handler reads an object once and carries it forward; re-reading it through a differently
  filtered query after a write lets the second read's 404 mask a filter missing from the first.
- Composing DRF permissions with a method-only operand (`X | ReadOnly`) keeps `IsAuthenticated` as
  its own earlier entry, since the OR replaces the default and an anonymous safe request passes
  `ReadOnly`; test OPTIONS and HEAD for every caller class.
- `ModelSerializer.update()` calls a full `instance.save()`, which rewrites every column from the
  instance read at the start of the request and undoes a concurrent write such as a soft delete;
  override it to save with `update_fields`.
- DRF's `BooleanField` reads a key missing from a form or multipart body as False even when
  required; a role or flag endpoint sets `default_empty_html = empty` on the field and tests a form
  body without it.
- An invariant enforced only in `save()` (two foreign keys sharing a tenant) is broken by any admin
  form that leaves one of those keys editable on an existing row; make it read-only on change with
  `get_readonly_fields` and prove it with a crafted change POST.
- A uniqueness check written as `exists()` then insert races: back it with a constraint, map the
  `IntegrityError` to the same 400, and probe the race through a live server, since the test client
  re-raises in-thread and hides the 500.
- Documenting an endpoint's answers by hand, send one request for each answer DRF and Django give
  around the view: the 415 for an unsupported `Content-Type` and the `detail` 400 for a body that
  does not parse (both counted by a throttle), the 406 answered before authentication, and Django's
  own HTML 400 for a body over `DATA_UPLOAD_MAX_MEMORY_SIZE`; then state the documented statuses as
  a closed list.
- With drf-spectacular, derive tags, summaries and descriptions in one `AutoSchema` subclass set as
  `DEFAULT_SCHEMA_CLASS`, in a module that imports no view, rather than per-view decorator arguments
  or a postprocessing hook; an `@api_view` function's docstring is on the view class, not the
  handler method.
- A schema generator publishes docstrings (a view's as summary and description, a serializer's as
  its component description): review every published string from the generated document, and write
  those docstrings as the contract a customer reads, never the mechanism.
