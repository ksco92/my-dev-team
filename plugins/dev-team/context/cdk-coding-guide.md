# CDK Coding Guide

Standards and rules for the Psyduck CDK infrastructure project.

---

## 1. General Coding Standards

### 1.1 TypeScript

- **Strict mode enabled.** `noImplicitAny`, `strictNullChecks`, `noImplicitReturns`.
- **Target:** ES2020 with CommonJS modules.
- **No unused variables** unless prefixed with `_`.

### 1.2 Indentation and Formatting

- **4-space indentation.** No tabs.
- **Single quotes** for strings. Template literals allowed for interpolation.
- **Trailing commas** on multiline arrays, objects, imports, and exports.
- **Each element on its own line** when an array or object has one or more items.
- **Each property on its own line** in object literals.
- **Quote object keys only when necessary** (as-needed).

### 1.3 Imports

- Each named import on its own line within the braces (enforced by `object-curly-newline`).
- Group imports: CDK core → CDK service modules → local configs → local utils.
- Use default imports for utility functions (`import createKey from ...`).
- Use named imports for CDK constructs (`import { Vpc } from ...`).

### 1.4 Documentation

- JSDoc comments on exported utility functions with `@param` tags, sized to the budget in
  `${CLAUDE_PLUGIN_ROOT}/context/agent-baseline.md` (Comment, docstring, and helper budget).
- Inline section comments using `///` separators for visual grouping in stack files.

---

## 2. Infrastructure Rules

### 2.1 Encryption (Everything Must Be Encrypted)

- **RDS:** KMS-encrypted storage + KMS-encrypted secrets + KMS-encrypted Performance Insights.
- **S3 (data buckets):** KMS encryption via `createKey()`. Each bucket gets its own KMS key.
- **S3 (logging buckets):** S3-managed encryption (KMS not needed for log destinations).
- **VPC Flow Logs:** Encrypted CloudWatch Log Group with KMS key.
- **KMS keys:** Always enable key rotation (`enableKeyRotation: true`).
- **Secrets Manager:** Encrypted with dedicated KMS key. Daily rotation.
- **CloudFront:** TLS 1.2 minimum (`SecurityPolicyProtocol.TLS_V1_2_2021`).

### 2.2 Network Architecture

- **VPC:** 10.0.0.0/16 CIDR across exactly 3 Availability Zones.
- **Subnet types:** `PRIVATE_WITH_EGRESS` for compute/data, `PUBLIC` for load balancers and NAT.
- **Compute instances in private subnets only.** RDS, EB EC2 instances, and Lambda functions
  must always be placed in private subnets.
- **Load balancers in public subnets.** The EB Application Load Balancer and the RDS Network
  Load Balancer are internet-facing and placed in public subnets.
- **NAT:** Use NAT instance (`NatProvider.instanceV2`) for cost efficiency in dev. Consider
  NAT Gateway for production high availability.
- **VPC Endpoints:** Always create a Secrets Manager VPC endpoint in private subnets.
- **VPC Flow Logs:** All traffic logged to CloudWatch with 1-year retention.

### 2.3 Principle of Least Privilege (POLP)

- **IAM roles:** Only attach the minimum managed policies needed.
  EB EC2 role gets `AWSElasticBeanstalkWebTier` + `AWSElasticBeanstalkWorkerTier` only.
- **Secret access:** Only the EB role and the rotation Lambda can read the RDS secret.
- **S3 access:** Block all public access (`BlockPublicAccess.BLOCK_ALL`).
  CloudFront uses Origin Access Control (OAC), not public bucket policies.
- **Security groups:** Explicit ingress rules only. No broad `0.0.0.0/0` except:
  - EB ALB on 443 (HTTPS from internet)
  - RDS NLB on 5432 (developer DB access)
- **IMDSv2:** Always disable IMDSv1 on EC2 instances (`DisableIMDSv1: true`).

### 2.4 Removal Policies

- **Dev/Local:** `RemovalPolicy.DESTROY` with `autoDeleteObjects: true` on S3 buckets.
- **Prod:** `RemovalPolicy.RETAIN` — never auto-delete production data.
- Use the `getRemovalPolicy()` utility consistently; never hardcode removal policies.

### 2.5 S3 Bucket Standards

- All buckets created via `createBucket()` utility for consistency.
- **Versioning:** Always enabled.
- **Metrics:** Always configured with bucket prefix.
- **Logging:** Data buckets log to the server access logs bucket.
- **Ownership:** `BUCKET_OWNER_ENFORCED` for data buckets, `OBJECT_WRITER` for logging buckets.

### 2.6 Elastic Beanstalk

- **Environment type:** Application Load Balancer (not Classic).
- **EC2 instances in private subnets.** ALB in public subnets.
- **HTTPS-only:** Default listener (port 80) disabled. HTTPS listener (port 443) enabled.
- **Health check:** Always configure `HealthCheckPath` (e.g., `/health_check/`).
- **Root volume:** gp3 storage type.
- **Access logs:** ALB access logs to S3.

### 2.7 RDS

- **Engine:** PostgreSQL (latest stable version).
- **Private subnets only.** Never publicly accessible.
- **Monitoring:** Enhanced monitoring (1-min interval), Performance Insights (3-month retention),
  CloudWatch log exports for PostgreSQL logs.
- **Credentials:** Generated secret with daily rotation via hosted Lambda.
- **IAM authentication:** Enabled.
- **Storage:** gp3 with KMS encryption.

### 2.8 CloudFront

- **Origin Access Control (OAC)** for S3 origins.
- **TLS 1.2 minimum** (`TLSv1.2_2021`).
- **HTTP → HTTPS redirect** on all behaviors.
- **SPA routing:** 404 → `/index.html` with 200 status and 0 TTL.
- **Access logs** to S3 with `cloudfront-logs/` prefix.

### 2.9 Route53

- Use the existing public hosted zone (imported by ID).
- **CNAME records** for EB and NLB endpoints.
- **A record (alias)** for CloudFront distribution on the root domain.

### 2.10 Monitoring

- CloudWatch dashboard per stage with metrics for all core services.
- RDS: CPU, free storage, free memory.
- ELB: Request count, 4xx/5xx errors, response time percentiles.
- CloudFront: Request count, error rates.

---

## 3. Project Structure

### 3.1 Directory Layout

```
psyduck_cdk/
├── bin/                   # CDK app entry point
├── lib/                   # Stack definitions and utilities
│   ├── configs/           # Stage-aware configuration objects
│   └── utils/aws/         # Reusable CDK construct factories
├── test/                  # Jest tests (mirrors lib/ structure)
├── cdk.json               # CDK app config and feature flags
├── package.json
├── tsconfig.json
├── jest.config.js
└── eslint.config.mjs
```

### 3.2 Naming Conventions

- **Stacks:** `PascalCaseStack` (e.g., `PsyduckStack`, `MonitoringStack`).
- **Construct IDs:** PascalCase, descriptive (e.g., `RDSSecurityGroup`, `ACMCertificate`).
- **Config files:** kebab-case (e.g., `general-configs.ts`, `rds-configs.ts`).
  Exception: `ebConfigs.ts` (legacy naming).
- **Utility functions:** camelCase (e.g., `createKey`, `createBucket`, `createVpc`).
- **Resource names:** Include stage suffix (e.g., `RDSNLB-dev`, `EBSecurityGroup-prod`).

### 3.3 Configuration Pattern

- All stage-dependent values live in `lib/configs/`.
- Configs are plain objects keyed by stage name (`dev`, `prod`).
- `general-configs.ts` reads `STAGE` from env vars at module load time.
- Never hardcode stage-specific values in stack files.

### 3.4 Utility Pattern

- Reusable construct factories in `lib/utils/aws/<service>/`.
- Each utility is a default-exported function that takes `scope` and config params.
- Utilities apply security defaults (encryption, removal policy, logging).
- Stack files consume utilities; they don't create raw constructs for common patterns.

---

## 4. Testing Standards

### 4.1 Framework

- **Jest 29** with **ts-jest** transform.
- **CDK assertions:** `Template.fromStack()`, `hasResourceProperties()`, `resourceCountIs()`.
- **Coverage threshold:** 95% (statements, branches, functions, lines).
- **Coverage scope:** `lib/**/*.ts` only (excludes `bin/` entry point).

### 4.2 Test Organization

- Tests mirror the `lib/` directory structure under `test/`.
- Stack tests: one `describe` block per resource group (RDS, EB, Frontend, etc.).
- Utility tests: test each function in isolation with a minimal stack.
- Config tests: verify both dev and prod paths using `jest.resetModules()`.

### 4.3 Test Patterns

```typescript
// Stack test pattern
describe('PsyduckStack', () => {
    let template: Template;

    beforeAll(() => {
        const app = new App();
        const stack = new PsyduckStack(app, 'TestStack', { env: { region: 'us-east-1' } });
        template = Template.fromStack(stack);
    });

    it('creates an RDS instance', () => {
        template.hasResourceProperties('AWS::RDS::DBInstance', {
            Engine: 'postgres',
        });
    });
});

// Utility test pattern
it('creates a KMS key with rotation', () => {
    const app = new App();
    const stack = new Stack(app, 'TestStack');
    createKey(stack, 'TestAlias');

    const template = Template.fromStack(stack);
    template.hasResourceProperties('AWS::KMS::Key', {
        EnableKeyRotation: true,
    });
});

// Config test pattern (module reload for env var changes)
afterEach(() => {
    process.env = { ...originalEnv };
    jest.resetModules();
});
```

---

## 5. Linter Configuration

### 5.1 ESLint Rules

| Rule | Setting |
|---|---|
| `indent` | 4 spaces |
| `quotes` | Single (template literals allowed) |
| `comma-dangle` | Always multiline |
| `array-bracket-newline` | Multiline, minItems: 1 |
| `array-element-newline` | Multiline, minItems: 1 |
| `object-curly-newline` | Multiline, minProperties: 1 |
| `object-property-newline` | Always (no same-line) |
| `quote-props` | As needed |
| `@typescript-eslint/no-unused-vars` | Error (except `_` prefixed) |

### 5.2 Running the Linter

```bash
npm run lint
```

This runs ESLint with `--fix` on `lib/`, `bin/`, and `test/` directories.

---

## 6. Deployment

### 6.1 Infrastructure Deployment

```bash
# Set stage
export STAGE=dev  # or prod

# Synthesize
npx cdk synth

# Deploy
npx cdk deploy --all --require-approval=never
```

### 6.2 Application Deployment (CI/CD)

CDK deploys infrastructure only. Application code is deployed separately:

- **Backend:** `eb deploy` or CodePipeline to the EB environment
- **Frontend:** `aws s3 sync build/ s3://psyduckui-{stage}/` + CloudFront invalidation
- **Infrastructure:** `cdk deploy` via CodePipeline CDK step

### 6.3 Stage Configuration

| Stage | Domain | Removal Policy |
|---|---|---|
| `dev` / `local` | `dev.allershare.com` | DESTROY |
| `prod` | `allershare.com` | RETAIN |

---

## 7. Reference Tooling Setup (copy from arceus / eevee)

When starting a new CDK or TypeScript repo, copy the tooling from these reference repos rather than
re-deriving it. **arceus** is the CDK reference; **eevee** is the general TypeScript reference (same
toolchain, non-CDK). The live files are the source of truth — read them and copy.

- **arceus** — CDK L2 construct, npm package `cdk-glue-iceberg-table`: <https://github.com/ksco92/arceus>
- **eevee** — TS validator + CLI, npm package `flexdataset` (package in `packages/core`):
  <https://github.com/ksco92/eevee>

### 7.1 Files to copy

- **ESLint flat config** (`eslint.config.js`) — ESLint 9 flat config: base JS recommended +
  `@typescript-eslint` recommended + `eslint-plugin-jest` for `*.test.ts`. Key rules: `indent` 4 with
  `SwitchCase: 1`, single quotes, `comma-dangle: always-multiline`, `array-bracket-newline` minItems 1,
  `array-element-newline` minItems 2, `object-curly-newline` minProperties 1, `object-property-newline`.
  Lint script: `eslint . --ext .ts,.tsx --report-unused-disable-directives --max-warnings=0 --fix
  --ignore-pattern '**/*.d.ts'`. (arceus `eslint.config.js`; eevee `packages/core/eslint.config.js`.)
- **TypeScript config** (`tsconfig.json` + `tsconfig.build.json`) — `target ES2022`,
  `module`/`moduleResolution` `NodeNext`, `strict`, `declaration`, `inlineSourceMap`. A separate
  `tsconfig.build.json` extends it with `outDir: dist`. **Gotcha:** to stop a bare `tsc` from emitting
  stray `.js`/`.d.ts` next to sources (which then shadow the `.ts` under ts-jest and silently run stale
  code), set `"noEmit": true` in the base `tsconfig.json` and `"noEmit": false` only in
  `tsconfig.build.json` (see eevee). Build only via `npm run build`, never a bare `tsc`.
- **Jest** (`jest.config.js`) — `ts-jest`, `roots: [test]`, `testMatch: ['**/*.test.ts']`,
  `collectCoverageFrom` over `lib/**/*.ts` (or `src/**/*.ts`), reporters including `lcov` for Codecov,
  and a `coverageThreshold` of 95% on statements / branches / functions / lines.
- **package.json scripts** — `build` (`tsc -p tsconfig.build.json`), `lint`, `test` (`jest`), `clean`,
  `dev`, and `prepublishOnly` (`build && test`).

### 7.2 CI/CD

Badges, the CI workflow, the npm publish workflow (OIDC trusted publishing, version-guarded on `main`),
and the version-bump-per-PR rule are in [`npm-publishing-pattern.md`](npm-publishing-pattern.md). Copy
`ci.yml` and `publish.yml` from arceus (single package) or eevee (monorepo — note the package
`working-directory`). A CDK construct repo (like arceus) may also keep an integration-test workflow that
runs a real `cdk deploy`; that is CDK-specific and gated, separate from this base.

## Self-mutation rule

Maintained by the orchestrating session only, never by a delegated subagent or headless worker,
even one instructed to read this file; a subagent that notices something worth adding reports it
under `Proposed learned pattern:` in its own output. Lessons here are stack-specific and true in
any repo of this stack; repo-specific facts go to that repo's `.claude/rules/`. Append an
imperative bullet under `## Learned patterns` (one sentence, two at most; no date, no repo name, no "added after" tail),
refine near-duplicates in place, keep the section under ~25 entries, and open a PR against the
plugin repository (`ksco92/my-dev-team`).

## Learned patterns

- Region-qualify globally unique resource names (S3 `bucketName`) with `${this.region}` whenever a
  stack may deploy to more than one region or share an account with a sibling using the same
  `name-${account}` pattern.
- A caret range on an `@aws-cdk/aws-*-alpha` prerelease only matches the same `major.minor.patch`
  tuple; pin the alpha to the construct's exact alpha line, let stable `aws-cdk-lib` float, and
  install all three in one `npm install`; a consumer of a library that peers on the alpha settles
  the same pin with an `npm install` in a temp dir before the slice is written. Before raising an
  alpha floor, run
  `npm view <pkg>@<version> stability` across the bump range; a `stability` of `deprecated` means
  the module graduated into `aws-cdk-lib`.
- When swapping an alpha L2 for its stable counterpart, diff the constructors' defaults as well as
  the typings by synthesizing both against the base; a stable promotion can flip a default (a
  removal policy gaining RETAIN) on a fixed-name resource that destroy-then-redeploy then trips
  over.
- `cdk-glue-iceberg-table` ≥ 0.5.0 requires explicit top-level `IcebergColumn.id` and allocates
  nested ids by counter; pin only top-level ids and verify nested ones by synth. ≥ 0.6.0 also
  requires `IcebergPartitionField.fieldId` (≥ 1000), unique across the table's whole spec history:
  an untouched field keeps its id, any change makes a new field with a never-used id.
- A construct that promises files stay under one location rejects the Iceberg properties that
  relocate data or metadata (`write.*.path`, `write.location-provider.impl`).
- A CloudWatch `Dashboard` body is an `Fn::Join` with region tokens and L2 dimensions render as
  `Ref`s; in template tests join the parts with a placeholder for intrinsics, parse, and assert
  dimension keys, not values. Glue catalog objects and LakeFormation permissions are not taggable;
  `Tags.of()` skips them silently.
- The `aws-cloudtrail` L2 `Trail` with a customer-managed key does not grant the CloudTrail service
  principal on the key, and the two statements it adds to a passed-in bucket carry no
  `aws:SourceArn`; add the KMS grant yourself with a `formatArn`-built trail ARN (not
  `trail.trailArn`, which cycles) plus a bucket Deny for that principal when `aws:SourceArn` is not
  that ARN, and assert both in template tests.
- A `Trail` with `managementEvents: ALL` plus `logAllS3DataEvents()` and `logAllLambdaDataEvents()`
  deploys as three selectors; pin the synthesized selectors with `Match.exact`, since the data
  selectors leave `IncludeManagementEvents` unset while the live API reports it `true`.
- Registering an S3 location with the Lake Formation service-linked role makes Lake Formation add
  the S3 actions to that role's own inline policy (`LakeFormationDataAccessPolicyForS3`); grant the
  role only `kms:Decrypt` and `kms:GenerateDataKey*` on the bucket key, no bucket-policy statement
  (`grantReadWrite` adds `DeleteObjectVersion` and retention actions) and no `aws:SourceArn`.
- Lake Formation-only access needs `hybridAccessEnabled: false` on the registration and no
  `IAM_ALLOWED_PRINCIPALS` grant on the construct's databases and tables: an empty
  `CreateTableDefaultPermissions` on each database, asserted in a template test, and an empty
  `CreateDatabaseDefaultPermissions` in the account's `DataLakeSettings`, which is a deployment
  precondition proved by a read-only `list-permissions` on the database, not by a template test.
- Lake Formation gives the principal that creates a table (the CloudFormation execution role) its
  own permissions on it, so a "no grant to the execution role" criterion is judged on the templates,
  never on `list-permissions`.
- An L1 property left unset still takes the service default on the live resource (an Athena
  workgroup without `enforceWorkGroupConfiguration` enforces); docs say the property is unset, never
  what the service then does.
- A jsii library whose entry point exports nothing builds an empty assembly and type-checks none of
  its deep-imported interfaces; to prove new interfaces jsii-legal, export them from the entry point
  in a throwaway build, read the `.jsii` `types`, and revert.
- To target a region with `cdk synth`/`deploy`, set `AWS_REGION`/`AWS_DEFAULT_REGION`; the CLI
  re-derives `CDK_DEFAULT_REGION` from the SDK default and overrides an exported value.
- CloudFront `ResponseHeadersPolicy` keeps one value per header name; merge a new directive into an
  existing custom header's value, grep the stack for an existing policy before creating one, and
  emit `X-XSS-Protection: 0` (`protection: false`), never `1; mode=block`.
- From TypeScript 6.0, `types` defaults to an empty list instead of every `@types/*` package; list
  `node` and `jest` explicitly in every tsconfig that compiles tests or reads ambient globals,
  including the `tsconfig.dev.json` a jsii package keeps for ts-jest, or the tests fail with TS2593
  (`Cannot find name 'describe'`) and scripts with TS2591 (`Cannot find name 'process'`).
- Lake Formation caps LF-tag keys and values at 50 characters and compares both ignoring case,
  whatever the API reference's limits say; validate keys and values at 50 and reject values that
  differ only in case.
- Before declaring a non-jsii runtime dependency in a jsii library, install the built package into a
  scratch consumer first: `dependencies` and `peerDependencies` fail the jsii build without
  `bundledDependencies`, a bundled dependency of a `file:` package installs nothing under
  `install-links=true`, and `optionalDependencies`, declared again by the consumer, both builds and
  installs.
- Before encoding a Glue DQDL rule type's NULL or filter behaviour, run it in a throwaway Data Catalog
  ruleset against a negative-control row (a NULL and an unmatched value); `ReferentialIntegrity`
  counts a NULL local value as missing and accepts no `where` clause, so an optional column needs a
  `CustomSql` anti-join instead.
- A Data Catalog `ReferentialIntegrity` rule written `"<db>.<table>.<col>"` resolves from the catalog
  with no `AdditionalDataSources`, while an `AdditionalDataSources` key may not contain `.` or `-` and
  `CustomSql` can read a reference table only through such a key; the run record copies the primary
  source's `AdditionalOptions` onto every reference entry, whatever the caller sent.
- A jsii build rejects a struct whose members mirror a PascalCase AWS request shape (JSII8002); return nested
  `{ [key: string]: ... }` string maps instead, and type-check an exported free function by wrapping
  it in a throwaway static method, since free functions never reach the assembly.
- When two props files import each other, every field that reads the other file's const is a getter
  on both sides, with a test that loads the modules in the opposite order from the entry point's; a
  one-sided getter fixes only the order the current entry point uses.
