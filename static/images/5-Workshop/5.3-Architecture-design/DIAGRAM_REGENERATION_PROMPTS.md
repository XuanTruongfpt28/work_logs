# 🎨 6 Prompts chi tiết để regenerate Diagram Workshop

> **File nguồn truth:** `d:\nhatpm\aws-advisor\backend\template.yaml` (đã đọc)
> **File nguồn secondary:** `d:\nhatpm\aws-advisor\backend\api/`, `d:\nhatpm\aws-advisor\backend\collector/`, `d:\nhatpm\aws-advisor\backend\template.yaml`
> **Ngày tạo:** 2026-08-01
> **Mục đích:** Thay thế các diagram đang hiển thị "Single-Table Design" + "3 Lambda" (sai) bằng kiến trúc thật "Multi-Table (4 tables + 1 GSI)" + "6 Lambda (5 API + 1 Collector)"

---

## Source-of-truth (dùng chung cho mọi prompt)

### Lambda handlers (file:handler thực tế)

| Function Name (CF) | Handler path | Table access | API Routes | Bedrock | SNS |
|---|---|---|---|---|---|
| `ai-advisor-projects-api` | `api.projects.lambda_handler` | CRUD trên 4 tables + Invoke Collector | 5 (GET, POST, GET/{id}, DELETE/{id}, POST/{id}/sync) | — | — |
| `ai-advisor-resources-api` | `api.resources.lambda_handler` | Read `resources` | 2 (GET /{project_id}/resources, GET /{project_id}/resources/{resource_id}) | — | — |
| `ai-advisor-insights-api` | `api.insights.lambda_handler` | CRUD `insights`, CRUD `alerts`, Read `resources` | 2 (GET /{project_id}/insights, POST /{project_id}/insights/generate) | ✅ InvokeModel | ✅ Publish |
| `ai-advisor-chat-api` | `api.chat.lambda_handler` | Read `resources`, Read `insights` | 1 (POST /{project_id}/chat) | ✅ InvokeModel | — |
| `ai-advisor-alerts-api` | `api.alerts.lambda_handler` | Read `alerts` | 1 (GET /{project_id}/alerts) | — | — |
| `ai-advisor-collector` | `collector.main.lambda_handler` | CRUD 4 tables + Publish SNS | (không có API endpoint - trigger bởi EventBridge) | ✅ InvokeModel | ✅ Publish |

### DynamoDB tables (Multi-Table, KHÔNG phải Single-Table)

| Table Name | PK | SK | GSI | Mục đích |
|---|---|---|---|---|
| `ai-advisor-projects` | `project_id` (S) | `sk` (S) | — | Root entity: metadata customer project |
| `ai-advisor-resources` | `project_id` (S) | `resource_id` (S) | `resource_type-index` (HASH=`resource_type`, RANGE=`collected_at`) | Raw AWS resources snapshot |
| `ai-advisor-insights` | `project_id` (S) | `insight_id` (S) | — | AI-generated insights |
| `ai-advisor-alerts` | `project_id` (S) | `alert_id` (S) | — | Critical risk alerts |

### Stack name (in SAM outputs)
`ai-aws-advisor-backend` (theo `5.4-Deployment-strategy/_index.md`)
Region: `us-east-1`
Account ID: mask as `XXXXXXXXXXXX`

---

## PROMPT 1: `5.3-Architecture-design/high_level_architecture.png`

**File path đích:** `d:\nhatpm\fcj-workshop\static\images\5.3-Architecture-design\high_level_architecture.png?v=2026-08-01-r2`
**Alt text cũ:** "High-Level Architecture diagram showing three independent security boundaries..."
**Kích thước:** 1600×900 px (hoặc 1200×675)
**Style:** Flat, professional, AWS architecture diagram style, color zones, Chinese-friendly typography

### Prompt (tiếng Anh - cho AI image generator)

```
Design a high-level AWS architecture diagram in flat, professional style suitable for a technical workshop documentation. The diagram is titled "AI AWS Advisor - High-Level Reference Architecture" at the top center in bold dark blue text.

LAYOUT: 3 independent security zones arranged horizontally, separated by a thin dashed vertical line labeled "Security Boundary" at each gap.

ZONE 1 - CLIENT FRONTEND (left, light blue background #dbeafe):
- Header label: "Client Frontend (Browser)" in bold
- Inside, top-down:
  - Box: "Browser User" (gray icon)
  - CloudFront + S3 hosting (CDN edge icon)
  - Amazon Cognito User Pool ai-advisor-user-pool (lock icon)
  - React 19 Dashboard SPA (orange React logo)
  - Tech labels: TanStack React Query, Recharts, Tailwind CSS

ZONE 2 - SAAS PROVIDER BACKEND (center, light purple background #e9d5ff):
- Header label: "SaaS Provider Backend (Serverless)" in bold
- Inside, top-down split into 3 layers:
  - API LAYER:
    - Amazon API Gateway (REST, 11 routes)
    - Cognito JWT Authorizer
    - 5 API Lambda Functions (each in a separate rounded box, color #c084fc):
      1. ai-advisor-projects-api (5 routes: list, create, get, delete, sync)
      2. ai-advisor-resources-api (2 routes: list, get)
      3. ai-advisor-insights-api (2 routes: list, generate)
      4. ai-advisor-chat-api (1 route: chat)
      5. ai-advisor-alerts-api (1 route: list)
  - DATA LAYER (below API layer):
    - Amazon DynamoDB (Multi-Table) - 4 dedicated tables (color #059669):
      - ai-advisor-projects (PK: project_id, SK: sk)
      - ai-advisor-resources (PK: project_id, SK: resource_id + GSI resource_type-index)
      - ai-advisor-insights (PK: project_id, SK: insight_id)
      - ai-advisor-alerts (PK: project_id, SK: alert_id)
    - Note label: "Multi-Table NoSQL | 4 tables + 1 GSI | tenant isolation via project_id"
  - AI LAYER (right side):
    - Amazon Bedrock (purple #a21caf)
    - Model: anthropic.claude-3-haiku-20240307-v1:0
  - AUTOMATION (bottom):
    - Amazon EventBridge rule: rate(1 hour)
    - Arrow down to Collector Lambda
    - Collector Lambda: ai-advisor-collector (color #c084fc)
    - Amazon SNS Topic ai-advisor-alerts with email subscription

ZONE 3 - CUSTOMER TARGET AWS ACCOUNTS (right, light amber background #fef3c7):
- Header label: "Customer Target AWS Accounts" in bold
- Inside:
  - IAM Role: AIAdvisorAuditRole (Read-Only access)
  - Trust policy: allows SaaS Provider account to AssumeRole
  - AWS STS validates trust policy & returns temporary credentials
  - AWS Resources to audit (multi-account):
    - Amazon EC2 (instances, security groups)
    - Amazon S3 (buckets, ACLs, public access)
    - IAM (users, MFA, access keys)
    - AWS Lambda (functions)
    - CloudWatch (metrics, alarms)

ARROWS:
- Solid arrows for intra-account data flow
- Dashed arrows for cross-account sts:AssumeRole from Collector Lambda to Customer IAM Role
- Always show direction with arrowheads

COLOR PALETTE:
- Background: white with zone tints
- Text: dark gray #1f2937
- Frontend zone: blue #dbeafe
- Backend zone: purple #e9d5ff
- Customer zone: amber #fef3c7
- Lambda boxes: #c084fc text white
- DynamoDB: green #059669
- Bedrock: purple #a21caf
- SNS: red #dc2626
- EventBridge: orange #b45309

TYPOGRAPHY: Use Segoe UI or Arial. Title 26pt bold, zone headers 16pt bold, service labels 12pt, technical details 10pt.

CRITICAL: DO NOT use the words "Single-Table" or "3 Lambda" anywhere. The system is Multi-Table (4 dedicated tables) and 6 Lambda functions (5 API + 1 Collector).

Output as PNG image at 1600x900 resolution with high contrast and clear separation between zones.
```

### Alt text mới (copy cho `_index.md`)

```
Sơ đồ kiến trúc tổng quan hiển thị ba ranh giới bảo mật độc lập: (1) Vùng Client Frontend màu xanh dương với React 19 Dashboard SPA, TanStack React Query, Recharts Visualization, CloudFront + S3 hosting, Amazon Cognito JWT, và Browser User Flow; (2) Vùng SaaS Provider Backend màu tím với API Gateway (REST, 11 routes, Cognito JWT Authorizer, quota 1000/tháng, burst 50, rate 100/s), năm API Lambda Functions (projects, resources, insights, chat, alerts), Collector Lambda (quét mỗi giờ, STS AssumeRole, 23 AWS read actions), Amazon EventBridge rate(1 hour), Amazon Bedrock Claude 3 Haiku, bốn bảng DynamoDB (ai-advisor-projects, ai-advisor-resources, ai-advisor-insights, ai-advisor-alerts) + 1 GSI, Amazon SNS Topic ai-advisor-alerts với email subscription; (3) Vùng Customer Target AWS Account màu hổ phách với Read-Only IAM Role AIAdvisorAuditRole + trust policy, AWS STS xác thực trust policy và trả về temporary credentials, các AWS resources audit (EC2, S3, IAM, Lambda, CloudWatch). Mũi tên liền thể hiện luồng nội tài khoản; mũi tên đứt nét thể hiện luồng cross-account sts:AssumeRole.
```

Version bump: `?v=2026-08-01-r2` → `?v=2026-08-01-r2` (giữ nguyên) hoặc tăng nếu thay đổi nhiều.

---

## PROMPT 2: `5.3-Architecture-design/dynamodb_singletable_design.png` ✏️

**File path đích:** `d:\nhatpm\fcj-workshop\static\images\5.3-Architecture-design\dynamodb_singletable_design.png` (giữ nguyên tên file, đổi alt text)
**ĐỀ XUẤT ĐỔI TÊN FILE** → `dynamodb_multitable_design.png` cho đúng nội dung (cần tạo file mới + xóa file cũ + update reference trong 2 file _index.md)

**Kích thước:** 1400×800 px
**Style:** ER diagram (Entity-Relationship) style, 4 tables arranged in a 2x2 grid or 4-row stack, with arrows showing relationships via `project_id`

### Prompt

```
Design a DynamoDB Multi-Table Entity-Relationship diagram for a technical workshop. The diagram shows the database schema of the AI AWS Advisor application.

TITLE: "DynamoDB Multi-Table Data Model" in bold dark blue text at top.

CENTRAL CONCEPT (center top): Show "project_id (Partition Key)" as the central tenant isolation key in a circle/icon, with 4 arrows extending outward to 4 tables.

4 DYNAMODB TABLES (arranged in 2x2 grid or row):

TABLE 1: ai-advisor-projects (top-left or top, color #059669 border)
- Header: "PROJECTS (Root Entity)" in bold
- Partition Key: project_id (String)
- Sort Key: sk (String)
- Attributes shown:
  - project_id (S), sk (S)
  - name (S), description (S)
  - customer_account_id (S)
  - role_arn (S)
  - status (S) - active/paused
  - created_at (S), updated_at (S)
- Purpose label: "Root entity: customer project metadata"

TABLE 2: ai-advisor-resources (top-right or 2nd row, color #059669 border)
- Header: "RESOURCES (AWS Resource Snapshots)"
- Partition Key: project_id (String)
- Sort Key: resource_id (String)
- GSI: resource_type-index (HASH: resource_type, RANGE: collected_at)
- Attributes: project_id, resource_id, resource_type, resource_arn, region, config(JSON), collected_at, last_audit_status
- Purpose label: "Raw AWS resources from Customer account (EC2, S3, IAM, Lambda, CloudWatch)"

TABLE 3: ai-advisor-insights (bottom-left or 3rd row, color #059669 border)
- Header: "INSIGHTS (AI Analysis Results)"
- Partition Key: project_id (String)
- Sort Key: insight_id (String)
- Attributes: project_id, insight_id, severity (low/medium/high/critical), category (cost/security/performance/reliability), summary, recommendation, generated_at, model_id
- Purpose label: "AI-generated recommendations from Bedrock Claude 3 Haiku"

TABLE 4: ai-advisor-alerts (bottom-right or 4th row, color #059669 border)
- Header: "ALERTS (Critical Risk Notifications)"
- Partition Key: project_id (String)
- Sort Key: alert_id (String)
- Attributes: project_id, alert_id, severity, title, description, related_resource_id, status (open/acknowledged/resolved), triggered_at
- Purpose label: "Critical risks published to SNS for email alerts"

RELATIONSHIPS (dashed arrows with labels):
- PROJECTS (1) → RESOURCES (N): "owns" (FK: project_id)
- PROJECTS (1) → INSIGHTS (N): "generates" (FK: project_id)
- PROJECTS (1) → ALERTS (N): "triggers" (FK: project_id)
- RESOURCES (1) → INSIGHTS (0..1): "analyzed in" (FK: project_id, resource_id)
- RESOURCES (1) → ALERTS (0..N): "causes" (FK: project_id, resource_id)

KEY CONCEPTS (bottom panel in light gray):
- "4 dedicated tables (NOT single-table design)"
- "Each table has its own primary key schema"
- "Common access pattern: Query by project_id (tenant isolation)"
- "1 GSI for cross-project queries by resource_type"

COLOR PALETTE: 
- Tables white background, #059669 border (AWS DynamoDB green)
- PK/SK rows highlighted in light green
- GSI rows highlighted in light yellow
- Project_id column highlighted in light blue (to show tenant isolation)

CRITICAL: Title MUST say "Multi-Table" not "Single-Table". DO NOT show a single table with multiple entity types. Show 4 distinct tables.

Output as PNG at 1400x800, high contrast, suitable for documentation.
```

### Alt text mới

```
Sơ đồ Entity-Relationship DynamoDB Multi-Table — Bốn table chuyên biệt (PROJECTS, RESOURCES, INSIGHTS, ALERTS) đều dùng chung project_id làm Partition Key cho cách ly tenant. Table PROJECTS (PK: project_id, SK: sk) là root entity; table RESOURCES (PK: project_id, SK: resource_id) thuộc về một project; table INSIGHTS (PK: project_id, SK: insight_id) được sinh ra từ một project; table ALERTS (PK: project_id, SK: alert_id) được tạo cho rủi ro nghiêm trọng. RESOURCES có thêm GSI resource_type-index cho truy vấn cross-project theo resource type. QUAN TRỌNG: Hệ thống dùng Multi-Table (4 bảng chuyên biệt), KHÔNG phải Single-Table Design.
```

### Update Markdown reference

Trong `content/5-Workshop/5.3-Architecture-design/_index.md` line 115 và `_index.vi.md` line 115, đổi:
- `dynamodb_singletable_design.png` → `dynamodb_multitable_design.png`
- Bump version: `?v=2026-08-01-r1` → `?v=2026-08-01-r2`

---

## PROMPT 3: `5.3-Architecture-design/detailed_architecture.png`

**File path đích:** `d:\nhatpm\fcj-workshop\static\images\5.3-Architecture-design\detailed_architecture.png?v=2026-08-01-r4`
**Alt text cũ:** "Reference end-to-end architecture with FLOW SUMMARY (1-11) and 3 security boundaries..."
**Kích thước:** 1800×1100 px (lớn vì phải show flow summary chi tiết)
**Style:** Detailed reference architecture with numbered flow steps

### Prompt

```
Design a detailed end-to-end reference architecture diagram for the AI AWS Advisor system. This is the most comprehensive diagram of the workshop - it should show the full FLOW SUMMARY with 11 numbered steps.

TITLE: "AI AWS Advisor - End-to-End Reference Architecture" in bold dark blue text at top.

OVERALL LAYOUT: 3 vertical zones (Frontend, Backend, Customer Account) separated by dashed trust boundaries, with horizontal FLOW SUMMARY numbering at the bottom.

ZONE 1 - CLIENT FRONTEND (left, blue background):
- Browser User → CloudFront + S3 → React 19 Dashboard → Cognito Login (JWT)
- React internals: TanStack Query, Recharts, Tailwind CSS

ZONE 2 - SAAS PROVIDER BACKEND (center, purple background):
Top section - API Layer:
- Amazon API Gateway (REST API, 11 routes, Cognito JWT Authorizer)
  - Routes listed: /projects, /projects/{id}, /projects/{id}/sync, /projects/{id}/resources, /projects/{id}/resources/{id}, /projects/{id}/insights, /projects/{id}/insights/generate, /projects/{id}/chat, /projects/{id}/alerts
- 5 API Lambda Functions (each as a separate box with name + handler):
  1. ai-advisor-projects-api (handler: api.projects.lambda_handler)
  2. ai-advisor-resources-api (handler: api.resources.lambda_handler)
  3. ai-advisor-insights-api (handler: api.insights.lambda_handler)
  4. ai-advisor-chat-api (handler: api.chat.lambda_handler)
  5. ai-advisor-alerts-api (handler: api.alerts.lambda_handler)

Middle section - Data Layer:
- Amazon DynamoDB (Multi-Table) - 4 boxes with arrows:
  - ai-advisor-projects (PK: project_id, SK: sk)
  - ai-advisor-resources (PK: project_id, SK: resource_id) + GSI resource_type-index
  - ai-advisor-insights (PK: project_id, SK: insight_id)
  - ai-advisor-alerts (PK: project_id, SK: alert_id)
- Label: "Multi-Table NoSQL | 4 tables + 1 GSI"

Right section - AI/ML Layer:
- Amazon Bedrock (purple)
- Model: anthropic.claude-3-haiku-20240307-v1:0 (Claude 3 Haiku)

Bottom section - Automation:
- Amazon EventBridge rule (rate(1 hour))
- ↓ arrow to Collector Lambda
- Collector Lambda: ai-advisor-collector (handler: collector.main.lambda_handler)
- Amazon SNS Topic ai-advisor-alerts + email subscription

ZONE 3 - CUSTOMER ACCOUNT (right, amber background):
- IAM Role: AIAdvisorAuditRole (Read-Only)
- Trust policy allows SaaS Provider account
- AWS Resources to audit:
  - EC2 (instances, security groups)
  - S3 (buckets, ACLs)
  - IAM (users, MFA, keys)
  - Lambda (functions)
  - CloudWatch (metrics, alarms)

FLOW SUMMARY (numbered horizontal panel at bottom, 11 steps):
1. User opens browser → CloudFront serves React Dashboard
2. User authenticates → Cognito returns JWT
3. User clicks "Sync" → Projects API invokes Collector Lambda async
4. EventBridge triggers Collector every hour (cron)
5. Collector queries DynamoDB PROJECTS table for active projects
6. Collector calls sts:AssumeRole to get temp credentials in customer account
7. Collector uses boto3 to read EC2/S3/IAM/Lambda/CloudWatch via 23 read actions
8. Collector writes raw resources to DynamoDB RESOURCES table
9. Collector calls Bedrock Claude 3 Haiku with prompt for AI analysis
10. Bedrock returns insights → Collector writes to DynamoDB INSIGHTS table
11. Critical risks → Collector publishes to SNS Topic → email alert

ARROWS:
- Solid arrows for intra-account data flow
- Dashed arrows for cross-account (steps 6-7)
- Number labels (1-11) on each major arrow

COLOR PALETTE: Same as previous diagrams. Use zone tints for backgrounds.

CRITICAL: 
- DO NOT use "Single-Table" or "3 Lambda" anywhere
- Lambda count must be 6 (5 API + 1 Collector)
- DynamoDB must show 4 tables + 1 GSI
- MUST show 11 numbered steps in the FLOW SUMMARY

Output as PNG at 1800x1100 resolution.
```

### Alt text mới

```
Sơ đồ kiến trúc end-to-end tham chiếu với FLOW SUMMARY (1-11) và 3 ranh giới bảo mật: Client Frontend (React Dashboard, S3+CloudFront stack, Cognito JWT, API Gateway), SaaS Provider Backend (6 Lambda functions: 5 API Handler chuyên biệt cho projects/resources/insights/chat/alerts + 1 Collector Lambda được trigger bởi EventBridge schedule rate(1 hour), Bedrock Claude 3 Haiku, SNS alerts, 4 DynamoDB tables Multi-Table với 1 GSI resource_type-index) và Customer Target AWS Accounts (IAM Role AIAdvisorAuditRole, STS AssumeRole, EC2, S3, IAM, Lambda, CloudWatch). 11 bước flow: (1) browser → CloudFront, (2) Cognito JWT, (3) Projects API invoke Collector async, (4) EventBridge cron, (5) Collector query PROJECTS, (6) sts:AssumeRole, (7) boto3 đọc 23 read actions, (8) ghi RESOURCES, (9) Bedrock analysis, (10) ghi INSIGHTS, (11) SNS publish. Mũi tên liền thể hiện luồng nội tài khoản; mũi tên đứt nét thể hiện cross-account sts:AssumeRole.
```

---

## PROMPT 4: `2-Proposal/aws_advisor_architecture.png`

**File path đích:** `d:\nhatpm\fcj-workshop\static\images\2-Proposal\aws_advisor_architecture.png?v=2026-08-01-r3`
**Alt text cũ:** "AWS Architecture diagram of the AI AWS Advisor - Three independent zones..."
**Kích thước:** 1400×800 px
**Style:** Clean proposal-grade architecture diagram

### Prompt

```
Design a clean proposal-grade AWS architecture diagram for the AI AWS Advisor system. This is the main diagram shown in the project proposal documentation.

TITLE: "AI AWS Advisor - Reference Architecture" in bold dark blue text at top.

Same content as Prompt 1 (high_level_architecture.png) but more compact and proposal-friendly:
- 3 horizontal zones (Client Frontend, SaaS Backend, Customer Accounts)
- Detail level: medium (show services, not internal tech stack)
- Number of Lambda functions shown: 6 (5 API + 1 Collector)
- DynamoDB shown as 4 tables + 1 GSI
- All 23 IAM read actions grouped into "Read-Only Access" badge
- Include cost estimate: "$42.30/month" as a small badge

CRITICAL: 
- Lambda count = 6 (NOT 3)
- DynamoDB = Multi-Table 4 tables (NOT Single-Table)
- Show 5 API Lambda separately + 1 Collector Lambda

Output as PNG at 1400x800.
```

### Alt text mới

```
Sơ đồ kiến trúc tổng quan AI AWS Advisor - Ba vùng độc lập: (1) Client Frontend với React 19 Dashboard, (2) AI Advisor Backend gồm API Gateway (11 routes), sáu Lambda Handler (5 API Handler chuyên biệt: projects-api, resources-api, insights-api, chat-api, alerts-api + 1 Collector), DynamoDB Multi-Table (4 bảng ai-advisor-projects/resources/insights/alerts + 1 GSI resource_type-index), Hourly Scanning Collector Lambda, Bedrock Claude 3 Haiku, SNS, (3) Customer Target AWS Accounts với STS AssumeRole truy cập EC2/S3/IAM/Lambda/CloudWatch. Ước tính chi phí $42.30/tháng.
```

---

## PROMPT 5: `5.1-Workshop-overview/workshop_architecture.png`

**File path đích:** `d:\nhatpm\fcj-workshop\static\images\5.1-Workshop-overview\workshop_architecture.png?v=2026-08-01-r3`
**Alt text cũ:** "AI AWS Advisor High-Level Architecture diagram - Three independent zones..."
**Kích thước:** 1400×700 px
**Style:** Workshop overview (giống Proposal nhưng gọn hơn, là slide đầu tiên của workshop)

### Prompt

```
Design a clean workshop-overview AWS architecture diagram for the AI AWS Advisor. This is the first architecture diagram readers see when starting the workshop, so it should be visually appealing and clear.

TITLE: "AI AWS Advisor - Workshop Architecture Overview" in bold dark blue text at top.
SUBTITLE: "What we'll build in this workshop" in italic dark gray text.

CONTENT (same as Prompt 1 but slightly simplified):
- 3 zones with clear labels
- Service icons visible (AWS service icons style)
- Lambda count: 6 (5 API + 1 Collector)
- DynamoDB: 4 tables + 1 GSI
- Add a "tech stack summary" sidebar with: React 19, Python 3.12, AWS SAM, DynamoDB Multi-Table, Bedrock Claude 3 Haiku

Use a friendly color palette suitable for a workshop introduction (slightly more saturated than proposal).

CRITICAL: 
- No "Single-Table" anywhere
- No "3 Lambda" anywhere

Output as PNG at 1400x700.
```

### Alt text mới

```
Sơ đồ kiến trúc tổng quan AI AWS Advisor trong workshop - Ba vùng độc lập: (1) Client Frontend với React Dashboard, (2) AI Advisor Backend gồm API Gateway (11 routes), sáu Lambda Handler chuyên biệt (Projects API, Resources API, Insights API, Chat API, Alerts API + Collector Lambda), bốn bảng DynamoDB Multi-Table (ai-advisor-projects, ai-advisor-resources, ai-advisor-insights, ai-advisor-alerts) + 1 GSI, Hourly Scanning Collector Lambda, Bedrock Claude 3 Haiku, SNS, (3) Customer Target AWS Accounts với STS AssumeRole truy cập EC2/S3/IAM. Workshop xây dựng hệ thống này qua 8 modules từ Prerequisites đến Operations Cleanup.
```

---

## PROMPT 6: `1-Worklog/week8_system_architecture.png`

**File path đích:** `d:\nhatpm\fcj-workshop\static\images\1-Worklog\week8_system_architecture.png?v=2026-08-01-r2`
**Alt text cũ:** "High-level system architecture diagram - Three-row flow..."
**Kích thước:** 1400×800 px
**Style:** Blogger-friendly, simpler than workshop docs, focus on week 8 achievements

### Prompt

```
Design a simple, blog-style system architecture diagram for the "Week 8 Achievements" blog post. This is a worklog showcase, not a deep-dive reference.

TITLE: "AI AWS Advisor - System Architecture (Week 8)" in bold.
SUBTITLE: "Final Technical Achievement of My 8-Week Cloud Journey" in italic.

LAYOUT: Simpler than workshop diagrams, focus on the "aha moment" of the system.

3 ROWS (top-down flow):

ROW 1 (top, blue background):
- Frontend: React 19 + Vite + Tailwind (laptop icon)
- Backend: AWS API Gateway + 6 Lambda Functions (function icon)
- AI Engine: Amazon Bedrock Claude 3 Haiku (brain icon)
- Connected by horizontal arrows

ROW 2 (middle, purple background):
- Backend → Database: DynamoDB Multi-Table (4 tables: projects, resources, insights, alerts) - NO single-table
- AI Engine → Data Sources: AWS APIs (EC2, S3, IAM, Lambda, CloudWatch)

ROW 3 (bottom, green background):
- EventBridge Scheduler (rate 1 hour) → triggers Collector Lambda → scans Data Sources

KEY ACHIEVEMENTS (sidebar or badges):
- ✅ Multi-Table DynamoDB (4 tables + 1 GSI)
- ✅ 6 Lambda functions (5 API + 1 Collector)
- ✅ 11 API routes
- ✅ 23 AWS read actions
- ✅ Cross-account STS AssumeRole
- ✅ $42.30/month estimated cost

CRITICAL: 
- NO "Single-Table" anywhere
- NO "3 Lambda" anywhere
- Lambda count = 6 (NOT 3)
- Tone: achievement-celebrating, blog-style

Output as PNG at 1400x800.
```

### Alt text mới

```
Sơ đồ kiến trúc tổng quan hệ thống (Blog Week 8) - Luồng 3 hàng: (1) Frontend React 19 + Vite, Backend API Gateway + 6 Lambda (5 API + 1 Collector), AI Engine Amazon Bedrock kết nối bằng mũi tên ngang, (2) Backend kết nối xuống Database Amazon DynamoDB Multi-Table (4 bảng projects/resources/insights/alerts + 1 GSI), AI Engine kết nối xuống Data Sources AWS APIs (EC2, S3, IAM, Lambda, CloudWatch), (3) Amazon EventBridge Scheduler rate(1 hour) kích hoạt Collector Lambda quét Data Sources qua mũi tên xuống. Thành tựu Week 8: Multi-Table DynamoDB, 6 Lambda functions, 11 API routes, 23 AWS read actions, cross-account STS AssumeRole, $42.30/tháng.
```

---

## Summary Table - Files to Update

| # | File path | Version bump | Action |
|---|---|---|---|
| 1 | `5.3-Architecture-design/high_level_architecture.png` | `r1` → `r2` | Regenerate |
| 2 | `5.3-Architecture-design/dynamodb_singletable_design.png` → **`dynamodb_multitable_design.png`** | `r1` → `r2` | Rename + Regenerate |
| 3 | `5.3-Architecture-design/detailed_architecture.png` | `r3` → `r4` | Regenerate |
| 4 | `2-Proposal/aws_advisor_architecture.png` | `r2` → `r3` | Regenerate |
| 5 | `5.1-Workshop-overview/workshop_architecture.png` | `r2` → `r3` | Regenerate |
| 6 | `1-Worklog/week8_system_architecture.png` | `r1` → `r2` | Regenerate |

## Markdown files to update (alt text + image src)

| File | Lines to update |
|---|---|
| `content/5-Workshop/5.3-Architecture-design/_index.md` | Line 21, 115, 160 (alt text + src for #1, #2, #3) |
| `content/5-Workshop/5.3-Architecture-design/_index.vi.md` | Line 21, 115, 160 (alt text + src for #1, #2, #3) |
| `content/2-Proposal/_index.md` | Line 54 (alt text for #4) |
| `content/2-Proposal/_index.vi.md` | Line 52 (alt text for #4) |
| `content/5-Workshop/5.1-Workshop-overview/_index.md` | Line 17 (alt text for #5) |
| `content/5-Workshop/5.1-Workshop-overview/_index.vi.md` | Line 17 (alt text for #5) |
| `content/1-Worklog/1.8-Week8/_index.md` | Line 46 (alt text for #6) |
| `content/1-Worklog/1.8-Week8/_index.vi.md` | Line 47 (alt text for #6) |
