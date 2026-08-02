---
title: "Architecture & Design"
date: 2026-05-01
weight: 3
chapter: false
pre: " <b> 5.3. </b> "
---

# Section 5.3 - Architecture & Technical Design

The **AI AWS Advisor** project is built upon three core technological pillars: **Serverless Computing**, **Zero-Trust Security**, and **Generative AI**.

---

## 1. High-Level Architecture

The system is partitioned into three independent security boundaries, illustrated in the architecture diagram below:

**Figure 1 - High-Level Architecture (3 security boundaries: Client Frontend / SaaS Provider Backend / Customer Target Account):**

<img src="/aws-ojt-workshop-ja/images/5.3-Architecture-design/high_level_architecture.png?v=2026-08-01-r2" alt="High-Level Architecture diagram showing three independent security boundaries: (1) Client Frontend zone in blue with React 19 Dashboard SPA, TanStack React Query, Recharts Visualization, CloudFront + S3 hosting, Amazon Cognito JWT, and Browser User Flow; (2) SaaS Provider Backend zone in purple with API Gateway (REST, 11 routes, Cognito JWT Authorizer, quota 1000/mo, burst 50, rate 100/s), SIX Lambda Functions: FIVE specialized API Handlers (projects-api, resources-api, insights-api, chat-api, alerts-api) and ONE Collector Lambda (ai-advisor-collector, hourly scan rate(1 hour), STS AssumeRole, 23 AWS read actions across EC2/S3/IAM/Lambda/CloudWatch), Amazon EventBridge rate(1 hour) triggering the Collector, Amazon Bedrock Claude 3 Haiku (anthropic.claude-3-haiku-20240307-v1:0) for AI analysis, DynamoDB Multi-Table (4 dedicated tables: ai-advisor-projects PK=project_id+SK=sk, ai-advisor-resources PK=project_id+SK=resource_id + GSI resource_type-index, ai-advisor-insights PK=project_id+SK=insight_id, ai-advisor-alerts PK=project_id+SK=alert_id), Amazon SNS Topic ai-advisor-alerts with email subscription for critical-risk alerts; (3) Customer Target AWS Account zone in amber with Read-Only IAM Role AIAdvisorAuditRole + trust policy, AWS STS validating trust policy and returning temporary credentials, and customer AWS resources (EC2, S3, IAM, Lambda, CloudWatch). Solid arrows denote intra-account data flows (HTTPS REST with JWT, every-1h trigger, Bedrock prompt, critical-risk SNS publish, boto3 read API); dashed red arrows denote the cross-account sts:AssumeRole delegation from Collector Lambda to Customer IAM Role, and the temp-credentials return path." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**What this diagram shows:**

The diagram is split into three coloured zones that correspond to three AWS accounts / security boundaries:

| # | Boundary | Colour | Owner | Purpose |
|---|----------|--------|-------|---------|
| 1 | **Client Frontend** (React 19 + Vite) | Blue | Browser | Renders the dashboard, fetches data via TanStack React Query, charts with Recharts, hosted on CloudFront + S3, authenticated via Amazon Cognito (JWT). |
| 2 | **SaaS Provider Backend** (Serverless Stack) | Purple | This workshop's account | Hosts the API Gateway (11 REST routes), five API Lambda functions, one scheduled Collector Lambda, Amazon EventBridge schedule, Amazon Bedrock (Claude 3 Haiku), four DynamoDB tables + 1 GSI, and an Amazon SNS topic for critical alerts. |
| 3 | **Customer Target AWS Account** | Amber | Each tenant | Provisions a Read-Only IAM Role that trusts the SaaS Provider account, and exposes EC2 / S3 / IAM / Lambda / CloudWatch resources to be audited. |

**Three notable design decisions:**

- **100 % Serverless on the Provider side.** API Gateway + Lambda + DynamoDB + EventBridge + SNS means there is no EC2 instance to babysit; idle cost is exactly $0 because all four DynamoDB tables use `PAY_PER_REQUEST` billing.
- **Zero long-lived customer credentials.** The dashed red arrows crossing the Provider ↔ Customer boundary represent `sts:AssumeRole` delegation — temporary credentials only, scoped to a single audit session, never persisted to disk.
- **Hourly cadence with AI on top.** EventBridge fires the Collector Lambda every hour; the raw inventory is stored in DynamoDB, then a single Prompt is sent to Bedrock (Claude 3 Haiku) for Security / Cost / Performance analysis. Critical risks are routed to SNS for email alerts.

> **Reading guide:** In Figure 1, follow the solid blue arrow (User → API Gateway) to see how a single dashboard request travels; then follow the dashed red arrows (Collector → STS → Temp Credentials → boto3 read API) to see how a single hourly scan crosses into the customer account.

### Design Decision: 100% Serverless

Operating on AWS Lambda, API Gateway, and DynamoDB eliminates baseline 24/7 EC2 infrastructure costs, granting zero idle costs and instant scalability.

---

## 2. Zero-Trust Security (Cross-Account Delegation)

Instead of storing customer permanent AWS Access Keys (which introduces massive security risks), the application requires customers to provision a Read-Only IAM Role that trusts our SaaS account.

**Figure 2 - Zero-Trust STS AssumeRole sequence (Provider Lambda ↔ Customer IAM Role via STS):**

<img src="/aws-ojt-workshop-ja/images/5.3-Architecture-design/zero_trust_security_cross_account.png?v=2026-08-01-r2" alt="Zero-Trust STS AssumeRole sequence diagram — Collector Lambda of the SaaS Provider calls sts:AssumeRole, AWS STS validates the trust policy of the customer IAM Role, returns temporary credentials, then the Collector uses those temporary credentials to audit EC2 and S3 resources in the customer AWS account" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**How Zero-Trust Cross-Account Delegation works in this system:**

| Step | Actor | Action |
|------|-------|--------|
| 1 | **SaaS Provider (Collector Lambda)** | Calls `sts:AssumeRole` against the customer's IAM Role ARN supplied at project creation time. The trust policy on the customer side must whitelist the SaaS Provider account ID (and optionally an `ExternalId`). |
| 2 | **AWS STS** | Validates the trust policy: checks that the calling principal matches, that the `ExternalId` matches (if any), and that the role's permission boundary (if any) is satisfied. |
| 3 | **Customer IAM Role** | If the trust policy matches, AWS STS issues a **session token** with `AccessKeyId`, `SecretAccessKey`, and `SessionToken`, all valid for **1 hour** (`DurationSeconds=3600`). |
| 4 | **Collector Lambda** | Receives the temporary credentials and uses them to build a fresh `boto3.Session` for the customer account. From this point on, every `boto3.client('ec2')`, `boto3.client('s3')`, `boto3.client('iam')` call is signed with the temporary session. |
| 5 | **Audit APIs** | The Collector enumerates EC2 / S3 / IAM / Lambda / CloudWatch resources, packages them as JSON, and writes them to the `ai-advisor-resources` DynamoDB table. |
| 6 | **Expiry** | One hour later the temporary credentials are auto-revoked by AWS — the next hourly scan re-issues a fresh session. No long-lived customer key ever touches our infrastructure. |

**Why this matters for Zero-Trust:**

- **No shared secrets.** The SaaS Provider never sees, stores, or transmits the customer's permanent Access Key / Secret Key pair. Even a full database breach on the Provider side cannot leak customer credentials because they never existed there.
- **Customer-controlled blast radius.** The customer chooses (a) which principal is allowed to assume the role, (b) what permissions the role grants (typically `ReadOnlyAccess`), and (c) whether to add an `ExternalId` to defend against the *confused-deputy* problem. The customer can revoke access at any time by editing the trust policy or deleting the role.
- **Time-bounded sessions.** Credentials auto-expire after one hour. If a Collector invocation is intercepted mid-scan, the window of opportunity is limited.
- **Read-only by default.** The recommended IAM policy is `arn:aws:iam::aws:policy/ReadOnlyAccess`. The Collector cannot mutate customer resources — only enumerate them. The full list of 23 read-only actions it uses is documented in section 5.3.10.

> The Customer IAM Role is created and owned entirely by the tenant. The SaaS Provider only knows the Role ARN. Section 5.4 walks through the on-boarding flow where the customer pastes the Role ARN into the dashboard.

---

## 3. Automated Scanning & AI Analysis Flow

**Figure 3 - Automated Scanning & AI Analysis sequence (EventBridge → Collector → STS → DynamoDB → Bedrock → SNS):**

<img src="/aws-ojt-workshop-ja/images/5.3-Architecture-design/automated_scanning_ai_analysis_flow.png?v=2026-08-01-r1" alt="Automated Scanning and AI Analysis sequence diagram — EventBridge triggers the Collector Lambda every hour, the Collector fetches active projects from DynamoDB, assumes the customer IAM Role via STS, audits the target AWS account, stores raw resources in DynamoDB, then sends a Prompt to Amazon Bedrock (Claude 3 Haiku) for AI analysis. Critical risks are published to SNS for email alerts" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**How the end-to-end hourly scan works:**

The full scan + AI analysis pipeline runs on a fixed hourly cadence (`rate(1 hour)` declared in `template.yaml` and configurable in the EventBridge console). For each active project, the Collector repeats the same six-stage pipeline:

| Stage | Component | What happens |
|-------|-----------|--------------|
| 1. **Trigger** | Amazon EventBridge | Fires the `CollectorFunction` on `rate(1 hour)`. The trigger payload is the JSON `{}` event (no manual invocation needed). |
| 2. **Project lookup** | Collector Lambda → DynamoDB `ai-advisor-projects` | Reads every row with `SK = METADATA` to get the list of active tenants. Each row carries `project_id`, `role_arn`, `region`, and `project_name`. |
| 3. **Cross-account assume** | Collector → AWS STS → Customer IAM Role | For each project, calls `sts:AssumeRole(RoleArn=project.role_arn, RoleSessionName='CollectorSession')`. Receives `AccessKeyId`, `SecretAccessKey`, `SessionToken` valid for 1 hour. See section 5.3.2 for the full delegation flow. |
| 4. **Resource enumeration** | Collector → boto3 (EC2 / S3 / IAM / Lambda / CloudWatch) | Builds a fresh `boto3.Session` from the temp credentials and runs 23 read-only API calls (the full list is in section 5.3.10). Result is a JSON inventory. |
| 5. **Persist raw resources** | Collector → DynamoDB `ai-advisor-resources` | Writes each resource as `(project_id, resource_id)` with `resource_type`, `collected_at`, and `raw_data`. The `resource_type-index` GSI lets the dashboard query "all S3 buckets across all projects" without scanning. |
| 6. **AI analysis** | Collector → Amazon Bedrock (Claude 3 Haiku) | Builds a prompt that bundles the raw inventory with a structured instruction: *"For each resource, identify Security, Cost, and Performance risks. Return JSON with severity (CRITICAL/HIGH/MEDIUM/LOW), category, title, description, and recommendation."* Bedrock returns the parsed JSON response. |
| 7. **Persist insights** | Collector → DynamoDB `ai-advisor-insights` | Writes each insight as `(project_id, insight_id)` keyed by severity for fast filtering on the dashboard. |
| 8. **Alert routing (optional)** | Collector → Amazon SNS | If any insight is `severity = CRITICAL`, the Collector publishes a JSON message to the `ai-advisor-alerts` SNS topic, which fans out an email to the configured `AlertEmail` SAM parameter. |

**Why this design works for AI-driven auditing:**

- **One pass collects everything; AI does the synthesis.** The Collector is intentionally *dumb* — it does not try to reason about each resource. It only enumerates and persists. All security / cost / performance reasoning happens in a single Bedrock call, where Claude 3 Haiku has full context across all resources in one prompt.
- **Idempotent and resilient.** Each scan re-writes the resource rows keyed by `(project_id, resource_id)`. A failed mid-scan Lambda does not corrupt the table; the next hourly scan overwrites cleanly.
- **Bounded cost.** Bedrock is called once per project per hour. With `ai-advisor-resources` PAY_PER_REQUEST and Bedrock pay-per-token, idle tenants cost exactly $0.
- **Auditable history.** Because every resource and every insight is timestamped in DynamoDB, you can graph cost/security trends over time by querying the GSI.

> The Collector Lambda's 23-action IAM policy is documented in section 5.3.10; the EventBridge + SNS configuration is documented in section 5.3.7.

---

## 4. DynamoDB NoSQL Multi-Table Design

The application persists data across **four dedicated DynamoDB tables** (one table per entity). Although every table shares `project_id` as the partition key to guarantee strict tenant isolation, the design is intentionally *not* a single-table layout — the four entities have different access patterns, secondary indexes, and attribute schemas, so a multi-table layout keeps each table small and fast. A single-table layout is documented in section 5.3.6 as a comparison point but is *not* what the production template deploys.

**Figure 4 - DynamoDB Multi-Table Entity-Relationship diagram (4 tables, all sharing `project_id` as Partition Key for tenant isolation):**

<img src="/aws-ojt-workshop-ja/images/5.3-Architecture-design/dynamodb_singletable_design.png?v=2026-08-01-r2" alt="DynamoDB Multi-Table Entity-Relationship diagram — Four dedicated tables (PROJECTS, RESOURCES, INSIGHTS, ALERTS) all sharing project_id as Partition Key for tenant isolation. PROJECTS table (PK: project_id, SK: sk) is the root entity holding customer-project metadata; RESOURCES table (PK: project_id, SK: resource_id) stores raw AWS resource snapshots (EC2, S3, IAM, Lambda, CloudWatch) collected by the Collector Lambda; INSIGHTS table (PK: project_id, SK: insight_id) stores AI-generated recommendations produced by Bedrock Claude 3 Haiku; ALERTS table (PK: project_id, SK: alert_id) stores critical-risk notifications published to the SNS Topic. RESOURCES additionally has a GSI resource_type-index (HASH: resource_type, RANGE: collected_at) for cross-project queries by resource type. KEY POINT: This is a Multi-Table design (4 dedicated tables) NOT single-table; tenant isolation is enforced via project_id as the common partition key." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Entity relationships in plain text:**

- **One project → many resources** — Each row in `ai-advisor-projects` owns many rows in `ai-advisor-resources`, one per scanned AWS resource (EC2 instance, S3 bucket, IAM role, Lambda function, CloudWatch metric, …).
- **One project → many insights** — Each project accumulates many rows in `ai-advisor-insights`, one per AI-generated finding (security risk, cost optimisation, performance bottleneck).
- **One project → many alerts** — A subset of the insights that hit `severity = CRITICAL` gets replicated to `ai-advisor-alerts` so the dashboard can show a separate alert feed and the SNS pipeline has a clean target table.
- **Cross-project resource queries** — The `ai-advisor-resources` table carries a Global Secondary Index called `resource_type-index` (PK: `resource_type`, SK: `collected_at`). This GSI lets the dashboard answer "show me all S3 buckets across every project" without scanning every project's partition.

**Why multi-table instead of single-table:**

| Concern | Multi-table (this project) | Single-table |
|---------|----------------------------|--------------|
| **Per-entity access patterns** | Each table fits its own query pattern (e.g. resources need a GSI on `resource_type`, insights do not). | One table must encode every access pattern via overloaded keys; harder to reason about. |
| **Per-table IAM** | `DynamoDBCrudPolicy` can be scoped per-table (e.g. `ResourcesFunction` only has `DynamoDBReadPolicy` on `ai-advisor-resources`). | A single table requires broader, less granular IAM. |
| **Hot-partition risk** | Only `ai-advisor-resources` is likely to be hot; the others stay cold. | A single table concentrates write traffic on one logical partition. |
| **Cost on PAY_PER_REQUEST** | Idle cost is $0 per table — same as single-table but easier to forecast. | Same per-item cost. |
| **Onboarding cognitive load** | New developers can reason about one entity at a time. | Requires understanding the full key-encoding scheme up front. |

**Table inventory (full detail):**

| # | Table | Partition Key | Sort Key | GSI | Holds |
|---|-------|---------------|----------|-----|-------|
| 1 | ai-advisor-projects | project_id (S) | sk (S) | - | Project metadata (name, role_arn, region, owner) |
| 2 | ai-advisor-resources | project_id (S) | resource_id (S) | resource_type-index | Raw scanned resources (EC2, S3, IAM, Lambda, CloudWatch) |
| 3 | ai-advisor-insights | project_id (S) | insight_id (S) | - | AI-generated security / cost / performance insights |
| 4 | ai-advisor-alerts | project_id (S) | alert_id (S) | - | Critical-risk alerts that triggered an SNS email |

- **PROJECTS:** `PK: project_id`, `SK: sk` — root entity, one row per project
- **RESOURCES:** `PK: project_id`, `SK: resource_id` — raw scanned AWS resources per project
- **INSIGHTS:** `PK: project_id`, `SK: insight_id` — AI-generated security/cost/performance insights per project
- **ALERTS:** `PK: project_id`, `SK: alert_id` — critical-risk alerts that published an SNS email per project

This design provides strict tenant isolation (`project_id` Partition Key on every table) and lets each entity use the attribute schema and access pattern that fits it best — e.g. only `ai-advisor-resources` carries the `resource_type-index` GSI for cross-project queries by resource type. See section 5.3.6 for the full table-by-table inventory.

> **Region note:** All four DynamoDB tables are deployed in the **same region** as the rest of the SAM stack (`AWS::Region` resolves to the deployment region, e.g. `ap-southeast-1`). The `boto3` client in `backend/shared/db.py` creates its DynamoDB resource with `region_name=os.environ.get("AWS_REGION", "ap-southeast-1")` — so the code default is `ap-southeast-1` but the SAM parameter always overrides it with the stack's actual region. **Amazon Bedrock** sits in a *different* region (`us-east-1` by default for Claude 3 Haiku) and is configured separately in `template.yaml` under the `Environment.BedrockRegion` variable. The Bedrock region is decoupled from the DynamoDB region on purpose — Bedrock is only available in a small set of AWS regions.

---

## 5. End-to-End Architecture (Reference PNG)

The PNG diagram below consolidates every AWS service in the system, organized into 3 security boundaries (Client, Provider Backend, Customer Target Account) with labelled arrows for all primary request flows:

**Figure 5 - End-to-End Architecture (3 security boundaries + 19 AWS services):**

<img src="/aws-ojt-workshop-ja/images/5.3-Architecture-design/detailed_architecture.png?v=2026-08-01-r4" alt="Reference end-to-end architecture with FLOW SUMMARY (11 numbered steps) and 3 security boundaries: Client Frontend (React 19 Dashboard, S3+CloudFront stack, Cognito JWT, API Gateway), SaaS Provider Backend (SIX Lambda functions split into FIVE specialized API Handlers — projects-api, resources-api, insights-api, chat-api, alerts-api — and ONE Collector Lambda triggered by EventBridge schedule rate(1 hour); Bedrock Claude 3 Haiku; SNS alerts; DynamoDB Multi-Table with 4 dedicated tables + 1 GSI resource_type-index), and Customer Target AWS Accounts (IAM Role AIAdvisorAuditRole, STS AssumeRole, EC2, S3, IAM, Lambda, CloudWatch). The 11 numbered flow steps are: (1) browser requests dashboard over HTTPS; (2) CloudFront+S3 serve React bundle; (3) Cognito issues JWT after login; (4) API Gateway receives REST call with JWT; (5) API Handler Lambda executes with DynamoDB read/write; (6) Collector Lambda triggers (via EventBridge OR via /sync API invocation); (7) Collector queries DynamoDB PROJECTS for active customers; (8) Collector calls sts:AssumeRole to get temp credentials in target account; (9) Collector uses boto3 to read 23 AWS read-actions (EC2/S3/IAM/Lambda/CloudWatch); (10) Collector writes raw data to DynamoDB RESOURCES + calls Bedrock Claude 3 Haiku for analysis + writes insights + publishes critical-risk alerts to SNS. Solid arrows denote intra-account data flows; dashed red arrows denote cross-account sts:AssumeRole delegation from Collector Lambda to Customer IAM Role." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

> **Reading guide:**
> - **Row 1 (Client):** Browser → CloudFront → S3 static SPA → Cognito issues JWT → API Gateway validates JWT on every request.
> - **Row 2 (Backend):** API Gateway routes to one of 5 API Lambdas (projects, resources, insights, chat, alerts). EventBridge schedule (1 hour) triggers the Collector Lambda, writes to DynamoDB, calls Bedrock for AI analysis, and publishes SNS if a critical risk is detected.
> - **Row 3 (Customer):** The Collector Lambda calls `sts:AssumeRole` against the customer's trusted IAM Role, then uses boto3 to enumerate EC2 / S3 / IAM / etc. configuration across regions.

---

## 6. DynamoDB Tables (4 Tables + 1 GSI)

The backend persists data across **four DynamoDB tables**, all on PAY_PER_REQUEST billing mode to keep idle cost at $0:

| # | Table Name | Partition Key | Sort Key | GSI | Holds |
|---|---|---|---|---|---|
| 1 | ai-advisor-projects | project_id (S) | sk (S) | - | Project metadata (name, role_arn, region, owner) |
| 2 | ai-advisor-resources | project_id (S) | resource_id (S) | resource_type-index (PK: resource_type, SK: collected_at) | Raw scanned resources (EC2, S3, IAM, Lambda, CloudWatch) |
| 3 | ai-advisor-insights | project_id (S) | insight_id (S) | - | AI-generated security / cost / performance insights |
| 4 | ai-advisor-alerts | project_id (S) | alert_id (S) | - | Critical-risk alerts that triggered an SNS email |

The resource_type-index GSI allows the dashboard to query, for example, 'all S3 buckets across all projects' without a full table scan.

---

## 7. EventBridge Schedule and SNS Alert Pipeline

- The **EventBridge rule** is declared inline in template.yaml with Schedule: rate(1 hour) and Enabled: true. To change cadence, edit the rule and redeploy the stack.
- The **SNS topic** i-advisor-alerts is created with an email subscription. Update the AlertEmail SAM parameter if you want a different recipient.

> **Cross-project query strategy with `resource_type-index` GSI:** The single GSI on `ai-advisor-resources` is deliberately designed for **cross-project queries by resource type**. The base table's primary key (`project_id`, `resource_id`) is optimised for "all resources of project X" — that is the *intra-project* query. But the dashboard also needs to answer the *cross-project* query "show me every S3 bucket across every project" (e.g., for a global misconfiguration sweep). Without the GSI, that query would require a full `Scan` of `ai-advisor-resources`. With the GSI, the same query is a `Query` against `resource_type-index` with `KeyConditionExpression = "resource_type = :t"`, which is O(matches) instead of O(table). The trade-off is duplicated writes (each resource is written once to the base table + indexed under `resource_type + collected_at` on the GSI), but at `PAY_PER_REQUEST` with the small resource volume per project, the cost is negligible compared to the query-latency win.

---

## 8. Cognito User Pool and API Gateway Authorizer

| Component | CloudFormation Resource | Purpose |
|---|---|---|
| AdvisorUserPool | AWS::Cognito::UserPool | Holds end-user identities (email username) |
| AdvisorUserPoolClient | AWS::Cognito::UserPoolClient | Frontend SPA client (no secret, public flows) |
| AdvisorApi.Auth | AWS::Serverless::Api | JWT authorizer bound to User Pool ARN |
| CognitoAuthorizer | API Gateway Authorizer | Validates the Authorization: Bearer <JWT> header on every API call |

All 11 routes are protected by CognitoAuthorizer - anonymous requests get HTTP 401.

---

## 9. API Gateway Throttling and Quota

The AdvisorUsagePlan resource enforces the following limits on the prod stage:

| Setting | Value |
|---|---|
| Rate limit (steady) | **100 requests/second** |
| Burst limit | **50** |
| Monthly quota | **1000 requests/month** |

{{% notice info %}}The 1000 req/month quota is sized for a **single workshop author + a few testers**. For multi-tenant SaaS production, raise the quota (or remove it) and rely on per-tenant throttling via API keys.{{% /notice %}}

---

## 10. Collector Lambda IAM Permissions (23 Actions)

The CollectorFunction is granted Resource: '*' for 23 AWS actions in seven service groups. This is the *minimum* set required to read EC2/S3/IAM/Lambda/CloudWatch across all regions of a target account:

| Service | Actions | Why |
|---|---|---|
| EC2 | DescribeInstances, DescribeInstanceStatus, DescribeSecurityGroups | Inventory + utilization |
| S3 | ListAllMyBuckets, GetBucketAcl, GetBucketPublicAccessBlock, GetBucketLocation | Public-access risk detection |
| IAM | ListRoles, ListAttachedRolePolicies, ListRolePolicies, ListUsers, ListMFADevices, ListAccessKeys, GetLoginProfile | Privilege hygiene |
| Lambda | ListFunctions, GetFunctionConfiguration | Cold-start + runtime audit |
| CloudWatch | GetMetricStatistics, ListMetrics, GetMetricData, DescribeAlarms | 7-day performance baseline |
| STS | AssumeRole | Cross-account delegation itself |
| Bedrock | InvokeModel, InvokeModelWithResponseStream | AI insight generation |

The trust policy of the customer's AIAdvisorAuditRole must allow sts:AssumeRole from the SaaS provider account (see section 5.4 for the JSON trust policy).

---

## Section Summary

This architecture combines four DynamoDB tables, one EventBridge schedule, one SNS topic, one Cognito User Pool, six Lambda functions, and one API Gateway with Cognito JWT auth - all deployed via a single SAM template (`template.yaml`). Cross-account auditing is achieved with sts:AssumeRole and zero long-lived credentials are stored on the SaaS side.
