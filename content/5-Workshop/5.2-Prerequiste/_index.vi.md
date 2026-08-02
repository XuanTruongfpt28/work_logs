---
title: "Yêu cầu & Chuẩn bị"
date: 2026-05-01
weight: 2
chapter: false
pre: " <b> 5.2. </b> "
---

# Phần 5.2 - Yêu cầu Hệ thống & Môi trường

Để triển khai và vận hành hệ thống **AI AWS Advisor**, môi trường phát triển và tài khoản AWS cần đáp ứng các điều kiện tiên quyết sau.

---

## 1. Yêu cầu Tài khoản AWS & Quyền Dịch vụ

- **Tài khoản AWS:** Cần có quyền Quản trị viên (`AdministratorAccess`).
- **Quyền Truy cập Amazon Bedrock Model:**
  - Mô hình `Claude 3 Haiku` phải được kích hoạt tại region `us-east-1` hoặc `ap-southeast-1` trên AWS Console (**Bedrock -> Model access -> Request access**).
  - Model ID / ARN: `anthropic.claude-3-haiku-20240307-v1:0`.
  - **Lưu ý quan trọng với model của Anthropic:** Bedrock yêu cầu bạn gửi **form Mô tả Use Case** (Tên công ty, Website, Ngành, Mô tả use case) một lần qua Chat/Text Playground trước lần gọi đầu tiên. Sau khi Anthropic duyệt (thường trong vòng 24 giờ), model mới có thể gọi được. Nếu bạn thấy thông báo *"Your account is not authorized to perform this action"* thì đó chính là lý do cần điền form này.
  - **Phương án thay thế (không cần duyệt):** Đổi Model ID trong `template.yaml` sang `amazon.nova-lite-v1:0` — các model first-party của Amazon không yêu cầu bước duyệt thủ công của Anthropic.
- **AWS CLI v2:** Đã cài đặt và cấu hình lệnh (`aws configure`).

**Hình - Cấu hình `aws configure` và xác minh bằng `aws sts get-caller-identity`:**

<img src="/aws-ojt-workshop-ja/images/5.2-Prerequiste/aws_cli_configure.png?v=2026-08-01-r1" alt="Terminal PowerShell 7 hiển thị các prompt của aws configure cho AWS Access Key ID, AWS Secret Access Key, Default region name (us-east-1), Default output format (json), tiếp theo là lệnh aws sts get-caller-identity trả về JSON với UserId, Account, và Arn xác nhận IAM credentials hợp lệ" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Hình 1 - Trang Amazon Bedrock Model Access — toàn bộ model Anthropic Claude 3 family đã được cấp quyền (trạng thái Access granted tại region `us-east-1`):**

<img src="/aws-ojt-workshop-ja/images/5.2-Prerequiste/bedrock_model_access.jpg?v=2026-08-01-r3" alt="Trang Amazon Bedrock Model Access hiển thị toàn bộ model Anthropic Claude 3 family (3.5 Sonnet v2, 3.5 Sonnet, 3 Opus, 3 Sonnet, 3 Haiku) đều có trạng thái Access granted màu xanh tại region us-east-1" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

> **Ghi chú kiểm chứng:** Ảnh chụp được lấy từ tài khoản AWS của tác giả workshop tại thời điểm xuất bản. Nếu console của bạn hiển thị *"Not available"* hoặc *"Access denied"* cho bất kỳ model Anthropic nào, hãy mở **Bedrock Chat/Text Playground** một lần và gửi **form Use Case** (Tên công ty, Website, Ngành, Đối tượng, Mô tả use case). Anthropic thường duyệt trong vòng 24 giờ. Hoặc đơn giản hơn, đổi Model ID trong `template.yaml` sang `amazon.nova-lite-v1:0` — không cần bước duyệt thủ công.

---

## 2. Toolchain Verification

Trước khi triển khai, hãy chạy các lệnh dưới đây trong PowerShell / Terminal và đối chiếu kết quả với phiên bản được khuyến nghị:

**Hình 2 - Kiểm tra phiên bản toolchain: `aws / sam / python / node / docker`:**

<img src="/aws-ojt-workshop-ja/images/5.2-Prerequiste/toolchain_check.png?v=2026-08-01-r1" alt="Terminal PowerShell 7 hiển thị kết quả kiểm tra phiên bản AWS CLI (2.17.10), SAM CLI (1.124.0), Python (3.12.6), Node.js (20.15.0), Docker (27.0.3) và lệnh aws sts get-caller-identity trả về thông tin IAM user của tác giả workshop" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

```bash
# Kiểm tra phiên bản các công cụ
aws --version
sam --version
python --version
node --version
docker --version
```

Nếu bất kỳ lệnh nào trả về *"command not found"*, hãy cài đặt trước khi tiếp tục:
- **AWS CLI:** Tải từ [AWS CLI v2 installer](https://awscli.amazonaws.com/AWSCLIV2.msi).
- **AWS SAM CLI:** `pip install aws-sam-cli` hoặc tải từ [AWS SAM CLI releases](https://github.com/aws/aws-sam-cli/releases).
- **Docker Desktop:** Cài từ [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/) (yêu cầu WSL 2 backend).
- **Python:** Từ [python.org](https://www.python.org/downloads/) (đánh dấu **"Add to PATH"** khi cài).
- **Node.js:** Từ [nodejs.org](https://nodejs.org/) (khuyến nghị bản LTS 20.x).

---

## 3. Công cụ Backend Serverless

- **AWS SAM CLI:** Bộ công cụ đóng gói và triển khai cơ sở hạ tầng dưới dạng mã (IaC - `template.yaml`).
- **Python 3.12+:** Ngôn ngữ lập trình chính cho các API Handlers và AI Analyzer trên AWS Lambda.
- **Docker Desktop:** Cần thiết cho SAM CLI (`sam build --use-container`) để biên dịch mã nguồn tương thích với môi trường Amazon Linux 2023 của Lambda.

---

## 4. Công cụ Frontend & Giả lập Môi trường

- **Node.js (v20.0 trở lên):** Môi trường thực thi cho React 19 / Vite 8. (Vite 8 yêu cầu Node 20+; Node 18 cũ sẽ fail khi cài đặt dependencies.)
- **npm / pnpm / yarn:** Trình quản lý thư viện Node.js.
- **DynamoDB Local:** Giả lập DynamoDB offline qua Docker Compose (`amazon/dynamodb-local`) để phát triển không cần chạm vào DB thật trên cloud.

Tham chiếu lại **§2 Toolchain Verification** phía trên — cùng các lệnh (`aws --version`, `sam --version`, `python --version`, `node --version`, `docker --version`) đã xác nhận tất cả công cụ được liệt kê trong phần này.

---

## 5. Thư viện Python Backend

Backend khai báo toàn bộ package Python trong `backend/requirements.txt`. Các thư viện quan trọng nhất:

| Thư viện | Mục đích |
|---|---|
| `boto3` | AWS SDK cho Python (DynamoDB, Bedrock, STS, EC2, S3, IAM, CloudWatch) |
| `aws-lambda-powertools` | Structured logging, custom metrics, distributed tracing |
| `pydantic` | Validate dữ liệu runtime cho JSON payload |
| `botocore` | Low-level AWS SDK (đi kèm `boto3`) — cần thiết cho client `STS`, `bedrock-runtime` |

{{% notice warning %}}
**Không commit secret trong `requirements-dev.txt`** lên Git public. File `env.json` (SAM dùng qua `--parameter-overrides`) chứa email nhận alert và override region Bedrock — coi như config runtime, không phải mã nguồn.
{{% /notice %}}

---

## 6. Khởi tạo Amazon Cognito User Pool

AI AWS Advisor dùng **Amazon Cognito** làm identity provider. Template SAM (`template.yaml`) tự động tạo:

- **User Pool** (`ai-advisor-user-pool`) với `email` là username attribute và bật auto-verified email.
- **User Pool Client** (`ai-advisor-web-client`) hỗ trợ public OAuth flow (`ALLOW_USER_SRP_AUTH`, `ALLOW_USER_PASSWORD_AUTH`, `ALLOW_REFRESH_TOKEN_AUTH`).

Sau khi deploy, lấy 2 identifier từ CloudFormation outputs:

```bash
aws cloudformation describe-stacks \
  --stack-name ai-aws-advisor \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId` || OutputKey==`UserPoolClientId`].OutputValue'
```

Tạo ít nhất 1 user Cognito để React dashboard đăng nhập được:

```bash
aws cognito-idp admin-create-user \
  --user-pool-id <UserPoolId> \
  --username admin@example.com \
  --user-attributes Name=email,Value=admin@example.com Name=email_verified,Value=true \
  --temporary-password "ChangeMe123!" \
  --message-action SUPPRESS
```

User phải đổi mật khẩu tạm thời ở lần đăng nhập đầu tiên.

---

## 7. DynamoDB Local (Phát triển Offline)

Để phát triển local không đụng database cloud, chạy **DynamoDB Local** trong Docker:

```bash
docker run -d --name dynamodb-local \
  -p 8000:8000 \
  amazon/dynamodb-local:latest \
  -jar DynamoDBLocal.jar -inMemory -sharedDb
```

Sau đó trỏ Lambda env về local bằng cách override `DYNAMODB_ENDPOINT_URL`:

```bash
DYNAMODB_ENDPOINT_URL=http://localhost:8000 \
  AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy AWS_DEFAULT_REGION=us-east-1 \
  sam local start-api --env-vars env.json
```

{{% notice info %}}
**Production phải để `DYNAMODB_ENDPOINT_URL=""`** (chuỗi rỗng). Template SAM mặc định là rỗng, nên Lambda khi deploy sẽ gọi DynamoDB thật.
{{% /notice %}}

---

## Tóm tắt Phần

Sau khi hoàn thành các bước trên, bạn đã có:
- Tài khoản AWS Administrator đã xác nhận Bedrock model access (hoặc thay bằng Nova Lite).
- Toolchain Python/Node/Docker/SAM đã verified.
- Cognito User Pool + Client đã được provision (sau lần `sam deploy` đầu tiên).
- Tuỳ chọn container DynamoDB Local để iterate offline.