# CDK Coding Guide

Standards and rules for AWS CDK infrastructure projects written in TypeScript.

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
- **Compute instances in private subnets only.** RDS, EB EC2 instances, and Lambda functions must
  always be placed in private subnets.
- **Load balancers in public subnets.** The EB Application Load Balancer and the RDS Network Load
  Balancer are internet-facing and placed in public subnets.
- **NAT:** Use NAT instance (`NatProvider.instanceV2`) for cost efficiency in dev. Consider NAT
  Gateway for production high availability.
- **VPC Endpoints:** Always create a Secrets Manager VPC endpoint in private subnets.
- **VPC Flow Logs:** All traffic logged to CloudWatch with 1-year retention.

### 2.3 Principle of Least Privilege (POLP)

- **IAM roles:** Only attach the minimum managed policies needed. EB EC2 role gets
  `AWSElasticBeanstalkWebTier` + `AWSElasticBeanstalkWorkerTier` only.
- **Policy claims:** Check a claim that every statement of a kind carries a condition against the
  statements of a fully synthesized template, root and nested stacks, not a grep of the source; an
  L2 construct adds statements the source never writes.
- **Secret access:** Only the EB role and the rotation Lambda can read the RDS secret.
- **S3 access:** Block all public access (`BlockPublicAccess.BLOCK_ALL`). CloudFront uses Origin
  Access Control (OAC), not public bucket policies.
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
my_app_cdk/
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

- **Stacks:** `PascalCaseStack` (e.g., `AppStack`, `MonitoringStack`).
- **Construct IDs:** PascalCase, descriptive (e.g., `RDSSecurityGroup`, `ACMCertificate`).
- **Config files:** kebab-case (e.g., `general-configs.ts`, `rds-configs.ts`). Exception:
  `ebConfigs.ts` (legacy naming).
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
describe('AppStack', () => {
    let template: Template;

    beforeAll(() => {
        const app = new App();
        const stack = new AppStack(app, 'TestStack', { env: { region: 'us-east-1' } });
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

| Rule                                | Setting                            |
| ----------------------------------- | ---------------------------------- |
| `indent`                            | 4 spaces                           |
| `quotes`                            | Single (template literals allowed) |
| `comma-dangle`                      | Always multiline                   |
| `array-bracket-newline`             | Multiline, minItems: 1             |
| `array-element-newline`             | Multiline, minItems: 1             |
| `object-curly-newline`              | Multiline, minProperties: 1        |
| `object-property-newline`           | Always (no same-line)              |
| `quote-props`                       | As needed                          |
| `@typescript-eslint/no-unused-vars` | Error (except `_` prefixed)        |

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
- **Frontend:** `aws s3 sync build/ s3://<app>-ui-{stage}/` + CloudFront invalidation
- **Infrastructure:** `cdk deploy` via CodePipeline CDK step

### 6.3 Stage Configuration

| Stage           | Domain            | Removal Policy |
| --------------- | ----------------- | -------------- |
| `dev` / `local` | `dev.example.com` | DESTROY        |
| `prod`          | `example.com`     | RETAIN         |

---

## 7. Reference Tooling Setup

When starting a new CDK or TypeScript repo, set up the tooling below rather than re-deriving it; it
is one working arrangement, the same for a CDK construct library and a non-CDK TypeScript package,
whether the package sits at the repo root or in a monorepo directory such as `packages/core`.

### 7.1 Files to set up

- **ESLint flat config** (`eslint.config.js`) — ESLint 9 flat config: base JS recommended +
  `@typescript-eslint` recommended + `eslint-plugin-jest` for `*.test.ts`. Key rules: `indent` 4
  with `SwitchCase: 1`, single quotes, `comma-dangle: always-multiline`, `array-bracket-newline`
  minItems 1, `array-element-newline` minItems 2, `object-curly-newline` minProperties 1,
  `object-property-newline`. Lint script:
  `eslint . --ext .ts,.tsx --report-unused-disable-directives --max-warnings=0 --fix --ignore-pattern '**/*.d.ts'`.
- **TypeScript config** (`tsconfig.json` + `tsconfig.build.json`) — `target ES2022`,
  `module`/`moduleResolution` `NodeNext`, `strict`, `declaration`, `inlineSourceMap`. A separate
  `tsconfig.build.json` extends it with `outDir: dist`. **Gotcha:** to stop a bare `tsc` from
  emitting stray `.js`/`.d.ts` next to sources (which then shadow the `.ts` under ts-jest and
  silently run stale code), set `"noEmit": true` in the base `tsconfig.json` and `"noEmit": false`
  only in `tsconfig.build.json`. Build only via `npm run build`, never a bare `tsc`.
- **Jest** (`jest.config.js`) — `ts-jest`, `roots: [test]`, `testMatch: ['**/*.test.ts']`,
  `collectCoverageFrom` over `lib/**/*.ts` (or `src/**/*.ts`), reporters including `lcov` for
  Codecov, and a `coverageThreshold` of 95% on statements / branches / functions / lines.
- **package.json scripts** — `build` (`tsc -p tsconfig.build.json`), `lint`, `test` (`jest`),
  `clean`, `dev`, and `prepublishOnly` (`build && test`).

### 7.2 CI/CD

Badges, the CI workflow, the npm publish workflow (OIDC trusted publishing, version-guarded on
`main`), and the version-bump-per-PR rule are in
[`npm-publishing-pattern.md`](npm-publishing-pattern.md), which describes `ci.yml` and `publish.yml`
for a single package and for a monorepo (set the package `working-directory`). A CDK construct repo
may also keep an integration-test workflow that runs a real `cdk deploy`; that is CDK-specific and
gated, separate from this base.

## Self-mutation rule

Maintained by the orchestrating session only, never by a delegated subagent or headless worker, even
one instructed to read this file; a subagent that notices something worth adding reports it under
`Proposed learned pattern:` in its own output. Lessons here are stack-specific and true in any repo
of this stack; repo-specific facts go to that repo's `.claude/rules/`. Append an imperative bullet
under `## Learned patterns` (one sentence, two at most; no date, no repo name, no "added after"
tail), refine near-duplicates in place, keep the section under ~25 entries, and open a PR against
the plugin repository (`ksco92/my-dev-team`). A lesson on how an AWS service behaves behind its
construct (Glue, Lake Formation, CloudTrail, CloudFront, Step Functions, EventBridge) goes to
`cdk-services-coding-guide.md`.

## Learned patterns

- Region-qualify globally unique resource names (S3 `bucketName`) with `${this.region}` whenever a
  stack may deploy to more than one region or share an account with a sibling using the same
  `name-${account}` pattern.
- A caret range on an `@aws-cdk/aws-*-alpha` prerelease only matches the same `major.minor.patch`
  tuple; pin the alpha to the construct's exact alpha line, let stable `aws-cdk-lib` float, and
  install all three in one `npm install`; a consumer of a library that peers on the alpha settles
  the same pin with an `npm install` in a temp dir before the slice is written. Before raising an
  alpha floor, run `npm view <pkg>@<version> stability` across the bump range; a `stability` of
  `deprecated` means the module graduated into `aws-cdk-lib`.
- When swapping an alpha L2 for its stable counterpart, diff the constructors' defaults as well as
  the typings by synthesizing both against the base; a stable promotion can flip a default (a
  removal policy gaining RETAIN) on a fixed-name resource that destroy-then-redeploy then trips
  over.
- A CloudWatch `Dashboard` body is an `Fn::Join` with region tokens and L2 dimensions render as
  `Ref`s; in template tests join the parts with a placeholder for intrinsics, parse, and assert
  dimension keys, not values. Glue catalog objects and LakeFormation permissions are not taggable;
  `Tags.of()` skips them silently.
- An L1 property left unset still takes the service default on the live resource (an Athena
  workgroup without `enforceWorkGroupConfiguration` enforces); docs say the property is unset, never
  what the service then does.
- A jsii library whose entry point exports nothing builds an empty assembly and type-checks none of
  its deep-imported interfaces; to prove new interfaces jsii-legal, export them from the entry point
  in a throwaway build, read the `.jsii` `types`, and revert; wrap an exported free function in a
  throwaway static method to type-check it.
- To target a region with `cdk synth`/`deploy`, set `AWS_REGION`/`AWS_DEFAULT_REGION`; the CLI
  re-derives `CDK_DEFAULT_REGION` from the SDK default and overrides an exported value.
- A synth that must not depend on the caller's account builds the `App` in a test, never through the
  CLI: the CLI sets `CDK_DEFAULT_ACCOUNT` from whatever credentials its default provider chain finds
  (shared files, environment keys, web identity, container and instance metadata) with one STS call
  and overrides an exported value.
- A flat ESLint block written as `{ ...preset, rules: {...} }` discards the preset's rules (the
  preset is `{ name, rules }` and the later key wins); spread `...preset.rules` inside `rules`, and
  prove it with a `debugger;` probe file that lint must report.
- A `cdk diff` run with flags the deploy will not use (`--no-version-reporting`, `--strict`) is not
  evidence for a deploy decision, since each flag changes what the synth contains or what the diff
  reports; diff with the deploy's own flags.
- A test that a principal is named in no resource policy stringifies the whole candidate resources
  (`findResources` for the key and bucket policies) and asserts `not.toContain(logicalId)`, with one
  `resourceCountIs` as the non-vacuity guard; extracting `Principal` fields misses a grant to
  `AnyPrincipal` conditioned on `aws:PrincipalArn`, so the probe includes that mutation.
- When a CDK property override targets an array index
  (`AssumeRolePolicyDocument.Statement.0.Action`), the test compares the resource's whole
  `Properties` with `toEqual`, so an override that lands on the wrong index or adds a statement
  fails instead of passing `hasResourceProperties`.
- A `cdk diff` line "may cause replacement" on an account-settings singleton (Lake Formation
  `DataLakeSettings`) is checked against the property's documented update behaviour before
  deploying, and the stack events are read for the same physical id and no delete afterwards.
- From TypeScript 6.0, `types` defaults to an empty list instead of every `@types/*` package; list
  `node` and `jest` explicitly in every tsconfig that compiles tests or reads ambient globals,
  including the `tsconfig.dev.json` a jsii package keeps for ts-jest, or the tests fail with TS2593
  (`Cannot find name 'describe'`) and scripts with TS2591 (`Cannot find name 'process'`).
- Before declaring a non-jsii runtime dependency in a jsii library, install the built package into a
  scratch consumer first: `dependencies` and `peerDependencies` fail the jsii build without
  `bundledDependencies`, a bundled dependency of a `file:` package installs nothing under
  `install-links=true`, and `optionalDependencies`, declared again by the consumer, both builds and
  installs.
- A jsii build rejects a struct whose members mirror a PascalCase AWS request shape (JSII8002);
  return nested `{ [key: string]: ... }` string maps instead.
- A reference between declared resources (a dependency, a foreign key) puts its target upstream:
  synth rejects a cycle through every reference kind together, and lint rejects a circular import
  between props files (`import-x/no-cycle`).
- A reference to a const inside its own initializer (a self-reference, not a mutual import) is the
  one reference declared as a getter; a reference to another file's const is a plain value.
- `eslint-plugin-import-x` `no-cycle` reports nothing on `.ts` files unless
  `settings['import-x/extensions']` lists `.ts` and the resolver's `extensions` list it too.
- A file a construct generates at synth for an asset is written under the cloud assembly's outdir
  (`Stage.of(scope).outdir`), never the OS temp dir, into a folder emptied before the write rather
  than deleted after; a folder deleted after construction leaves the asset manifest pointing at
  nothing under `aws:cdk:disable-asset-staging`, and a throw between the write and the delete leaves
  it behind.
- Dropping a restated default from a construct still changes the template: check each removed
  property's documented update behaviour before calling the change deploy-free, since one that
  requires replacement fails the deploy of a custom-named resource, and replace its value assertion
  with an absence assertion (`Match.absent()`) rather than deleting it.
- A doc or skill that tells a reader to remove a resource from the stack and deploy, which deletes
  it, holds only under `RemovalPolicy.DESTROY`; under `RETAIN` the resource stays and the deploy
  that recreates it fails on the existing name, so check the instruction against every removal
  policy a consumer can pick.
- Measure in a synthesized template any policy statement that lists one ARN per resource: CDK moves
  whole statements into overflow managed policies and never splits one, so a statement past the
  6,144 characters a managed policy holds fails the deploy; document the resource count that reaches
  it.
