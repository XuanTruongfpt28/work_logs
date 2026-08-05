---
title: "Architecture & Design"
date: 2026-07-07
weight: 3
chapter: false
pre: " <b> 5.3. </b> "
---

# Section 5.3 - Technical Architecture & Design

**AI AWS Advisor** is built on 3 core technical pillars: **Serverless Architecture**, **Zero-Trust Security**, and **Generative AI**.

---

## 1. System Overview Architecture

The system splits its security boundary into 3 independent zones, illustrated in the architecture diagram below:

**Overall Architecture (3 security boundaries: Client Frontend / SaaS Provider Backend / Customer Target Account):**



> **Diagram description:** The diagram is split into three zones.
> - **Zone 1 — Client Frontend:** React 19 Dashboard SPA, TanStack React Query, Recharts, hosted on CloudFront + S3, authenticated via Amazon Cognito (JWT).
> - **Zone 2 — SaaS Provider Backend:** API Gateway (REST, 11 routes, Cognito JWT Authorizer, 1000/month quota, burst 50, rate 100/s); six Lambda functions (five API handlers: projects-api, resources-api, insights-api, chat-api, alerts-api, plus one Collector Lambda `ai-advisor-collector`); Amazon EventBridge `rate(1 hour)` triggering the Collector; Amazon Bedrock Claude 3 Haiku for AI analysis; DynamoDB Multi-Table (4 tables); Amazon SNS Topic `ai-advisor-alerts` emailing critical-risk alerts.
> - **Zone 3 — Customer Target AWS Account:** Read-Only IAM Role `AIAdvisorAuditRole` + trust policy, AWS STS authenticating and returning temp credentials, plus the customer's own resources (EC2, S3, IAM, Lambda, CloudWatch).
> - **Arrow legend:** solid arrows = intra-account flow (HTTPS/JWT, hourly trigger, Bedrock prompt, SNS publish, boto3 read); dashed arrows = cross-account `sts:AssumeRole` delegation from the Collector to the customer's IAM Role, including the temp-credentials return path.

**This diagram shows:**

The diagram is divided into three zones corresponding to three AWS accounts / security boundaries:

| # | Zone | Boundary | Owner | Purpose |
|---|------|-----------|------------|----------|
| 1 | **Zone 1** | **Client Frontend** (React 19 + Vite) | Browser | Renders the dashboard, fetches data via TanStack React Query, charts with Recharts, hosted on CloudFront + S3, authenticated via Amazon Cognito (JWT). |
| 2 | **Zone 2** | **SaaS Provider Backend** (Serverless Stack) | This workshop's account | Hosts API Gateway (11 REST routes), five API Lambda functions, one scheduled Collector Lambda, an Amazon EventBridge schedule, Amazon Bedrock (Claude 3 Haiku), four DynamoDB tables + 1 GSI, and one Amazon SNS topic for critical alerts. |
| 3 | **Zone 3** | **Customer Target AWS Account** | Each tenant | Grants a Read-Only IAM Role that trusts the SaaS Provider's account, and allows EC2 / S3 / IAM / Lambda / CloudWatch resources to be audited. |

**Three notable design decisions:**

- **100% Serverless on the Provider side.** API Gateway + Lambda + DynamoDB + EventBridge + SNS means no EC2 instance ever needs to run; idle cost is exactly $0 since all four DynamoDB tables use `PAY_PER_REQUEST`.
- **No fixed customer credentials.** The dashed arrow crossing the Zone 2 ↔ Zone 3 boundary (Provider ↔ Customer) represents `sts:AssumeRole` delegation — temporary credentials, scoped to a single audit session, never persisted to disk.
- **Hourly cadence with AI processing on top.** EventBridge triggers the Collector Lambda every hour; the raw inventory is stored in DynamoDB, then a single prompt is sent to Bedrock (Claude 3 Haiku) to analyze Security / Cost / Performance. Critical risks are forwarded to SNS, which sends an email alert.


### Design Decision: 100% Serverless

Running on AWS Lambda, API Gateway, and DynamoDB eliminates the baseline cost of running EC2 infrastructure 24/7, delivering zero idle cost and instant scalability.

---

## 2. Zero-Trust Security (Cross-Account Delegation)

Instead of requiring customers to provide fixed Access Key / Secret Key credentials (a very high leak risk), the system asks customers to grant a Read-Only IAM Role that trusts our SaaS account.

**Figure - Zero-Trust STS AssumeRole Sequence Flow (Provider Lambda ↔ Customer IAM Role via STS):**

![Zero-Trust Cross-Account STS AssumeRole flow](/images/5-Workshop/5.3-Architecture-design/zero_trust_security_cross_account.png)

**How Zero-Trust Cross-Account Delegation works in this system:**

| Step | Actor | Action |
|------|----------|-----------|
| 1 | **SaaS Provider (Collector Lambda)** | Calls `sts:AssumeRole` with the customer's Role ARN, provided when the project was created. The customer-side trust policy must whitelist the SaaS Provider's account ID (and optionally an `ExternalId`). |
| 2 | **AWS STS** | Validates the trust policy: checks that the calling principal matches, checks the `ExternalId` matches (if present), and confirms the permission boundary (if any) is satisfied. |
| 3 | **Customer IAM Role** | If the trust policy matches, AWS STS issues a **session token** with `AccessKeyId`, `SecretAccessKey`, and `SessionToken`, all valid for **1 hour** (`DurationSeconds=3600`). |
| 4 | **Collector Lambda** | Receives the temporary credentials and uses them to build a new `boto3.Session` for the customer's account. From here, every `boto3.client('ec2')`, `boto3.client('s3')`, `boto3.client('iam')` call is signed with the temporary session. |
| 5 | **Audit APIs** | The Collector lists EC2 / S3 / IAM / Lambda / CloudWatch resources, packages them as JSON, and writes them to the `ai-advisor-resources` DynamoDB table. |
| 6 | **Expiration** | An hour later, the temporary credentials are automatically revoked by AWS — the next scan will issue a fresh session. No fixed customer key ever touches our infrastructure. |

**Why this matters for Zero-Trust:**

- **No shared secrets.** The SaaS Provider never sees, stores, or transmits the customer's fixed Access Key / Secret Key. Even a full breach of the Provider-side database wouldn't leak customer credentials, because they never existed there in the first place.
- **The customer controls the blast radius.** The customer chooses (a) which principal is allowed to assume the role, (b) what permissions the role grants (typically `ReadOnlyAccess`), and (c) whether to add an `ExternalId` to prevent a *confused-deputy* attack. The customer can revoke access at any time by editing the trust policy or deleting the role.
- **Time-bounded sessions.** Credentials expire on their own after one hour. If the Collector is ever compromised mid-session, the window of opportunity is limited.
- **Read-only by default.** The recommended IAM policy is `arn:aws:iam::aws:policy/ReadOnlyAccess`. The Collector cannot mutate customer resources — it can only list them. The full list of the 23 read-only actions used is in section 5.3.10.

> The customer's IAM Role is created and fully owned by the tenant. The SaaS Provider only ever knows the Role ARN. Section 5.4 walks through the onboarding flow where the customer pastes the Role ARN into the dashboard.

---

## 3. Automated Scanning & AI Analysis Flow

**Figure - Automated Scanning & AI Analysis Sequence Flow (EventBridge → Collector → STS → DynamoDB → Bedrock → SNS):**

![Automated scanning and AI analysis flow](/images/5-Workshop/5.3-Architecture-design/automated_scanning_ai_analysis_flow.png)

**How the end-to-end hourly scan works:**

The entire scan + AI-analysis pipeline runs on a fixed hourly cadence (`rate(1 hour)`, declared in `template.yaml` and configurable in the EventBridge console). For each active project, the Collector repeats the same 6-stage pipeline:

| Stage | Component | What Happens |
|-----------|-----------|----------------|
| 1. **Trigger** | Amazon EventBridge | Triggers `CollectorFunction` on a `rate(1 hour)` schedule. The trigger payload is an empty JSON `{}` (no manual invocation needed). |
| 2. **Project lookup** | Collector Lambda → DynamoDB `ai-advisor-projects` | Reads every row with `SK = METADATA` to get the list of active tenants. Each row contains `project_id`, `role_arn`, `region`, and `project_name`. |
| 3. **Cross-account assume** | Collector → AWS STS → Customer IAM Role | For each project, calls `sts:AssumeRole(RoleArn=project.role_arn, RoleSessionName='CollectorSession')`. Receives `AccessKeyId`, `SecretAccessKey`, `SessionToken`, valid for 1 hour. See section 5.3.2 for the full delegation flow. |
| 4. **Resource enumeration** | Collector → boto3 (EC2 / S3 / IAM / Lambda / CloudWatch) | Builds a new `boto3.Session` from the temp credentials and runs 23 read-only API calls (full list in section 5.3.10). The result is a JSON inventory. |
| 5. **Persist raw resources** | Collector → DynamoDB `ai-advisor-resources` | Writes each resource as `(project_id, resource_id)` with `resource_type`, `collected_at`, and `raw_data`. The `resource_type-index` GSI lets the dashboard query "all S3 buckets across every project" without a scan. |
| 6. **AI analysis** | Collector → Amazon Bedrock (Claude 3 Haiku) | Builds a prompt combining the raw inventory with a structured instruction: *"For each resource, identify Security, Cost, and Performance risks. Return JSON with severity (CRITICAL/HIGH/MEDIUM/LOW), category, title, description, and recommendation."* Bedrock returns a parsed JSON response. |
| 7. **Persist insights** | Collector → DynamoDB `ai-advisor-insights` | Writes each insight as `(project_id, insight_id)`, keyed by severity for fast filtering on the dashboard. |
| 8. **Alert routing (optional)** | Collector → Amazon SNS | If any insight has `severity = CRITICAL`, the Collector publishes a JSON message to the `ai-advisor-alerts` SNS topic, fanning out an email to the configured `AlertEmail` SAM parameter. |

**Why this design fits AI-driven auditing:**

- **One collection pass; AI does the synthesis.** The Collector is deliberately *simple* — it doesn't try to reason about individual resources. It only lists and stores them. All security / cost / performance reasoning happens in a single Bedrock call, where Claude 3 Haiku has full context across every resource in one prompt.
- **Idempotent and resilient.** Each scan writes resource rows keyed by `(project_id, resource_id)`. A Lambda failing mid-run doesn't corrupt the table; the next scan simply overwrites cleanly.
- **Cost-bounded.** Bedrock is called once per project per hour. With `ai-advisor-resources` on PAY_PER_REQUEST and Bedrock's pay-per-token pricing, an idle tenant costs exactly $0.
- **Auditable history.** Since every resource and insight is timestamped in DynamoDB, cost/security trends over time can be charted by querying the GSI.

> The Collector Lambda's 23-action IAM policy is documented in section 5.3.10; EventBridge + SNS configuration is in section 5.3.7.

---

## 4. DynamoDB Multi-Table Database Design

The application stores data across **four dedicated DynamoDB tables** (one table per entity). While every table shares `project_id` as its Partition Key to guarantee absolute tenant isolation, this design is deliberately *not* single-table — the four entities have different access patterns, secondary indexes, and attribute schemas, so multi-table keeps each table small and fast. The single-table layout is documented in section 5.3.6 as a point of comparison, but it is *not* what the production template deploys.

**DynamoDB Multi-Table Entity-Relationship Diagram (4 tables, all sharing `project_id` as the Partition Key for tenant isolation):**


> **Diagram description (readable even if the image hasn't loaded):** Four dedicated tables — **PROJECTS**, **RESOURCES**, **INSIGHTS**, **ALERTS** — all share `project_id` as their Partition Key for tenant isolation.
> - **PROJECTS** (PK: `project_id`, SK: `sk`) — the root entity, holding customer-project metadata.
> - **RESOURCES** (PK: `project_id`, SK: `resource_id`) — raw AWS resource snapshots (EC2, S3, IAM, Lambda, CloudWatch) collected by the Collector Lambda; also carries a **GSI `resource_type-index`** (HASH: `resource_type`, RANGE: `collected_at`) for cross-project queries by resource type.
> - **INSIGHTS** (PK: `project_id`, SK: `insight_id`) — AI recommendations generated by Bedrock Claude 3 Haiku.
> - **ALERTS** (PK: `project_id`, SK: `alert_id`) — critical-risk alerts published to the SNS Topic.
> - **Key point:** this is a **Multi-Table** design (4 dedicated tables), **not** single-table; tenant isolation is guaranteed via `project_id` as the shared partition key across all 4 tables.

**Entity relationships explained in text:**

- **One project → many resources** — Each row in `ai-advisor-projects` owns many rows in `ai-advisor-resources`, one row per scanned AWS resource (EC2 instance, S3 bucket, IAM role, Lambda function, CloudWatch metric, …).
- **One project → many insights** — Each project accumulates many rows in `ai-advisor-insights`, one row per AI-generated finding (security risk, cost optimization, performance bottleneck).
- **One project → many alerts** — A subset of insights that hit `severity = CRITICAL` are duplicated into `ai-advisor-alerts` so the dashboard can display a dedicated alert feed and the SNS pipeline has a clean target table.
- **Cross-project resource queries** — The `ai-advisor-resources` table carries a Global Secondary Index named `resource_type-index` (PK: `resource_type`, SK: `collected_at`). This GSI lets the dashboard answer "show all S3 buckets across every project" without scanning each project's partition individually.

**Why multi-table instead of single-table:**

| Concern | Multi-table (this project) | Single-table |
|----------------|--------------------------|--------------|
| **Per-entity access pattern** | Each table exactly matches its own query pattern (e.g. resources need a GSI on `resource_type`, insights don't). | A single table must encode every access pattern through overloaded keys; harder to reason about. |
| **Per-table IAM** | `DynamoDBCrudPolicy` can be scoped per table (e.g. `ResourcesFunction` only gets `DynamoDBReadPolicy` on `ai-advisor-resources`). | A single table requires broader, less granular IAM. |
| **Hot-partition risk** | Only `ai-advisor-resources` has any hot-partition risk; the other tables stay cold. | A single table concentrates write traffic onto one logical partition. |
| **PAY_PER_REQUEST cost** | $0 idle cost per table — same as single-table, but easier to forecast. | Per-item cost is equivalent. |
| **Onboarding cognitive load** | New developers can reason about one entity at a time. | Requires understanding the entire key-encoding scheme up front. |

**Full table inventory:**

| # | Table | Partition Key | Sort Key | GSI | Stores |
|---|-------|---------------|----------|-----|---------|
| 1 | ai-advisor-projects | project_id (S) | sk (S) | - | Project metadata (name, role_arn, region, owner) |
| 2 | ai-advisor-resources | project_id (S) | resource_id (S) | resource_type-index | Raw scanned AWS resources (EC2, S3, IAM, Lambda, CloudWatch) |
| 3 | ai-advisor-insights | project_id (S) | insight_id (S) | - | AI security/cost/performance insights per project |
| 4 | ai-advisor-alerts | project_id (S) | alert_id (S) | - | Critical-risk alerts that triggered an SNS email |

- **PROJECTS:** `PK: project_id`, `SK: sk` — root entity, one row per project
- **RESOURCES:** `PK: project_id`, `SK: resource_id` — raw scanned AWS resources per project
- **INSIGHTS:** `PK: project_id`, `SK: insight_id` — AI security/cost/performance insights per project
- **ALERTS:** `PK: project_id`, `SK: alert_id` — critical-risk alerts that published an SNS email per project

This design guarantees absolute tenant isolation (`project_id` as the Partition Key on every table) and lets each entity use whichever attribute schema and access pattern fits best — for example, only `ai-advisor-resources` carries the `resource_type-index` GSI for cross-project queries by resource type. See section 5.3.6 for the full per-table inventory.

> **Region note:** All 4 DynamoDB tables are deployed in the **same region** as the rest of the SAM stack (`AWS::Region` resolves to the deploy region, e.g. `ap-southeast-1`). The `boto3` client in `backend/shared/db.py` initializes the DynamoDB resource with `region_name=os.environ.get("AWS_REGION", "ap-southeast-1")` — the code default is `ap-southeast-1`, but the SAM parameter always overrides it with the stack's actual region. **Amazon Bedrock** lives in a *different* region (`us-east-1` by default for Claude 3 Haiku) and is configured separately in `template.yaml` under the `Environment.BedrockRegion` variable. The Bedrock region is deliberately decoupled from the DynamoDB region — Bedrock is only available in a small subset of AWS regions.

---

## 5. End-to-End Architecture Overview (Reference PNG)

The diagram below consolidates every AWS service in the system, organized into 3 security boundaries (Client, Provider Backend, Customer Target Account) with labeled arrows for every major request flow:

**End-to-End Architecture Diagram (3 security boundaries + 19 AWS services):**


> **Diagram description:**
> - **Zone 1 — Client Frontend:** React 19 Dashboard, S3 + CloudFront, Cognito JWT, API Gateway.
> - **Zone 2 — SaaS Provider Backend:** six Lambda functions (five API handlers — projects-api, resources-api, insights-api, chat-api, alerts-api — and one Collector Lambda triggered by EventBridge `rate(1 hour)`); Bedrock Claude 3 Haiku; SNS alerts; DynamoDB Multi-Table with 4 tables + 1 GSI `resource_type-index`.
> - **Zone 3 — Customer Target AWS Accounts:** IAM Role `AIAdvisorAuditRole`, STS AssumeRole, EC2, S3, IAM, Lambda, CloudWatch.
> - **11 numbered flow steps:** (1) browser requests the dashboard over HTTPS → (2) CloudFront + S3 serve the React bundle → (3) Cognito issues a JWT after login → (4) API Gateway receives the REST call with the JWT → (5) the API Handler Lambda executes with DynamoDB read/write → (6) the Collector Lambda is triggered (via EventBridge or the `/sync` API) → (7) the Collector queries DynamoDB PROJECTS for active customers → (8) the Collector calls `sts:AssumeRole` to get temp credentials in the target account → (9) the Collector uses boto3 to read 23 AWS read-actions (EC2/S3/IAM/Lambda/CloudWatch) → (10) the Collector writes raw data to DynamoDB RESOURCES, calls Bedrock Claude 3 Haiku for analysis, writes insights, and publishes critical-risk alerts to SNS.
> - **Arrow legend:** solid arrows = intra-account flow; dashed arrows = cross-account `sts:AssumeRole` delegation from the Collector to the customer's IAM Role.



---

## 6. DynamoDB Tables (4 Tables + 1 GSI)

The backend stores data across **four DynamoDB tables**, all using PAY_PER_REQUEST so idle cost stays near $0:

| # | Table Name | Partition Key | Sort Key | GSI | Contents |
|---|---|---|---|---|---|
| 1 | ai-advisor-projects | project_id (S) | sk (S) | - | Project metadata (name, role_arn, region, owner) |
| 2 | ai-advisor-resources | project_id (S) | resource_id (S) | resource_type-index (PK: resource_type, SK: collected_at) | Raw scanned resources (EC2, S3, IAM, Lambda, CloudWatch) |
| 3 | ai-advisor-insights | project_id (S) | insight_id (S) | - | AI insights (security / cost / performance) |
| 4 | ai-advisor-alerts | project_id (S) | alert_id (S) | - | Critical-risk alerts sent via SNS |

The resource_type-index GSI lets the dashboard query, for example, 'all S3 buckets across every project' without a full table scan.

---

## 7. EventBridge Schedule and SNS Alert Pipeline

- The **EventBridge rule** is declared inline in template.yaml with Schedule: rate(1 hour) and Enabled: true. To change the frequency, edit the rule and redeploy the stack.
- The **SNS topic** ai-advisor-alerts is created with an email subscription. Update the AlertEmail SAM parameter to change the recipient.

> **Cross-project query strategy with the `resource_type-index` GSI:** The single GSI on `ai-advisor-resources` is purpose-built for **cross-project queries by resource type**. The base table's primary key (`project_id`, `resource_id`) is optimized for *intra-project* queries like "all resources for project X." But the dashboard also needs to answer *cross-project* queries like "show every S3 bucket across every project" (e.g. for a global misconfiguration sweep). Without a GSI, that query would require a `Scan` of the entire `ai-advisor-resources` table. With the GSI, the same query becomes a `Query` against `resource_type-index` with `KeyConditionExpression = "resource_type = :t"` — O(matches) instead of O(table). The trade-off is duplicated writes (each resource is written once to the base table and once more to the index under `resource_type + collected_at` on the GSI), but with `PAY_PER_REQUEST` and a small resource volume per project, that cost is negligible compared to the query-latency benefit.

---

## 8. Cognito User Pool and API Gateway Authorizer

| Component | CloudFormation Resource | Purpose |
|---|---|---|
| AdvisorUserPool | AWS::Cognito::UserPool | Holds end-user identities (email as username) |
| AdvisorUserPoolClient | AWS::Cognito::UserPoolClient | Frontend SPA client (no secret, public flow) |
| AdvisorApi.Auth | AWS::Serverless::Api | JWT authorizer attached to the User Pool ARN |
| CognitoAuthorizer | API Gateway Authorizer | Validates the Authorization: Bearer <JWT> header on every API call |

All 11 routes are protected by the CognitoAuthorizer — anonymous requests return HTTP 401.

---

## 9. API Gateway Throttling and Quota

The AdvisorUsagePlan resource applies the following limits on the prod stage:

| Setting | Value |
|---|---|
| Rate limit (steady) | **100 requests/second** |
| Burst limit | **50** |
| Monthly quota | **1000 requests/month** |

{{% notice info %}}The 1000 req/month quota is sized for **one workshop author + a few testers**. For multi-tenant SaaS production, raise the quota (or remove it) and use per-tenant throttling via API keys.{{% /notice %}}

---

## 10. Collector Lambda IAM Permissions (23 Actions)

The CollectorFunction is granted Resource: '*' for 23 AWS actions across 7 service groups. This is the *minimum* set needed to read EC2/S3/IAM/Lambda/CloudWatch across every region of the target account:

| Service | Actions | Purpose |
|---|---|---|
| EC2 | DescribeInstances, DescribeInstanceStatus, DescribeSecurityGroups | Inventory + utilization |
| S3 | ListAllMyBuckets, GetBucketAcl, GetBucketPublicAccessBlock, GetBucketLocation | Detect public-access risk |
| IAM | ListRoles, ListAttachedRolePolicies, ListRolePolicies, ListUsers, ListMFADevices, ListAccessKeys, GetLoginProfile | Privilege hygiene |
| Lambda | ListFunctions, GetFunctionConfiguration | Cold-start + runtime audit |
| CloudWatch | GetMetricStatistics, ListMetrics, GetMetricData, DescribeAlarms | 7-day performance baseline |
| STS | AssumeRole | The core cross-account delegation mechanism |
| Bedrock | InvokeModel, InvokeModelWithResponseStream | Generate AI insights |

The customer-side AIAdvisorAuditRole trust policy must allow sts:AssumeRole from the SaaS provider's account (see section 5.4 for the trust policy JSON).

---

## Section Summary

This architecture combines 4 DynamoDB tables, 1 EventBridge schedule, 1 SNS topic, 1 Cognito User Pool, 6 Lambda functions, and 1 API Gateway with Cognito JWT auth — all deployed through a single SAM template (template.yaml). Cross-account auditing is achieved via sts:AssumeRole, with no long-lived credentials ever stored on the SaaS side.