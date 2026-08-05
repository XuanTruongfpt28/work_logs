---
title: "Kiến trúc & Thiết kế"
date: 2026-05-01
weight: 3
chapter: false
pre: " <b> 5.3. </b> "
---

# Phần 5.3 - Kiến trúc & Thiết kế Kỹ thuật

Dự án **AI AWS Advisor** được phát triển trên 3 trụ cột kỹ thuật chính: **Kiến trúc Serverless**, **Bảo mật Zero-Trust**, và **Generative AI**.

---

## 1. Kiến trúc Tổng quan Hệ thống

Hệ thống phân chia ranh giới bảo mật thành 3 vùng độc lập, được minh họa trong sơ đồ kiến trúc bên dưới:

**Hình 1 - Kiến trúc Tổng quan (3 ranh giới bảo mật: Client Frontend / SaaS Provider Backend / Customer Target Account):**

<img src="/images/5.3-Architecture-design/high_level_architecture.png?v=2026-08-01-r2" alt="Sơ đồ kiến trúc tổng quan hiển thị ba ranh giới bảo mật độc lập: (1) Vùng Client Frontend màu xanh dương với React 19 Dashboard SPA, TanStack React Query, Recharts Visualization, CloudFront + S3 hosting, Amazon Cognito JWT, và Browser User Flow; (2) Vùng SaaS Provider Backend màu tím với API Gateway (REST, 11 routes, Cognito JWT Authorizer, quota 1000/tháng, burst 50, rate 100/s), SÁU Lambda Functions: NĂM API Handler chuyên biệt (projects-api, resources-api, insights-api, chat-api, alerts-api) và MỘT Collector Lambda (ai-advisor-collector, quét mỗi giờ rate(1 hour), STS AssumeRole, 23 AWS read actions trên EC2/S3/IAM/Lambda/CloudWatch), Amazon EventBridge rate(1 hour) kích hoạt Collector, Amazon Bedrock Claude 3 Haiku (anthropic.claude-3-haiku-20240307-v1:0) cho phân tích AI, DynamoDB Multi-Table (4 bảng chuyên biệt: ai-advisor-projects PK=project_id+SK=sk, ai-advisor-resources PK=project_id+SK=resource_id + GSI resource_type-index, ai-advisor-insights PK=project_id+SK=insight_id, ai-advisor-alerts PK=project_id+SK=alert_id), Amazon SNS Topic ai-advisor-alerts với email subscription cho critical-risk alerts; (3) Vùng Customer Target AWS Account màu hổ phách với Read-Only IAM Role AIAdvisorAuditRole + trust policy, AWS STS xác thực trust policy và trả về temp credentials, và customer AWS resources (EC2, S3, IAM, Lambda, CloudWatch). Mũi tên liền thể hiện luồng nội tài khoản (HTTPS REST với JWT, mỗi-1-giờ trigger, Bedrock prompt, critical-risk SNS publish, boto3 read API); mũi tên đứt nét màu đỏ thể hiện cross-account sts:AssumeRole delegation từ Collector Lambda sang Customer IAM Role, và đường temp-credentials trở về." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Sơ đồ này thể hiện:**

Sơ đồ được chia thành ba vùng màu tương ứng với ba AWS account / ranh giới bảo mật:

| # | Ranh giới | Màu | Chủ sở hữu | Mục đích |
|---|-----------|-----|------------|----------|
| 1 | **Client Frontend** (React 19 + Vite) | Xanh dương | Trình duyệt | Render dashboard, fetch data qua TanStack React Query, biểu đồ với Recharts, host trên CloudFront + S3, xác thực qua Amazon Cognito (JWT). |
| 2 | **SaaS Provider Backend** (Serverless Stack) | Tím | Tài khoản workshop này | Host API Gateway (11 REST routes), năm API Lambda function, một Collector Lambda theo lịch, Amazon EventBridge schedule, Amazon Bedrock (Claude 3 Haiku), bốn bảng DynamoDB + 1 GSI, và một Amazon SNS topic cho cảnh báo nghiêm trọng. |
| 3 | **Customer Target AWS Account** | Hổ phách | Mỗi tenant | Cấp một Read-Only IAM Role tin tưởng tài khoản SaaS Provider, và cho phép các resource EC2 / S3 / IAM / Lambda / CloudWatch được kiểm toán. |

**Ba quyết định thiết kế đáng chú ý:**

- **100 % Serverless phía Provider.** API Gateway + Lambda + DynamoDB + EventBridge + SNS nghĩa là không có EC2 instance nào phải vận hành; chi phí nhàn rỗi đúng bằng $0 vì cả bốn bảng DynamoDB dùng `PAY_PER_REQUEST`.
- **Không có customer credential cố định.** Mũi tên đứt nét đỏ xuyên qua ranh giới Provider ↔ Customer thể hiện `sts:AssumeRole` delegation — credentials tạm thời, scope trong một phiên kiểm toán, không bao giờ lưu xuống đĩa.
- **Tần suất mỗi giờ với AI xử lý phía trên.** EventBridge kích hoạt Collector Lambda mỗi giờ; raw inventory được lưu vào DynamoDB, sau đó một Prompt duy nhất được gửi tới Bedrock (Claude 3 Haiku) để phân tích Security / Cost / Performance. Rủi ro nghiêm trọng được chuyển sang SNS gửi email cảnh báo.

> **Hướng dẫn đọc sơ đồ:** Trong Hình 1, theo mũi tên liền màu xanh (User → API Gateway) để thấy một dashboard request di chuyển như thế nào; sau đó theo mũi tên đứt nét đỏ (Collector → STS → Temp Credentials → boto3 read API) để thấy một lần quét mỗi giờ xuyên qua tài khoản khách hàng ra sao.

### Quyết định thiết kế: 100% Serverless

Vận hành trên AWS Lambda, API Gateway, và DynamoDB loại bỏ chi phí hạ tầng EC2 24/7 cơ bản, mang lại chi phí nhàn rỗi bằng 0 và khả năng mở rộng tức thì.

---

## 2. Bảo mật Zero-Trust (Cross-Account Delegation)

Thay vì yêu cầu khách hàng cung cấp Access Key / Secret Key cố định (nguy cơ rò rỉ rất cao), hệ thống yêu cầu khách hàng cấp một Read-Only IAM Role tin tưởng tài khoản SaaS của chúng ta.

**Hình 2 - Luồng sequence Zero-Trust STS AssumeRole (Provider Lambda ↔ IAM Role Khách hàng qua STS):**

<img src="/images/5.3-Architecture-design/zero_trust_security_cross_account.png?v=2026-08-01-r2" alt="Sơ đồ sequence Zero-Trust STS AssumeRole — Collector Lambda của SaaS Provider gọi sts:AssumeRole, AWS STS xác thực trust policy của IAM Role khách hàng, trả về temporary credentials, sau đó Collector dùng credentials tạm thời để kiểm toán tài nguyên EC2 và S3 trong tài khoản AWS khách hàng" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Cách Zero-Trust Cross-Account Delegation hoạt động trong hệ thống này:**

| Bước | Tác nhân | Hành động |
|------|----------|-----------|
| 1 | **SaaS Provider (Collector Lambda)** | Gọi `sts:AssumeRole` với Role ARN của khách hàng được cung cấp khi tạo project. Trust policy phía khách hàng phải whitelist account ID của SaaS Provider (và tùy chọn một `ExternalId`). |
| 2 | **AWS STS** | Xác thực trust policy: kiểm tra calling principal khớp, kiểm tra `ExternalId` khớp (nếu có), và permission boundary (nếu có) được thỏa mãn. |
| 3 | **Customer IAM Role** | Nếu trust policy khớp, AWS STS cấp một **session token** với `AccessKeyId`, `SecretAccessKey`, và `SessionToken`, tất cả có hiệu lực **1 giờ** (`DurationSeconds=3600`). |
| 4 | **Collector Lambda** | Nhận temporary credentials và dùng chúng để build một `boto3.Session` mới cho tài khoản khách hàng. Từ đây, mọi `boto3.client('ec2')`, `boto3.client('s3')`, `boto3.client('iam')` được ký bằng session tạm thời. |
| 5 | **Audit APIs** | Collector liệt kê resource EC2 / S3 / IAM / Lambda / CloudWatch, đóng gói thành JSON, và ghi vào bảng `ai-advisor-resources` DynamoDB. |
| 6 | **Hết hạn** | Một giờ sau, temporary credentials tự động bị AWS thu hồi — lần quét tiếp theo sẽ cấp session mới. Không customer key cố định nào chạm vào hạ tầng của chúng ta. |

**Tại sao điều này quan trọng cho Zero-Trust:**

- **Không chia sẻ secret.** SaaS Provider không bao giờ thấy, lưu trữ, hay truyền Access Key / Secret Key cố định của khách hàng. Ngay cả khi database phía Provider bị breach toàn bộ cũng không rò rỉ được customer credentials vì chúng chưa từng tồn tại ở đó.
- **Customer kiểm soát blast radius.** Khách hàng tự chọn (a) principal nào được phép assume role, (b) role cấp quyền gì (thường là `ReadOnlyAccess`), và (c) có thêm `ExternalId` để chống *confused-deputy*. Khách hàng có thể thu hồi quyền bất cứ lúc nào bằng cách sửa trust policy hoặc xóa role.
- **Session có giới hạn thời gian.** Credentials tự hết hạn sau một giờ. Nếu một lần Collector bị chặn giữa chừng, cửa sổ cơ hội bị giới hạn.
- **Read-only mặc định.** IAM policy khuyến nghị là `arn:aws:iam::aws:policy/ReadOnlyAccess`. Collector không thể mutate resource khách hàng — chỉ liệt kê. Danh sách đầy đủ 23 read-only action được dùng có ở mục 5.3.10.

> IAM Role của khách hàng được tạo và sở hữu hoàn toàn bởi tenant. SaaS Provider chỉ biết Role ARN. Mục 5.4 sẽ đi qua luồng on-boarding nơi khách hàng paste Role ARN vào dashboard.

---

## 3. Luồng Quét Tự động & Phân tích Trí tuệ Nhân tạo

**Hình 3 - Luồng sequence Quét Tự động & Phân tích AI (EventBridge → Collector → STS → DynamoDB → Bedrock → SNS):**

<img src="/images/5.3-Architecture-design/automated_scanning_ai_analysis_flow.png?v=2026-08-01-r1" alt="Sơ đồ sequence Quét Tự động và Phân tích AI — EventBridge kích hoạt Collector Lambda mỗi giờ, Collector lấy danh sách dự án active từ DynamoDB, AssumeRole IAM Role khách hàng qua STS, kiểm toán tài khoản AWS mục tiêu, lưu tài nguyên thô vào DynamoDB, sau đó gửi Prompt đến Amazon Bedrock (Claude 3 Haiku) để phân tích AI. Rủi ro nghiêm trọng sẽ publish SNS để gửi email cảnh báo" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Cách end-to-end hourly scan hoạt động:**

Toàn bộ pipeline scan + AI analysis chạy theo tần suất cố định mỗi giờ (`rate(1 hour)` khai báo trong `template.yaml` và cấu hình được trong EventBridge console). Với mỗi project active, Collector lặp lại cùng pipeline 6 giai đoạn:

| Giai đoạn | Thành phần | Điều gì xảy ra |
|-----------|-----------|----------------|
| 1. **Trigger** | Amazon EventBridge | Kích hoạt `CollectorFunction` trên `rate(1 hour)`. Payload trigger là JSON `{}` (không cần gọi thủ công). |
| 2. **Project lookup** | Collector Lambda → DynamoDB `ai-advisor-projects` | Đọc mọi row có `SK = METADATA` để lấy danh sách tenant active. Mỗi row chứa `project_id`, `role_arn`, `region`, và `project_name`. |
| 3. **Cross-account assume** | Collector → AWS STS → Customer IAM Role | Với mỗi project, gọi `sts:AssumeRole(RoleArn=project.role_arn, RoleSessionName='CollectorSession')`. Nhận `AccessKeyId`, `SecretAccessKey`, `SessionToken` có hiệu lực 1 giờ. Xem mục 5.3.2 để có luồng delegation đầy đủ. |
| 4. **Resource enumeration** | Collector → boto3 (EC2 / S3 / IAM / Lambda / CloudWatch) | Build một `boto3.Session` mới từ temp credentials và chạy 23 read-only API call (danh sách đầy đủ ở mục 5.3.10). Kết quả là một JSON inventory. |
| 5. **Persist raw resources** | Collector → DynamoDB `ai-advisor-resources` | Ghi mỗi resource dưới dạng `(project_id, resource_id)` với `resource_type`, `collected_at`, và `raw_data`. GSI `resource_type-index` cho phép dashboard truy vấn "tất cả S3 bucket của mọi project" mà không cần scan. |
| 6. **AI analysis** | Collector → Amazon Bedrock (Claude 3 Haiku) | Build một prompt gộp raw inventory cùng một chỉ dẫn có cấu trúc: *"Với mỗi resource, xác định rủi ro Security, Cost, và Performance. Trả về JSON với severity (CRITICAL/HIGH/MEDIUM/LOW), category, title, description, và recommendation."* Bedrock trả về response JSON đã parse. |
| 7. **Persist insights** | Collector → DynamoDB `ai-advisor-insights` | Ghi mỗi insight dưới dạng `(project_id, insight_id)` được khóa theo severity để filter nhanh trên dashboard. |
| 8. **Alert routing (tùy chọn)** | Collector → Amazon SNS | Nếu có insight nào `severity = CRITICAL`, Collector publish một JSON message tới SNS topic `ai-advisor-alerts`, fan-out email tới `AlertEmail` SAM parameter đã cấu hình. |

**Tại sao thiết kế này phù hợp cho AI-driven auditing:**

- **Một pass thu thập tất cả; AI tổng hợp.** Collector cố ý *đơn giản* — nó không cố suy luận về từng resource. Nó chỉ liệt kê và lưu trữ. Mọi suy luận security / cost / performance diễn ra trong một Bedrock call duy nhất, nơi Claude 3 Haiku có đầy đủ context xuyên suốt mọi resource trong một prompt.
- **Idempotent và resilient.** Mỗi lần quét ghi lại các row resource theo key `(project_id, resource_id)`. Một Lambda thất bại giữa chừng không làm hỏng bảng; lần quét kế tiếp sẽ ghi đè sạch sẽ.
- **Chi phí giới hạn.** Bedrock được gọi một lần cho mỗi project mỗi giờ. Với `ai-advisor-resources` PAY_PER_REQUEST và Bedrock pay-per-token, tenant nhàn rỗi tốn đúng $0.
- **Lịch sử có thể audit.** Vì mọi resource và insight đều được timestamp trong DynamoDB, có thể vẽ biểu đồ cost/security trend theo thời gian bằng cách truy vấn GSI.

> IAM policy 23-action của Collector Lambda được tài liệu hóa tại mục 5.3.10; cấu hình EventBridge + SNS ở mục 5.3.7.

---

## 4. Cơ sở Dữ liệu DynamoDB Multi-Table Design

Ứng dụng lưu trữ dữ liệu trên **bốn DynamoDB table chuyên biệt** (một table cho mỗi entity). Mặc dù mọi table đều dùng chung `project_id` làm Partition Key để đảm bảo cách ly tenant tuyệt đối, thiết kế này cố ý *không phải* single-table — bốn entity có access pattern, secondary index và attribute schema khác nhau, vì vậy multi-table giữ cho mỗi table nhỏ và nhanh. Single-table layout được tài liệu hóa trong mục 5.3.6 như một điểm so sánh, nhưng *không phải* là thứ mà production template triển khai.

**Hình 4 - Sơ đồ Entity-Relationship DynamoDB Multi-Table (4 table, đều dùng chung `project_id` làm Partition Key cho cách ly tenant):**

<img src="/images/5.3-Architecture-design/dynamodb_singletable_design.png?v=2026-08-01-r2" alt="Sơ đồ Entity-Relationship DynamoDB Multi-Table — Bốn table chuyên biệt (PROJECTS, RESOURCES, INSIGHTS, ALERTS) đều dùng chung project_id làm Partition Key cho cách ly tenant. Table PROJECTS (PK: project_id, SK: sk) là root entity chứa metadata customer-project; table RESOURCES (PK: project_id, SK: resource_id) lưu snapshot AWS resources thô (EC2, S3, IAM, Lambda, CloudWatch) do Collector Lambda thu thập; table INSIGHTS (PK: project_id, SK: insight_id) lưu các khuyến nghị AI được Bedrock Claude 3 Haiku sinh ra; table ALERTS (PK: project_id, SK: alert_id) lưu các cảnh báo rủi ro nghiêm trọng được publish lên SNS Topic. RESOURCES có thêm GSI resource_type-index (HASH: resource_type, RANGE: collected_at) cho truy vấn cross-project theo resource type. ĐIỂM QUAN TRỌNG: Hệ thống dùng Multi-Table design (4 bảng chuyên biệt) KHÔNG phải single-table; tenant isolation được đảm bảo qua project_id làm partition key chung." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Quan hệ entity diễn giải bằng văn bản:**

- **Một project → nhiều resource** — Mỗi row trong `ai-advisor-projects` sở hữu nhiều row trong `ai-advisor-resources`, một row cho mỗi AWS resource đã quét (EC2 instance, S3 bucket, IAM role, Lambda function, CloudWatch metric, …).
- **Một project → nhiều insight** — Mỗi project tích lũy nhiều row trong `ai-advisor-insights`, một row cho mỗi finding do AI sinh ra (security risk, cost optimisation, performance bottleneck).
- **Một project → nhiều alert** — Một tập con các insight chạm `severity = CRITICAL` được nhân bản sang `ai-advisor-alerts` để dashboard có thể hiển thị alert feed riêng và pipeline SNS có target table sạch.
- **Truy vấn resource cross-project** — Bảng `ai-advisor-resources` mang một Global Secondary Index tên `resource_type-index` (PK: `resource_type`, SK: `collected_at`). GSI này cho phép dashboard trả lời "hiện tất cả S3 bucket của mọi project" mà không cần scan từng partition của từng project.

**Tại sao multi-table thay vì single-table:**

| Mối quan tâm | Multi-table (dự án này) | Single-table |
|----------------|--------------------------|--------------|
| **Per-entity access pattern** | Mỗi table vừa khớp với query pattern riêng (ví dụ resources cần GSI trên `resource_type`, insights thì không). | Một table phải encode mọi access pattern qua overloaded key; khó suy luận hơn. |
| **Per-table IAM** | `DynamoDBCrudPolicy` có thể scope theo table (ví dụ `ResourcesFunction` chỉ có `DynamoDBReadPolicy` trên `ai-advisor-resources`). | Một table duy nhất đòi hỏi IAM rộng hơn, ít granular hơn. |
| **Hot-partition risk** | Chỉ `ai-advisor-resources` có khả năng nóng; các bảng khác giữ lạnh. | Một table duy nhất gom write traffic lên một logical partition. |
| **Chi phí PAY_PER_REQUEST** | Chi phí nhàn rỗi $0 mỗi table — giống single-table nhưng dễ dự báo hơn. | Chi phí mỗi item tương đương. |
| **Cognitive load khi onboard** | Developer mới có thể suy luận về một entity tại một thời điểm. | Đòi hỏi hiểu toàn bộ key-encoding scheme ngay từ đầu. |

**Bảng inventory đầy đủ:**

| # | Table | Partition Key | Sort Key | GSI | Lưu trữ |
|---|-------|---------------|----------|-----|---------|
| 1 | ai-advisor-projects | project_id (S) | sk (S) | - | Metadata dự án (name, role_arn, region, owner) |
| 2 | ai-advisor-resources | project_id (S) | resource_id (S) | resource_type-index | Tài nguyên AWS đã quét thô (EC2, S3, IAM, Lambda, CloudWatch) |
| 3 | ai-advisor-insights | project_id (S) | insight_id (S) | - | Insight AI security/cost/performance theo project |
| 4 | ai-advisor-alerts | project_id (S) | alert_id (S) | - | Cảnh báo rủi ro nghiêm trọng đã kích hoạt email SNS |

- **PROJECTS:** `PK: project_id`, `SK: sk` — root entity, một row cho mỗi project
- **RESOURCES:** `PK: project_id`, `SK: resource_id` — tài nguyên AWS thô đã quét cho mỗi project
- **INSIGHTS:** `PK: project_id`, `SK: insight_id` — insight AI security/cost/performance cho mỗi project
- **ALERTS:** `PK: project_id`, `SK: alert_id` — cảnh báo rủi ro nghiêm trọng đã publish email SNS cho mỗi project

Thiết kế này đảm bảo cách ly tenant tuyệt đối (`project_id` Partition Key trên mọi table) và cho phép mỗi entity dùng attribute schema cùng access pattern phù hợp nhất — ví dụ chỉ `ai-advisor-resources` mang GSI `resource_type-index` cho truy vấn cross-project theo resource type. Xem mục 5.3.6 để có inventory đầy đủ từng table.

> **Ghi chú về Region:** Cả 4 bảng DynamoDB được triển khai trong **cùng region** với phần còn lại của SAM stack (`AWS::Region` resolve về region deploy, ví dụ `ap-southeast-1`). Client `boto3` trong `backend/shared/db.py` khởi tạo DynamoDB resource với `region_name=os.environ.get("AWS_REGION", "ap-southeast-1")` — code default là `ap-southeast-1` nhưng SAM parameter luôn override bằng region thực tế của stack. **Amazon Bedrock** nằm ở *region khác* (`us-east-1` mặc định cho Claude 3 Haiku) và được cấu hình riêng trong `template.yaml` dưới biến `Environment.BedrockRegion`. Bedrock region được tách rời khỏi DynamoDB region một cách có chủ đích — Bedrock chỉ khả dụng ở một tập region AWS nhỏ.

---

## 5. Tổng quan Kiến trúc End-to-End (PNG Tham chiếu)

Sơ đồ PNG bên dưới hợp nhất toàn bộ AWS service trong hệ thống, được tổ chức thành 3 ranh giới bảo mật (Client, Provider Backend, Customer Target Account) cùng các mũi tên có nhãn cho mọi luồng request chính:

**Hình 5 - Sơ đồ Kiến trúc End-to-End (3 ranh giới bảo mật + 19 AWS services):**

<img src="/images/5.3-Architecture-design/detailed_architecture.png?v=2026-08-01-r4" alt="Sơ đồ kiến trúc end-to-end tham chiếu với FLOW SUMMARY (11 bước đánh số) và 3 ranh giới bảo mật: Client Frontend (React 19 Dashboard, S3+CloudFront stack, Cognito JWT, API Gateway); SaaS Provider Backend (SÁU Lambda functions: NĂM API Handler chuyên biệt — projects-api, resources-api, insights-api, chat-api, alerts-api — và MỘT Collector Lambda được trigger bởi EventBridge schedule rate(1 hour); Bedrock Claude 3 Haiku; SNS alerts; DynamoDB Multi-Table 4 bảng chuyên biệt + 1 GSI resource_type-index); và Customer Target AWS Accounts (IAM Role AIAdvisorAuditRole, STS AssumeRole, EC2, S3, IAM, Lambda, CloudWatch). 11 bước flow đánh số: (1) browser request dashboard qua HTTPS; (2) CloudFront+S3 phục vụ React bundle; (3) Cognito cấp JWT sau login; (4) API Gateway nhận REST call với JWT; (5) API Handler Lambda thực thi với DynamoDB read/write; (6) Collector Lambda được trigger (qua EventBridge HOẶC qua /sync API); (7) Collector query DynamoDB PROJECTS lấy customer đang active; (8) Collector gọi sts:AssumeRole lấy temp credentials trong target account; (9) Collector dùng boto3 đọc 23 AWS read-actions (EC2/S3/IAM/Lambda/CloudWatch); (10) Collector ghi raw data vào DynamoDB RESOURCES + gọi Bedrock Claude 3 Haiku phân tích + ghi insights + publish critical-risk alerts lên SNS. Mũi tên liền thể hiện luồng nội tài khoản; mũi tên đứt nét màu đỏ thể hiện cross-account sts:AssumeRole delegation từ Collector Lambda sang Customer IAM Role." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

> **Hướng dẫn đọc sơ đồ:**
> - **Hàng 1 (Client):** Trình duyệt → CloudFront → S3 SPA tĩnh → Cognito cấp JWT → API Gateway xác thực JWT trên mỗi request.
> - **Hàng 2 (Backend):** API Gateway định tuyến đến một trong 5 API Lambdas (projects, resources, insights, chat, alerts). EventBridge schedule (1 giờ) kích hoạt Collector Lambda, ghi vào DynamoDB, gọi Bedrock phân tích AI, và publish SNS nếu phát hiện rủi ro nghiêm trọng.
> - **Hàng 3 (Customer):** Collector Lambda gọi `sts:AssumeRole` đến IAM Role đáng tin cậy của khách hàng, sau đó dùng boto3 liệt kê cấu hình EC2 / S3 / IAM / v.v. trên nhiều region.

---

## 6. Bảng DynamoDB (4 bảng + 1 GSI)

Backend lưu trữ dữ liệu trên **bốn bảng DynamoDB**, tất cả dùng PAY_PER_REQUEST để chi phí nhàn rỗi xấp xỉ $0:

| # | Tên bảng | Partition Key | Sort Key | GSI | Nội dung |
|---|---|---|---|---|---|
| 1 | ai-advisor-projects | project_id (S) | sk (S) | - | Metadata dự án (name, role_arn, region, owner) |
| 2 | ai-advisor-resources | project_id (S) | resource_id (S) | resource_type-index (PK: resource_type, SK: collected_at) | Tài nguyên quét thô (EC2, S3, IAM, Lambda, CloudWatch) |
| 3 | ai-advisor-insights | project_id (S) | insight_id (S) | - | AI insights (security / cost / performance) |
| 4 | ai-advisor-alerts | project_id (S) | alert_id (S) | - | Cảnh báo rủi ro nghiêm trọng đã gửi qua SNS |

GSI resource_type-index cho phép dashboard truy vấn, ví dụ: 'tất cả S3 bucket của mọi dự án' mà không cần full table scan.

---

## 7. EventBridge Schedule và SNS Alert Pipeline

- **EventBridge rule** được khai báo inline trong template.yaml với Schedule: rate(1 hour) và Enabled: true. Để đổi tần suất, sửa rule và redeploy stack.
- **SNS topic** i-advisor-alerts được tạo với subscription email. Cập nhật SAM parameter AlertEmail nếu muốn đổi người nhận.

> **Chiến lược truy vấn cross-project với GSI `resource_type-index`:** GSI duy nhất trên `ai-advisor-resources` được thiết kế có chủ đích cho **truy vấn cross-project theo resource type**. Primary key của base table (`project_id`, `resource_id`) tối ưu cho *intra-project* query "tất cả resource của project X". Nhưng dashboard cũng cần trả lời *cross-project* query "hiện mọi S3 bucket của mọi project" (vd: cho một global misconfiguration sweep). Không có GSI, query đó phải `Scan` toàn bộ `ai-advisor-resources`. Có GSI, cùng query đó trở thành `Query` trên `resource_type-index` với `KeyConditionExpression = "resource_type = :t"`, O(matches) thay vì O(table). Đánh đổi là duplicated writes (mỗi resource ghi một lần vào base table + index dưới `resource_type + collected_at` trên GSI), nhưng với `PAY_PER_REQUEST` và lượng resource nhỏ mỗi project, chi phí bỏ qua được so với lợi ích query-latency.

---

## 8. Cognito User Pool và API Gateway Authorizer

| Component | CloudFormation Resource | Mục đích |
|---|---|---|
| AdvisorUserPool | AWS::Cognito::UserPool | Chứa danh tính người dùng cuối (email username) |
| AdvisorUserPoolClient | AWS::Cognito::UserPoolClient | Client SPA frontend (không secret, public flow) |
| AdvisorApi.Auth | AWS::Serverless::Api | JWT authorizer gắn với User Pool ARN |
| CognitoAuthorizer | API Gateway Authorizer | Validate header Authorization: Bearer <JWT> trên mọi API call |

Toàn bộ 11 route được bảo vệ bởi CognitoAuthorizer - request ẩn danh trả về HTTP 401.

---

## 9. API Gateway Throttling và Quota

Resource AdvisorUsagePlan áp dụng các giới hạn sau cho stage prod:

| Setting | Value |
|---|---|
| Rate limit (steady) | **100 requests/giây** |
| Burst limit | **50** |
| Monthly quota | **1000 requests/tháng** |

{{% notice info %}}Quota 1000 req/tháng được tính cho **một tác giả workshop + vài tester**. Với multi-tenant SaaS production, nâng quota (hoặc bỏ) và dùng per-tenant throttling qua API keys.{{% /notice %}}

---

## 10. IAM Permissions của Collector Lambda (23 Actions)

CollectorFunction được cấp Resource: '*' cho 23 AWS action thuộc 7 nhóm service. Đây là tập *tối thiểu* cần thiết để đọc EC2/S3/IAM/Lambda/CloudWatch qua mọi region của tài khoản đích:

| Service | Actions | Mục đích |
|---|---|---|
| EC2 | DescribeInstances, DescribeInstanceStatus, DescribeSecurityGroups | Inventory + utilization |
| S3 | ListAllMyBuckets, GetBucketAcl, GetBucketPublicAccessBlock, GetBucketLocation | Phát hiện rủi ro public-access |
| IAM | ListRoles, ListAttachedRolePolicies, ListRolePolicies, ListUsers, ListMFADevices, ListAccessKeys, GetLoginProfile | Privilege hygiene |
| Lambda | ListFunctions, GetFunctionConfiguration | Cold-start + runtime audit |
| CloudWatch | GetMetricStatistics, ListMetrics, GetMetricData, DescribeAlarms | Baseline hiệu năng 7 ngày |
| STS | AssumeRole | Chính cơ chế cross-account delegation |
| Bedrock | InvokeModel, InvokeModelWithResponseStream | Sinh AI insight |

Trust policy của AIAdvisorAuditRole phía khách hàng phải cho phép sts:AssumeRole từ tài khoản SaaS provider (xem phần 5.4 để thấy JSON trust policy).

---

## Tóm tắt Phần

Kiến trúc này kết hợp 4 bảng DynamoDB, 1 EventBridge schedule, 1 SNS topic, 1 Cognito User Pool, 6 Lambda function, và 1 API Gateway với Cognito JWT auth - tất cả được triển khai qua một SAM template duy nhất (template.yaml). Kiểm toán cross-account đạt được nhờ sts:AssumeRole và không lưu trữ long-lived credential phía SaaS.