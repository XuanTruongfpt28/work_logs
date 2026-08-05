---
title: "Chiến lược Triển khai"
date: 2026-07-07
weight: 4
chapter: false
pre: " <b> 5.4. </b> "
---

# Phần 5.4 - Chiến lược Triển khai & Tích hợp Khách hàng

Tài liệu này chi tiết quy trình triển khai hạ tầng Backend Serverless, ứng dụng Frontend React và các bước tích hợp tài khoản AWS của khách hàng vào hệ thống.

---

## 1. Triển khai Backend Serverless (AWS SAM CLI)

### Bước 1: Biên dịch Mã nguồn
Biên dịch thư viện phụ thuộc bên trong container Amazon Linux để đảm bảo tính tương thích binary với AWS Lambda.

```bash
cd backend
sam build --use-container
```

**Hình 1 - Kết quả SAM CLI `sam build --use-container` (Build Succeeded):**

![SAM Build](/images/5-Workshop/5.4-Deployment-strategy/sam_build.png)

### Bước 2: Triển khai CloudFormation Stack
Thực hiện triển khai theo hướng dẫn để khởi tạo API Gateway, Lambda Functions, DynamoDB, EventBridge và SNS.

```bash
sam deploy --guided
```

**Hình 2 - Kết quả SAM CLI `sam deploy --guided` (Successfully created/updated stack):**

![SAM Deploy](/images/5-Workshop/5.4-Deployment-strategy/sam_deploy.png)

Các tham số chính:
- **Stack Name:** `ai-aws-advisor`
- **AWS Region:** `us-east-1` (hoặc region hỗ trợ Amazon Bedrock)
- **Confirm changes before deploy:** `Y`
- **Allow SAM CLI IAM role creation:** `Y`
- **Save parameters to configuration file:** `Y` (`samconfig.toml`)

### Bước 3: Lưu lại Đầu ra Outputs
Ghi lại URL `ApiGatewayEndpoint` được xuất ra từ SAM CLI (ví dụ: `https://<api-id>.execute-api.us-east-1.amazonaws.com/prod`).

---

## 2. Triển khai Frontend React Application

### Bước 1: Cấu hình Môi trường
Tạo file `.env` tại thư mục `frontend/`:

```env
VITE_API_BASE_URL=https://<your-api-id>.execute-api.us-east-1.amazonaws.com/prod
```

### Bước 2: Chạy Server Phát triển
```bash
cd frontend
npm install
npm run dev
```

### Bước 3: Đóng gói Sản phẩm
```bash
npm run build
```
Tạo mã nguồn tĩnh trong thư mục `dist/` sẵn sàng tải lên Amazon S3 + CloudFront, Vercel hoặc Netlify.

---

## 3. Quy trình Tích hợp Tài khoản Khách hàng

Các bước khách hàng thực hiện để kết nối tài khoản AWS cần kiểm toán:

1. Khách hàng đăng nhập vào AWS Console của tài khoản cần kiểm toán.
2. Truy cập **IAM -> Roles -> Create Role**.
3. Chọn loại Trusted Entity là **AWS Account** và nhập Account ID của tài khoản SaaS Provider.
4. Gắn policy `ReadOnlyAccess` cho IAM Role.
5. Sao chép **Role ARN** được tạo ra (`arn:aws:iam::<CustomerAccountID>:role/AIAdvisorAuditRole`).
6. Nhập Role ARN này trên Dashboard của AI AWS Advisor để khởi tạo Dự án.

**Hình 3 - Trang tóm tắt IAM Role phía khách hàng (đã che Account ID):**

![IAM Audit Role Summary](/images/5-Workshop/5.4-Deployment-strategy/iam_audit_role_summary.png)

**Hình 4 - Tab Trust relationships — JSON Trust policy (đã che Account ID):**

![IAM Trust Policy](/images/5-Workshop/5.4-Deployment-strategy/iam_audit_role_trust_policy.png)

---

## 4. CloudFormation Outputs (Ghi nhận sau khi Deploy)

Sau khi sam deploy --guided hoàn tất, SAM CLI in ra 5 output mà frontend và CLI script phụ thuộc. Hãy ghi nhận ngay - đây là cách duy nhất để wire SPA với API, AI scanner với IAM role khách hàng, và SNS alert pipeline với email người nhận:

| Output Key | Mô tả | Ví dụ |
|---|---|---|
| ApiGatewayEndpoint | Base URL mà React SPA gọi. | https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod |
| CollectorFunctionArn | ARN của Collector Lambda theo lịch. | arn:aws:lambda:us-east-1:111122223333:function:ai-advisor-collector |
| AlertsTopicArn | ARN SNS Topic cho cảnh báo mức độ cao (subscribe email khách hàng tại đây). | arn:aws:sns:us-east-1:111122223333:ai-advisor-alerts |
| UserPoolId | ID Cognito User Pool (dùng trong frontend .env). | us-east-1_aBcDeFgHi |
| UserPoolClientId | ID Cognito User Pool Client (dùng trong frontend .env). | 7a8b9c0d1e2f3g4h5i6j7k8l9m |

Lấy lại bất cứ lúc nào bằng một lệnh:

```bash
aws cloudformation describe-stacks 
  --stack-name ai-aws-advisor 
  --query 'Stacks[0].Outputs[].OutputValue' 
  --output text
` 

---

## 5. Triển khai Frontend Production (S3 + CloudFront)

Để deploy SPA production-grade, host folder tĩnh dist/ trên Amazon S3 sau CloudFront CDN. Bước build từ §2.3 đã tạo artifact trong `frontend/dist/` - giờ ship chúng đi.

### Bước 1: Tạo S3 bucket cho static hosting

```bash
aws s3 mb s3://ai-aws-advisor-web-prod --region us-east-1
aws s3 website s3://ai-aws-advisor-web-prod --index-document index.html --error-document index.html
` 

### Bước 2: Upload bản production build

```bash
cd frontend
aws s3 sync dist/ s3://ai-aws-advisor-web-prod --delete --cache-control 'public, max-age=31536000, immutable'
```

### Bước 3: Tạo CloudFront distribution trỏ về bucket

```bash
aws cloudfront create-distribution 
  --origin-domain-name ai-aws-advisor-web-prod.s3.amazonaws.com 
  --default-root-object index.html
` 

{{% notice warning %}}Với SPA routing, cấu hình CloudFront custom error response: map cả 403 và 404 về /index.html với HTTP 200, để client-side route như /projects/abc không vỡ khi hard reload.{{% /notice %}}

### Bước 4: Set biến môi trường SPA lúc build

React app đọc `VITE_API_BASE_URL`, `VITE_USER_POOL_ID`, và `VITE_USER_POOL_CLIENT_ID` **lúc build** (Vite inline chúng). Set trong `frontend/.env.production` trước khi `npm run build`:

```env
VITE_API_BASE_URL=https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod
VITE_USER_POOL_ID=us-east-1_aBcDeFgHi
VITE_USER_POOL_CLIENT_ID=7a8b9c0d1e2f3g4h5i6j7k8l9m
VITE_AWS_REGION=us-east-1
```

---

## 6. Hướng dẫn Dashboard: Thêm Customer Project

Khi SPA đã live, operator thêm một tài khoản khách hàng qua 4 bước trên dashboard:

1. **Đăng nhập** tại URL CloudFront bằng Cognito credentials đã tạo ở §5.2.6. JWT được lưu trong localStorage và gắn vào mọi API call qua Axios interceptor.
2. **Vào Projects -> Add Project**. Điền: project name, AWS region cần quét, và Role ARN do khách hàng cung cấp (xem §3 phía trên).
3. **Trigger manual scan** bằng cách bấm Sync Now. Frontend POST lên /projects/{id}/sync, Lambda sẽ invoke Collector. Scan đầu tiên thường hoàn tất trong 30-60 giây cho tài khoản AWS nhỏ.
4. **Mở Dashboard** để xem các tab Cost / Performance / Security đã populate với AI insights. Bấm vào bất kỳ card nào để drill down vào raw JSON resource data.

EventBridge schedule theo giờ giữ data tươi ở background không cần operator can thiệp.

**Hình 6 - Dashboard sau scan đầu tiên thành công, hiển thị 4 KPI card và insight cho từng dự án được sinh bởi Bedrock Claude 3 Haiku:**

![Dashboard Overview](/images/5-Workshop/5.4-Deployment-strategy/dashboard_overview.png)

---

## Tóm tắt Phần

Chiến lược triển khai của AI AWS Advisor gồm bốn giai đoạn chính: **(1)** triển khai backend bằng AWS SAM và ghi nhận các CloudFormation Outputs, **(2)** phát triển và kiểm thử ứng dụng frontend trên môi trường cục bộ, **(3)** tích hợp tài khoản AWS của khách hàng thông qua cơ chế IAM Role (cross-account), và **(4)** triển khai ứng dụng React lên môi trường production bằng Amazon S3 kết hợp CloudFront. Toàn bộ quy trình có thể được tái lập từ mã nguồn trong repository thông qua chuỗi lệnh `sam deploy --guided`, `npm run build` và `aws s3 sync`, giúp việc triển khai trở nên nhất quán, dễ bảo trì và thuận tiện tích hợp vào các quy trình DevOps.
