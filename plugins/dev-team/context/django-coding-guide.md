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
