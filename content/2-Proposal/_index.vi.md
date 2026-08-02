---
title: "Proposal"
date: 2026-05-01
weight: 2
chapter: false
pre: " <b> 2. </b> "
---

# Đề xuất Đồ án: AI AWS Advisor (Enterprise SaaS)
## Nền tảng Tự động Kiểm toán & Tối ưu hóa Đa tài khoản Đám mây AWS

### 1. Tóm tắt Đề xuất

Dự án **AI AWS Advisor** đề xuất giải pháp xây dựng nền tảng B2B SaaS cấp doanh nghiệp nhằm tự động hóa quy trình kiểm toán hạ tầng đám mây, kiểm tra tuân thủ bảo mật và tối ưu hóa chi phí cho các môi trường đa tài khoản AWS.

Bằng cách kết hợp **Amazon Bedrock (Claude 3 Haiku)** cùng kiến trúc Serverless 100% (**AWS Lambda, Amazon API Gateway, Amazon DynamoDB, Amazon EventBridge**), hệ thống tự động thu thập cấu hình tài nguyên thô, đánh giá rủi ro, tính toán số tiền tiết kiệm và đưa ra khuyến nghị xử lý trực quan qua Web Dashboard và AI Copilot.

---

### 2. Mô tả Bài toán Thực tế

#### Thách thức của Ngành
Các tổ chức vận hành hệ thống trên AWS hiện nay đang đối mặt với 3 thách thức lớn:
1. **Lỗ hổng Bảo mật tiềm ẩn:** Lỗi cấu hình như S3 bucket công khai, Security Group mở `0.0.0.0/0`, hay IAM roles cấp thừa quyền thường khó phát hiện cho đến khi sự cố rò rỉ dữ liệu diễn ra.
2. **Lãng phí Tài nguyên Cloud:** EBS volume không gắn vào máy chủ, EC2 nhàn rỗi, hay Elastic IP không sử dụng gây lãng phí hàng nghìn USD mỗi tháng.
3. **Quy trình Kiểm toán Thủ công Tốn thời gian:** Đội ngũ Security và DevOps phải tốn hàng trăm giờ đọc file JSON cấu hình thô một cách thủ công trên nhiều tài khoản khác nhau.

#### Giải pháp Đề xuất
**AI AWS Advisor** mang đến giải pháp kiểm toán đám mây tập trung, bảo mật Zero-Trust:
- **Ủy quyền Zero-Trust Cross-Account:** Sử dụng dịch vụ AWS STS (`sts:AssumeRole`) cấp quyền truy cập kiểm toán ngắn hạn mà không cần lưu trữ Access Key cố định của khách hàng.
- **Quét Tự động Theo Sự kiện:** EventBridge kích hoạt tiến trình định kỳ hàng giờ để thu thập cấu hình hạ tầng từ tất cả tài khoản đã đăng ký.
- **Động cơ Phân tích Generative AI:** Tích hợp Amazon Bedrock (Claude 3 Haiku) dịch dữ liệu cấu hình thô thành các báo cáo khuyến nghị được phân loại theo **Bảo mật (Security)**, **Tối ưu Chi phí (Cost)**, và **Hiệu năng (Performance)**.
- **AI Copilot Trợ lý Ảo:** Cho phép người dùng hỏi đáp trực tiếp về trạng thái hạ tầng bằng ngôn ngữ tự nhiên.

**Hình 1 - Luồng Cross-Account Role Assumption qua AWS STS:**

<img src="/aws-ojt-workshop-ja/images/2-Proposal/cross_account_role_assumption.png?v=2026-07-31" alt="Sequence Diagram mô tả luồng STS AssumeRole - SaaS Lambda gọi AssumeRole, AWS STS validate Trust Policy, trả về temporary credentials để truy cập EC2, S3 trong tài khoản khách hàng" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

*Sơ đồ trên minh họa cơ chế **Ủy quyền Zero-Trust Cross-Account** qua 6 bước: (1) Lambda trong Provider Account gọi `sts:AssumeRole` với ARN của Cross-Account IAM Role (kèm `ExternalId` tùy chọn); (2) AWS STS validate Trust Policy — kiểm tra calling principal khớp, `ExternalId` khớp (nếu có), và permission boundary (nếu có) thỏa mãn; (3) Trust Policy hợp lệ được xác nhận; (4) STS phát hành **session token** (`AccessKeyId`, `SecretAccessKey`, `SessionToken`) có thời hạn 1 giờ qua `DurationSeconds=3600`; (5) Lambda dùng credentials tạm thời này tạo `boto3.Session` mới và gọi các API read-only lên **EC2** / **S3** / **IAM** / **Lambda** / **CloudWatch** trong tài khoản khách hàng mà không cần lưu trữ Access Key cố định - đảm bảo nguyên tắc **Least Privilege** và giảm thiểu rủi ro rò rỉ credential; (6) sau 1 giờ session tự hết hạn và lần scan hourly tiếp theo sẽ cấp session mới. Toàn bộ 23 read-only action được liệt kê chi tiết tại mục 5.3.10.*

#### Hiệu quả Kinh tế & Tối ưu (ROI)
- **Tiết kiệm Thời gian:** Giảm hơn 90% thời gian kiểm toán thủ công (từ nhiều ngày xuống còn vài phút).
- **Tối ưu Chi phí:** Phát hiện từ 15% đến 35% chi phí lãng phí hàng tháng cho khách hàng.
- **Chi phí Duy trì Nhàn rỗi xấp xỉ $0:** Hệ thống hoạt động theo mô hình Serverless Pay-per-use, chi phí khi không có người dùng đạt $0.00/tháng.

---

### 3. Kiến trúc Giải pháp

**Hình 2 - Sơ đồ Kiến trúc Tổng quan Hệ thống AI AWS Advisor:**

<img src="/aws-ojt-workshop-ja/images/2-Proposal/aws_advisor_architecture.png?v=2026-08-01-r3" alt="Sơ đồ kiến trúc tổng quan AI AWS Advisor - Ba vùng độc lập: (1) Client Frontend với React 19 + Vite + Tailwind Dashboard (Recharts, TanStack Query) được phục vụ qua CloudFront + Route 53; (2) AI Advisor Backend gồm API Gateway (REST + Cognito JWT + Rate Limiting), SÁU Lambda Handler chia thành NĂM API Handler chuyên biệt (ai-advisor-projects-api 5 routes, ai-advisor-resources-api 2 routes, ai-advisor-insights-api 2 routes + Bedrock + SNS, ai-advisor-chat-api 1 route + Bedrock streaming, ai-advisor-alerts-api 1 route) và MỘT Collector Lambda (ai-advisor-collector trigger bởi EventBridge rate(1 hour), dùng sts:AssumeRole + 23 AWS read-actions), DynamoDB Multi-Table (4 bảng chuyên biệt ai-advisor-projects/resources/insights/alerts + 1 GSI resource_type-index, tất cả dùng chung project_id làm Partition Key cho tenant isolation), Amazon Bedrock Claude 3 Haiku (anthropic.claude-3-haiku-20240307-v1:0), Amazon SNS Topic ai-advisor-alerts với email subscription cho critical-risk alerts; (3) Customer Target AWS Accounts với Cross-Account IAM Role AIAdvisorAuditRole + trust policy + sts:AssumeRole truy cập EC2, S3, IAM, Lambda, CloudWatch." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

*Sơ đồ trên minh họa kiến trúc tổng quan của hệ thống ở **cấp độ hạ tầng AWS**, chia thành hai vùng chính:*

- **Vùng 1 - SaaS Provider Backend (Serverless)**: Edge Layer (CloudFront, Route 53) → Frontend (React 19 Web Dashboard, JavaScript SPA) với xác thực Amazon Cognito → API Layer (API Gateway + 5 Lambda API Handler) → AI Layer (Amazon Bedrock với Claude 3 Haiku) → Data Layer (DynamoDB Multi-Table: 4 bảng chuyên biệt + 1 GSI) → Automation (EventBridge cron + Collector Lambda + SNS alerts).
- **Vùng 2 - Tài khoản AWS Khách hàng**: Collector Lambda sử dụng **IAM Role Cross-Account** với `sts:AssumeRole` để quét các tài nguyên EC2, S3, IAM, Lambda và CloudWatch mà không cần lưu trữ Access Key cố định.

**Hình 3 - Luồng tương tác chi tiết của quá trình AI Analysis:**

<img src="/aws-ojt-workshop-ja/images/2-Proposal/ai_analysis.png?v=2026-07-31" alt="Luồng tương tác chi tiết giữa Frontend, API Gateway, Lambda, Bedrock, DynamoDB và SNS trong quá trình AI Analysis" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

*Hình trên minh họa chuỗi tương tác tuần tự (sequence) giữa các thành phần trong hệ thống: Frontend gửi yêu cầu phân tích qua API Gateway, Lambda triệu gọi Amazon Bedrock (Claude 3 Haiku) với context từ DynamoDB, nhận về các khuyến nghị, lưu kết quả và gửi cảnh báo qua SNS nếu vượt ngưỡng nghiêm trọng.*

#### Dịch vụ AWS Sử dụng
- **AWS Lambda:** Thực thi các API endpoints, truy vấn AI chat và cron quét dữ liệu.
- **Amazon API Gateway:** Cung cấp endpoint REST bảo mật cho ứng dụng Frontend.
- **Amazon DynamoDB:** Cơ sở dữ liệu Multi-Table NoSQL (4 bảng chuyên biệt: `projects`, `resources`, `insights`, `alerts`) lưu trữ metadata dự án, cấu hình tài nguyên và khuyến nghị AI với `project_id` Partition Key cách ly dữ liệu từng khách hàng.
- **Amazon Bedrock (Claude 3 Haiku):** Động cơ Generative AI phân tích dữ liệu JSON thô thành kế hoạch xử lý.
- **Amazon EventBridge & SNS:** Định kỳ lịch quét hàng giờ và phát thông báo qua Email.
- **AWS STS:** Chức năng ủy quyền tài khoản (`sts:AssumeRole`).

---

### 4. Kế hoạch Triển khai Kỹ thuật

#### Các Giai đoạn Thực hiện

1. **Giai đoạn 1: Bảo mật & Thiết kế Kiến trúc (Tháng 1):** Thiết lập Trust Policy IAM Cross-Account, cấu hình template IaC với AWS SAM CLI và thiết kế Multi-Table schema DynamoDB (4 bảng: `projects`, `resources`, `insights`, `alerts`; cùng 1 GSI trên `resource_type`).
2. **Giai đoạn 2: Phát triển Scanner & Tích hợp Bedrock (Tháng 2):** Lập trình bộ thu thập cấu hình bằng `boto3` (EC2, S3, IAM, Lambda, CloudWatch), viết Prompt Engineering cho Claude 3 trên Bedrock và xây dựng bộ kiểm thử Pytest/Moto. Luồng tương tác chi tiết giữa các thành phần đã được minh họa trong Hình 1 (STS AssumeRole) và Hình 3 (AI Analysis) ở §1/§3 phía trên.

3. **Giai đoạn 3: Phát triển Dashboard & AI Chatbot (Tháng 3):** Xây dựng giao diện React 19 (JavaScript SPA) với Vite, Tailwind CSS và Recharts; tích hợp AI Chatbot Copilot; kiểm thử toàn diện và đóng gói CloudFormation deployment.

---

### 5. Lộ trình & Cột mốc Thực hiện

**Hình 3 - Lộ trình Triển khai 3 Tháng với các Cột mốc Quan trọng:**

<img src="/aws-ojt-workshop-ja/images/2-Proposal/implementation_roadmap_vi.png?v=2026-08-01" alt="Lộ trình triển khai 3 tháng của dự án AI AWS Advisor - 3 box giai đoạn M1, M2, M3 nối với nhau bằng mũi tên xuống dưới thể hiện tiến trình Kiến trúc & SAM IaC → Collector Lambda & Bedrock → React Dashboard & AI Chatbot" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

*Sơ đồ trên minh họa kế hoạch thực thi dự án chia thành 3 tháng với các cột mốc tương ứng. **Tháng 1** tập trung Bảo mật & Kiến trúc (Cross-Account Trust Policy, SAM IaC, DynamoDB Multi-Table schema). **Tháng 2** hoàn thiện Core Scanner & Bedrock Integration (`boto3` Collectors, prompt engineering, Pytest unit tests). **Tháng 3** ra mắt Frontend Dashboard & AI Chatbot (React 19 + Vite + Tailwind, kiểm thử E2E, SAM CloudFormation deployment).*

---

### 6. Ước tính Chi phí (Pricing Estimation)

Chi phí ước tính hàng tháng trên 10 dự án khách hàng quét 1,000 tài nguyên AWS mỗi ngày:

| Dịch vụ AWS | Mức độ Sử dụng | Chi phí Ước tính / Tháng |
| :--- | :--- | :--- |
| **AWS Lambda** | 100,000 requests, 512 MB memory | $0.00 (Free Tier) |
| **Amazon API Gateway** | 50,000 REST requests | $0.05 |
| **Amazon DynamoDB** | On-Demand (2 GB storage, 500k reads/writes) | $0.25 |
| **Amazon Bedrock** | Claude 3 Haiku (1M Input tokens, 200k Output tokens) | $1.20 |
| **Amazon EventBridge & SNS** | 720 triggers/tháng, 100 emails | $0.01 |
| **Tổng Chi phí Ước tính Tháng** | **Serverless Pay-Per-Use** | **~$1.51 / tháng** |

*Tổng Chi phí Hạ tầng Hàng năm:* **~$18.12 USD / năm**.

---

### 7. Đánh giá Rủi ro & Giải pháp Nạp ứng

| Rủi ro Phát hiện | Mức độ | Xảy ra | Giải pháp Giảm thiểu |
| :--- | :--- | :--- | :--- |
| **Giới hạn Rate Limit của Bedrock API** | Trung bình | Thấp | Cấu hình Retry exponential backoff & cache kết quả trên DynamoDB. |
| **Khách hàng Thu hồi Quyền IAM Role** | Cao | Trung bình | Xử lý ngoại lệ `ClientError` khi gọi `sts:AssumeRole` và đánh dấu trạng thái project disconnected. |
| **Hiện tượng Virtual Hallucination của LLM** | Cao | Thấp | Yêu cầu định dạng đầu ra JSON strict schema & sử dụng regex fallback parser trên Python. |
| **Vượt Ngân sách Cloud** | Trung bình | Thấp | Cấu hình AWS Budgets cảnh báo khi ngưỡng đạt $5/tháng & giới hạn tần suất cron. |

---

### 8. Kết quả Kỳ vọng

1. **Hệ thống Kiểm toán Tự động:** Thay thế quy trình rà soát thủ công bằng hệ thống AI kiểm toán định kỳ hàng giờ.
2. **Đảm bảo An toàn Dữ liệu:** Không có rủi ro rò rỉ credential nhờ sử dụng session token ngắn hạn qua `sts:AssumeRole`.
3. **Mẫu Kiến trúc Doanh nghiệp:** Tạo ra blueprint chuẩn cho các sản phẩm B2B SaaS phát triển trên nền tảng Serverless AWS.