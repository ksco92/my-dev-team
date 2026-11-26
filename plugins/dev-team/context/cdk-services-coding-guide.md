# CDK Service Constructs Guide

Learned patterns on how AWS services behave behind their CDK constructs: Glue jobs, Data Quality and
Iceberg tables, Lake Formation, CloudTrail, CloudFront, Step Functions and EventBridge S3 events.
Read with `cdk-coding-guide.md`, which holds the CDK standards and the toolchain, synth, deploy and
template-test lessons; its self-mutation rule governs this file, with the same ~25-entry budget.

## Learned patterns

- When an Iceberg table construct takes explicit top-level column ids and allocates nested ids by
  counter, pin only top-level ids and verify nested ones by synth. A partition field id (≥ 1000) is
  unique across the table's whole spec history: an untouched field keeps its id, any change makes a
  new field with a never-used id.
- Glue `UpdateTable` reuses a history schema whose fields match and keeps its identifier-field-ids,
  so an identifier-only change is dropped; a construct carries the ids by changing the key columns'
  docs too (a `(PK) ` doc marker). A partition change of the field id alone is a no-op (a new
  transform is applied), and a V2 to V3 `formatVersion` change updates the `format-version` property
  while the metadata stays 2.
- A construct that promises files stay under one location rejects the Iceberg properties that
  relocate data or metadata (`write.*.path`, `write.location-provider.impl`).
- The `aws-cloudtrail` L2 `Trail` with a customer-managed key does not grant the CloudTrail service
  principal on the key, and the two statements it adds to a passed-in bucket carry no
  `aws:SourceArn`; add the KMS grant yourself with a `formatArn`-built trail ARN (not
  `trail.trailArn`, which cycles) plus a bucket Deny for that principal when `aws:SourceArn` is not
  that ARN, and assert both in template tests.
- A `Trail` with `managementEvents: ALL` plus `logAllS3DataEvents()` and `logAllLambdaDataEvents()`
  deploys as three selectors; pin the synthesized selectors with `Match.exact`, since the data
  selectors leave `IncludeManagementEvents` unset while the live API reports it `true`.
- Register Lake Formation locations with a user-defined role trusting `lakeformation.amazonaws.com`
  for `sts:AssumeRole` and `sts:SetContext`, never the service-linked role: Lake Formation vends
  external engines (Glue Data Quality, EMR) no credentials from a service-linked registration, so
  their `GetDataAccess` answers `Access is not allowed.` whatever the grants or data-lake settings
  while Athena still passes. Write the role's own policy explicitly (object get, put and delete,
  `s3:ListBucket`, `kms:Decrypt` and `kms:GenerateDataKey*` on the bucket key), never
  `grantReadWrite`, which adds `DeleteObjectVersion` and retention actions, and check the
  registration role before turning on a data-lake setting to cure a denial.
- Lake Formation-only access needs `hybridAccessEnabled: false` on the registration and no
  `IAM_ALLOWED_PRINCIPALS` grant on the construct's databases and tables: an empty
  `CreateTableDefaultPermissions` on each database, asserted in a template test, and an empty
  `CreateDatabaseDefaultPermissions` in the account's `DataLakeSettings`, which is a deployment
  precondition proved by a read-only `list-permissions` on the database, not by a template test.
- Lake Formation gives the principal that creates a table (the CloudFormation execution role) its
  own permissions on it, so a "no grant to the execution role" criterion is judged on the templates,
  never on `list-permissions`.
- Lake Formation admin status grants no `CREATE_TABLE` on a database, so an engine's `CREATE TABLE`
  through the Glue catalog fails with `Required Create Table on <database>` even for an admin
  principal; create integration tables through the construct's own stack and grant the test
  principal on them.
- CloudFront `ResponseHeadersPolicy` keeps one value per header name; merge a new directive into an
  existing custom header's value, grep the stack for an existing policy before creating one, and
  emit `X-XSS-Protection: 0` (`protection: false`), never `1; mode=block`.
- Lake Formation caps LF-tag keys and values at 50 characters and compares both ignoring case,
  whatever the API reference's limits say; validate keys and values at 50 and reject values that
  differ only in case.
- A Data Catalog `ReferentialIntegrity` rule counts a NULL local value as missing and accepts no
  `where` clause; an optional column needs a `CustomSql` anti-join instead.
- A Data Catalog `ReferentialIntegrity` rule written `"<db>.<table>.<col>"` needs no
  `AdditionalDataSources`; an `AdditionalDataSources` key may not contain `.` or `-`, and
  `CustomSql` reads a reference table only through such a key. Every identifier interpolated into
  DQDL or `CustomSql` text passes an allow-list at synth (`^[a-z0-9_]+$` for Glue database and table
  names, `^[A-Za-z0-9_]+$` for columns); never quote-escape.
- A Glue job's `Code.fromAsset` takes one file; ship a folder as an `Asset` with a `.py`-only
  exclude list under `ignoreMode: IgnoreMode.GIT` (a negated pattern stages nothing in the default
  glob mode) and `Code.fromBucket`, with an `__init__.py` in every package folder, because the CDK
  CLI zips files only and `zipimport` before Python 3.14 finds no namespace package without
  directory entries. Validate such a folder at synth with `readdirSync` exact-name regular-file
  matches and `lstatSync` symlink rejection: `existsSync` passes a case variant and a directory on
  macOS, and a name-based exclude is escaped by glob characters in a link name.
- A Data Quality evaluation run started from a job needs `glue:GetPartitions` on the target table,
  `glue:PublishDataQuality` and `kms:Decrypt` on the catalog key besides the ruleset actions; write
  the job role's policy explicitly, since `AWSGlueServiceRole` grants `glue:*` on every resource.
- A Step Functions `Choice` rule that compares a field the input may omit pairs the comparison with
  an `IsPresent` check in an `And`
  (`Condition.and(Condition.isPresent(path), Condition.stringEquals(path, value))`): a bare
  comparison on a missing path fails the execution with `States.Runtime` instead of taking
  `Default`, and `aws stepfunctions test-state` with the state inline shows it without a deploy.
- Parse the `Cause` of a failed Step Functions `glue:startJobRun.sync` task as the `JobRun` object
  itself, with `JobRunState` and `ErrorMessage` at the top level and no wrapper key, and keep any
  other `Cause` as text: a job that never starts fails with a `Glue.*` error and a plain-text
  `Cause`.
- Read the object key of an EventBridge S3 `Object Created` event as it arrives, without URL
  decoding: EventBridge delivers the key raw, with a `:` as a `:`, where an S3 bucket notification
  URL-encodes it.
- Glue `GetJobRun` returns in `Arguments` only what the caller of the run set; read a job default
  from `GetJob` `DefaultArguments` or from the driver's launch line, never from the run record.
- When a value is interpolated inside quotes of a target grammar (such as DQDL `QUOTED_STRING`,
  `ESC: '\\"' | '\\\\'`), check the grammar's escape rules as well as its quote character: rejecting
  `"` alone lets a trailing `\` swallow the closing quote.
- When building an AWS service hostname from a region id, check the partitions it admits (`cn-*`
  regions use `.com.cn`) and compare against sibling URLs in the same flow.
