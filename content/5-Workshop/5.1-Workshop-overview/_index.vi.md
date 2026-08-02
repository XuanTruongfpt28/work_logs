---
title: "Tổng quan Workshop"
date: 2026-05-01
weight: 1
chapter: false
pre: " <b> 5.1. </b> "
---

# Phần 5.1 - Tổng quan Workshop

## Tóm tắt Dự án

**AI AWS Advisor** được thiết kế như một hệ thống B2B SaaS toàn diện cấp doanh nghiệp, có khả năng quét hạ tầng đa tài khoản AWS của khách hàng một cách an toàn, thu thập cấu hình bằng cơ chế phân quyền tạm thời và phân tích bằng Trí tuệ nhân tạo (Generative AI).

**Hình 1 - Sơ đồ Kiến trúc Tổng quan AI AWS Advisor (Web Dashboard → API Gateway → Lambda → DynamoDB ↔ Bedrock + STS AssumeRole):**

<img src="/images/5.1-Workshop-overview/workshop_architecture.png?v=2026-08-01-r3" alt="Sơ đồ kiến trúc tổng quan AI AWS Advisor - Ba vùng độc lập: (1) Client Frontend với React 19 + Vite + Tailwind Dashboard (Recharts, TanStack Query) được phục vụ qua CloudFront+S3; (2) AI Advisor Backend gồm API Gateway (REST, 11 routes, Cognito JWT Authorizer) điều hướng tới SÁU Lambda functions — NĂM API Handler chuyên biệt (ai-advisor-projects-api: 5 routes list/create/get/delete/sync, ai-advisor-resources-api: 2 routes list/get, ai-advisor-insights-api: 2 routes list/generate + Bedrock + SNS, ai-advisor-chat-api: 1 route chat + Bedrock streaming, ai-advisor-alerts-api: 1 route list) và MỘT Collector Lambda (ai-advisor-collector trigger bởi EventBridge rate(1 hour), dùng sts:AssumeRole cross-account, thực hiện 23 AWS read-actions trên EC2/S3/IAM/Lambda/CloudWatch); Amazon Bedrock Claude 3 Haiku (anthropic.claude-3-haiku-20240307-v1:0); Amazon SNS Topic ai-advisor-alerts + email subscription cho critical-risk notifications; DynamoDB Multi-Table (4 bảng chuyên biệt: ai-advisor-projects PK=project_id+SK=sk, ai-advisor-resources PK=project_id+SK=resource_id + GSI resource_type-index, ai-advisor-insights PK=project_id+SK=insight_id, ai-advisor-alerts PK=project_id+SK=alert_id); (3) Customer Target AWS Accounts với STS AssumeRole truy cập EC2/S3/IAM/Lambda/CloudWatch resources qua audit IAM Role AIAdvisorAuditRole." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

_Sơ đồ trên minh họa luồng dữ liệu tổng quan của nền tảng AI AWS Advisor: người dùng tương tác với **Enterprise Web Dashboard**, gọi **Amazon API Gateway** qua HTTPS/REST. API Gateway phân phối yêu cầu đến năm API Lambda handler chuyên biệt (Projects, Resources, Insights, Chat Copilot, Alerts) đọc/ghi **bốn bảng Amazon DynamoDB**. Song song, **Hourly Scanning Collector Lambda** gọi `sts:AssumeRole` để đọc an toàn tài khoản AWS khách hàng, sau đó gửi Prompt JSON Context đến **Amazon Bedrock** (Claude 3 Haiku) sinh các khuyến nghị tối ưu bằng AI. Tổng số Lambda trong backend serverless là **sáu** (5 API + 1 Collector)._

---

## Bài toán Thực tế

Quản lý hệ thống AWS lớn trong môi trường thực tế gặp 3 thách thức lớn:

1. **Lỗi cấu hình Bảo mật tiềm ẩn:** S3 Bucket mở công khai, Security Group mở `0.0.0.0/0`, hay dữ liệu không được mã hóa thường bị bỏ qua cho đến khi xảy ra rò rỉ dữ liệu.
2. **Lãng phí Chi phí Đám mây:** EBS Volume nhàn rỗi, EC2 instance bỏ trống, Elastic IP không gắn vào server làm tiêu tốn hàng nghìn USD hàng tháng.
3. **Quy trình Kiểm toán Thủ công tốn thời gian:** Đội ngũ DevOps và Security phải tốn hàng trăm giờ rà soát thủ công các file JSON cấu hình thô.

---

## Công nghệ Sử dụng

- **Frontend:** React 19 (JavaScript SPA), Vite, Tailwind CSS, shadcn/ui-style components (Radix UI primitives + `class-variance-authority`), Recharts, TanStack React Query.
- **Backend Serverless:** Python 3.12, AWS Lambda, Amazon API Gateway, Amazon EventBridge, Amazon SNS.
- **Trí tuệ Nhân tạo (GenAI):** Amazon Bedrock (Anthropic Claude 3 Haiku `anthropic.claude-3-haiku-20240307-v1:0`).
- **Cơ sở dữ liệu:** Amazon DynamoDB (Thiết kế Multi-Table NoSQL — 4 bảng chuyên biệt + 1 GSI).
- **Bảo mật:** AWS Security Token Service (STS `sts:AssumeRole`) phân quyền cross-account.
- **IaC:** AWS Serverless Application Model (SAM CLI).

---

## Danh mục Lambda Backend (6 Functions)

Toàn bộ backend serverless gồm **6 Lambda function** (5 API handler + 1 Collector theo lịch), được khai báo trong `template.yaml`:

| # | Function Name | Handler | Trigger | Mục đích chính |
|---|---|---|---|---|
| 1 | `ai-advisor-projects-api` | `api.projects.lambda_handler` | API Gateway (5 route) | CRUD dự án + kích hoạt sync |
| 2 | `ai-advisor-resources-api` | `api.resources.lambda_handler` | API Gateway (2 route) | Liệt kê tài nguyên AWS đã quét |
| 3 | `ai-advisor-insights-api` | `api.insights.lambda_handler` | API Gateway (2 route) | Liệt kê + sinh AI insights |
| 4 | `ai-advisor-chat-api` | `api.chat.lambda_handler` | API Gateway (1 route) | Generative AI Copilot (Q&A) |
| 5 | `ai-advisor-alerts-api` | `api.alerts.lambda_handler` | API Gateway (1 route) | Liệt kê cảnh báo rủi ro nghiêm trọng |
| 6 | `ai-advisor-collector` | `collector.main.lambda_handler` | EventBridge `rate(1 hour)` | Quét tài khoản đích qua STS |

Cả 6 function chạy trên **Python 3.12** runtime, tích hợp **AWS Lambda Powertools** (logger, metrics, tracer) cho observability.

---

## Cấu trúc Frontend React

SPA React 19 được xây trên **Vite** và dùng **TanStack React Query** để fetch dữ liệu qua API Gateway. Sáu trang chính nằm trong `frontend/src/pages/`:

| Trang | Route | Mục đích |
|---|---|---|
| **Dashboard** | `/` | Tổng quan KPI của toàn bộ dự án |
| **Projects** | `/projects` | Liệt kê, tạo, xóa dự án; nhập Role ARN |
| **Cost** | `/cost` | Biểu đồ khuyến nghị tiết kiệm chi phí (Recharts) |
| **Performance** | `/performance` | Lambda cold start, mức sử dụng EC2 |
| **Security** | `/security` | S3 public, security group mở, IAM hygiene |
| **Copilot** | `/copilot` | Chat với Bedrock Claude 3 Haiku |

UI primitive dùng **shadcn/ui** (Radix-based), style bằng **Tailwind CSS**; biểu đồ bằng **Recharts**. State nằm trong cache của **TanStack React Query** và tự động retry khi gặp lỗi 5xx.

Dưới đây là giao diện thực tế của từng trang, chụp từ session workshop author với stack đã deploy tại `us-east-1`:

**Hình 2 - Dashboard Overview (`/`) hiển thị 4 KPI card (System Health 78%, Resources 75, Critical Risks 4, Monthly Savings $2.5K), tab chuyển dự án (ProDev / Beta Dev / Production) và panel AI Analysis với đếm severity và ô input AI Chat:**

<img src="/images/5.1-Workshop-overview/ui_dashboard_overview.png?v=2026-08-01-r4" alt="Trang Dashboard Overview của AI AWS Advisor render với backend đã deploy - hàng trên hiển thị 4 KPI card: System Health 78% (gradient tím), Resources 75 (gradient xanh dương), Critical Risks 4 (gradient cam), Monthly Savings $2.5K (gradient xanh lá). Bên dưới là tab switcher với ProDev (active, tím), Beta Dev, và Production. Mỗi tab load project summary với empty state và sidebar AI Analysis panel hiển thị severity counts (High: 4, Medium: 0, Low: 0) cùng ô input AI Chat placeholder 'Hỏi về hạ tầng của bạn...'" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Hình 3 - Trang Projects (`/projects`) liệt kê 3 môi trường AWS dưới dạng card gradient (ProDev dấu tick xanh status Active, Beta Dev amber pending status, Production đỏ warning 4 critical issues), mỗi card hiển thị Project ID, Role ARN, Last Scan timestamp và 3 action button:**

<img src="/images/5.1-Workshop-overview/ui_projects_list.png?v=2026-08-01-r4" alt="Trang Projects của AI AWS Advisor liệt kê ba môi trường AWS của khách hàng dưới dạng card gradient trong grid responsive: ProDev (gradient xanh lá, status Active, Project ID PRJ-1301, Role ARN arn:aws:iam::050912644653:role/AIAdvisorAuditRole, Last Scan 1/30/2026 với nút Sync Now và Add Project); Beta Dev (gradient amber, status Pending); Production (gradient đỏ, status hiển thị 4 critical issues). Mỗi card có 3 nút Sync, View Details và Delete." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Hình 4 - Trang Cost Optimization (`/cost`) hiển thị AI phát hiện idle EC2 instance tiết kiệm ($124.50/tháng), hero card 'Potential Monthly Savings', và 3 cost optimization insights xếp hạng theo severity (Idle EC2 detected, Rightsizing recommendation, Reserved Instance opportunity):**

<img src="/images/5.1-Workshop-overview/ui_cost_optimization.png?v=2026-08-01-r4" alt="Trang Cost Optimization của AI AWS Advisor với hero card 'Potential Monthly Savings' hiển thị $124.50/tháng. Bên dưới là 3 cost insight do AI sinh xếp theo severity: (1) Idle EC2 Instance Detected với $85.50/tháng tiềm năng tiết kiệm và đề xuất 'Implement rightsizing or terminate'; (2) Over-provisioned RDS Instance với $24.00/tháng và đề xuất 'Downsize to db.t3.medium'; (3) Unused Elastic IP Address với $15.00/tháng và đề xuất 'Release the Elastic IP'. Mỗi insight card hiển thị Category, Estimated Monthly Savings và badge Severity màu." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Hình 5 - Trang Performance Insights (`/performance`) hiển thị critical DB Node Overloaded ở 98.5% CPU, cùng 3 performance insight (CPU saturation, I/O bottleneck, Lambda cold start) với utilization bar và đề xuất AI:**

<img src="/images/5.1-Workshop-overview/ui_performance_insights.png?v=2026-08-01-r4" alt="Trang Performance Insights của AI AWS Advisor hiển thị phát hiện nghiêm trọng nhất qua hero card: 'DB Node Overloaded' ở 98.5% CPU utilization với thanh utilization đỏ tại 98.5% và đề xuất AI 'Consider scaling vertically or enabling read replicas'. Bên dưới là 3 performance insight bổ sung: (1) Lambda Cold Start Latency với badge severity trung bình và thanh utilization 23%; (2) I/O Bottleneck on EBS Volume với badge severity thấp; (3) Memory Pressure on App Server với thanh utilization amber." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Hình 6 - Trang Security Risks (`/security`) với 2 critical S3 bucket exposure (Public Access, Missing Encryption) và 1 medium IAM risk (Over-privileged Role), mỗi risk card hiển thị Severity badge, Resource ARN, Detection method và AI remediation steps:**

<img src="/images/5.1-Workshop-overview/ui_security_risks.png?v=2026-08-01-r4" alt="Trang Security Risks của AI AWS Advisor liệt kê 3 lỗ hổng đang hoạt động với severity badge: (1) CRITICAL - S3 Bucket Public Access trên aws-glue-assets-prod, phát hiện qua GetBucketPublicAccessBlock, đề xuất 'Enable Block Public Access and audit bucket ACL'; (2) CRITICAL - S3 Bucket Missing Encryption trên deploy-bucket-artifacts, đề xuất 'Enable default encryption with KMS key'; (3) MEDIUM - IAM Role Over-privileged trên LambdaExecutionRole, đề xuất 'Apply least-privilege policy and remove AdministratorAccess'. Mỗi card hiển thị Severity badge, Resource identifier, Detection method và AI-generated remediation steps." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Hình 7 - AI Copilot chat (`/copilot`) với cuộc hội thoại 3 lượt giữa operator và Claude 3 Haiku — câu hỏi về resource đang tốn kém nhất, AI xếp hạng trỏ vào Production EC2 fleet, và follow-up hỏi về quyền tối ưu AI trả về dưới dạng action plan đánh số:**

<img src="/images/5.1-Workshop-overview/ui_ai_copilot.png?v=2026-08-01-r4" alt="Giao diện chat AI Copilot của AI AWS Advisor hiển thị cuộc hội thoại 3 lượt tiếng Việt giữa operator và Claude 3 Haiku: (1) 'tài nguyên nào đang tốn kém nhất'; (2) AI phản hồi phân tích rằng 4 EC2 Production chiếm cost lớn nhất ~$720/tháng và đề xuất terminate 2 instance idle; (3) follow-up 'có thể tối ưu không?'; (4) AI trả về action plan 4 bước đánh số: rightsize Production instance, chuyển sang Compute Savings Plans, xóa 4 stopped instance, bật S3 Intelligent-Tiering. Chat header hiển thị 'AI Advisor Assistant' với badge Powered by Claude 3 Haiku." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

---

## Danh mục REST API Endpoint (11 Route)

Toàn bộ 11 route được deploy dưới một stage API Gateway duy nhất (`/prod`), bảo vệ bằng **Amazon Cognito JWT authorizer**. CORS được mở `*` (production nên giới hạn lại):

| Method | Path | Lambda | Mục đích |
|---|---|---|---|
| `GET` | `/projects` | ProjectsFunction | Liệt kê dự án của user hiện tại |
| `POST` | `/projects` | ProjectsFunction | Tạo dự án mới (nhận Role ARN + region) |
| `GET` | `/projects/{project_id}` | ProjectsFunction | Chi tiết 1 dự án |
| `DELETE` | `/projects/{project_id}` | ProjectsFunction | Xóa dự án (cascade resources/insights) |
| `POST` | `/projects/{project_id}/sync` | ProjectsFunction | Kích hoạt Collector không đồng bộ |
| `GET` | `/projects/{project_id}/resources` | ResourcesFunction | Liệt kê tài nguyên AWS đã quét |
| `GET` | `/projects/{project_id}/resources/{resource_id}` | ResourcesFunction | Lấy raw_data JSON đầy đủ |
| `GET` | `/projects/{project_id}/insights` | InsightsFunction | Liệt kê AI insights (phân trang) |
| `POST` | `/projects/{project_id}/insights/generate` | InsightsFunction | Yêu cầu Bedrock sinh insights mới |
| `POST` | `/projects/{project_id}/chat` | ChatFunction | Gửi prompt + context tài nguyên cho Bedrock |
| `GET` | `/projects/{project_id}/alerts` | AlertsFunction | Liệt kê cảnh báo rủi ro nghiêm trọng |

API Gateway throttle **100 requests/giây** với **burst 50** và quota **1000 request/tháng** qua `AdvisorUsagePlan`.

---

## Cấu trúc Repository

```
aws-advisor/
├── backend/                     # Ứng dụng AWS SAM Python 3.12 serverless
│   ├── api/                     # 5 API handler (projects, resources, insights, chat, alerts)
│   ├── collector/               # 6 collector (ec2, s3, iam, lambda, cloudwatch, main)
│   ├── ai/                      # Bedrock Claude 3 prompt + rule engine
│   ├── shared/                  # aws_client (STS AssumeRole), db, models
│   ├── tests/                   # pytest + moto (26 tests)
│   └── template.yaml            # CloudFormation / SAM IaC
├── frontend/                    # Vite + React 19 + JavaScript SPA (JSX, không TypeScript)
│   ├── src/pages/               # 6 trang chính (Dashboard, Projects, Cost, ...)
│   ├── src/components/          # shadcn/ui primitive + custom cards
│   ├── src/services/            # API client (apiClient.js, queryKeys.js)
│   └── src/__tests__/           # Vitest + RTL (5 test files)
└── docs/                        # Engineering reflection + future roadmap
```

---

## Tóm tắt Phần

Phần tổng quan này đặt nền tảng cho toàn bộ workshop. Các phần sau đi sâu vào yêu cầu hệ thống (§5.2), kiến trúc end-to-end (§5.3), chiến lược triển khai (§5.4), đảm bảo chất lượng (§5.5) và vận hành & dọn dẹp (§5.6).
