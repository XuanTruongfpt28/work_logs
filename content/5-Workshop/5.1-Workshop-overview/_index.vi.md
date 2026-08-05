---
title : "Giới thiệu"
date : 2026-07-07
weight : 1
chapter : false
pre : " <b> 5.1. </b> "
---

# Phần 5.1 - Tổng quan Workshop

## Tóm tắt Dự án

**AI AWS Advisor** được thiết kế như một hệ thống B2B SaaS toàn diện cấp doanh nghiệp, có khả năng quét hạ tầng đa tài khoản AWS của khách hàng một cách an toàn, thu thập cấu hình bằng cơ chế phân quyền tạm thời và phân tích bằng Trí tuệ nhân tạo (Generative AI).

**Hình 1 - Sơ đồ Kiến trúc Tổng quan AI AWS Advisor**


![Architecture](/images/5-Workshop/5.1-Workshop-overview/architecture.png)


Sơ đồ trên minh họa luồng dữ liệu tổng quan của nền tảng **AI AWS Advisor**. Người dùng truy cập **Enterprise Web Dashboard**, sau đó gửi các yêu cầu qua giao thức **HTTPS/REST** đến **Amazon API Gateway**. API Gateway tiếp nhận và phân phối yêu cầu đến năm **AWS Lambda API Handler** chuyên biệt (**Projects, Resources, Insights, Chat Copilot** và **Alerts**), các Lambda này thực hiện việc đọc và ghi dữ liệu trên **bốn bảng Amazon DynamoDB**.

Song song với luồng xử lý yêu cầu từ người dùng, **Hourly Scanning Collector Lambda** định kỳ sử dụng quyền `sts:AssumeRole` để truy cập an toàn vào tài khoản AWS của khách hàng, thu thập thông tin tài nguyên và tạo **Prompt JSON Context**. Dữ liệu này được gửi đến **Amazon Bedrock** (Claude 3 Haiku) để phân tích và sinh các khuyến nghị tối ưu hóa bằng AI.

Toàn bộ backend của hệ thống được triển khai theo kiến trúc serverless với **sáu hàm Lambda**, bao gồm **năm API Lambda Handler** và **một Collector Lambda**.


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

**Hình 2.** Trang **Dashboard Overview** (`/`) hiển thị bốn thẻ KPI chính gồm **System Health (78%)**, **Resources (75)**, **Critical Risks (4)** và **Monthly Savings ($2.5K)**. Bên dưới là khu vực chuyển đổi giữa các dự án (**ProDev**, **Beta Dev** và **Production**). Ở phía phải là **AI Analysis Panel**, hiển thị số lượng cảnh báo theo từng mức độ nghiêm trọng (severity) và ô nhập **AI Chat** để người dùng đặt câu hỏi về hạ tầng AWS.



![dashboard](/images/5-Workshop/5.1-Workshop-overview/dashboard_overview.png)




**Hình 3.** Trang **Projects** (`/projects`) hiển thị ba môi trường AWS dưới dạng các thẻ (card) với màu sắc phân biệt theo trạng thái, gồm **ProDev** (Active – dấu tick xanh), **Beta Dev** (Pending – màu hổ phách) và **Production** (Warning – 4 Critical Issues, màu đỏ). Mỗi thẻ cung cấp các thông tin chính như **Project ID**, **IAM Role ARN**, **thời điểm quét gần nhất (Last Scan)** và ba nút thao tác để quản lý dự án.


![projects_list](/images/5-Workshop/5.1-Workshop-overview/projects_list.png)

**Hình 4.** Trang **Cost Optimization** (`/cost`) hiển thị kết quả phân tích chi phí do AI tạo ra, bao gồm **Hero Card – Potential Monthly Savings** với mức tiết kiệm ước tính **124,50 USD/tháng** nhờ phát hiện **EC2 instance** không hoạt động (idle). Bên dưới là ba **Cost Optimization Insights** được sắp xếp theo mức độ ưu tiên (severity), gồm **Idle EC2 Detected**, **Rightsizing Recommendation** và **Reserved Instance Opportunity**, giúp người dùng nhanh chóng xác định các cơ hội tối ưu chi phí trên hạ tầng AWS.


![cost_optimization](/images/5-Workshop/5.1-Workshop-overview/cost_optimization.png)


**Hình 5.** Trang **Performance Insights** (`/performance`) hiển thị kết quả phân tích hiệu năng hệ thống, trong đó nổi bật là cảnh báo **DB Node Overloaded** với mức sử dụng **CPU đạt 98,5%**. Bên dưới là ba **Performance Insights** được AI phân tích, gồm **CPU Saturation**, **I/O Bottleneck** và **Lambda Cold Start**. Mỗi mục hiển thị thanh **Utilization** cùng các khuyến nghị do AI đề xuất, giúp người dùng nhanh chóng xác định nguyên nhân gây suy giảm hiệu năng và lựa chọn giải pháp tối ưu phù hợp.


![cost_optimization](/images/5-Workshop/5.1-Workshop-overview/cost_optimization.png)



**Hình 6.** Trang **Security Risks** (`/security`) hiển thị các rủi ro bảo mật được AI phát hiện trên hạ tầng AWS, bao gồm hai cảnh báo mức **Critical** liên quan đến **S3 Bucket Exposure** (*Public Access* và *Missing Encryption*) cùng một rủi ro mức **Medium** đối với **IAM Over-privileged Role**. Mỗi **Risk Card** cung cấp các thông tin quan trọng như **Severity Badge**, **Resource ARN**, **Detection Method** và các **AI Remediation Steps**, giúp người dùng nhanh chóng đánh giá mức độ ảnh hưởng và thực hiện các biện pháp khắc phục được đề xuất.


![security_risks](/images/5-Workshop/5.1-Workshop-overview/security_risks.png)



**Hình 7.** Trang **AI Copilot** (`/copilot`) minh họa cuộc hội thoại gồm ba lượt trao đổi giữa người vận hành (operator) và **Claude 3 Haiku**. Người dùng đặt câu hỏi về tài nguyên đang phát sinh chi phí cao nhất, AI phân tích và xác định **Production EC2 Fleet** là đối tượng cần ưu tiên tối ưu. Trong lượt trao đổi tiếp theo, AI tiếp tục trả lời câu hỏi về các quyền và phương án tối ưu dưới dạng **Action Plan** được trình bày theo từng bước đánh số, giúp người dùng dễ dàng thực hiện các khuyến nghị.



![ai_copilot](/images/5-Workshop/5.1-Workshop-overview/ai_copilot.png)


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

Phần tổng quan này đặt nền tảng cho toàn bộ workshop. Các phần sau đi sâu vào yêu cầu hệ thống (5.2), kiến trúc end-to-end (5.3), chiến lược triển khai (5.4), đảm bảo chất lượng (5.5) và vận hành & dọn dẹp (5.6).