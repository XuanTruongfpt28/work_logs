---
title: "Vận hành & Dọn dẹp"
date: 2026-05-01
weight: 6
chapter: false
pre: " <b> 5.6. </b> "
---

# Phần 5.6 - Vận hành, Dọn dẹp Tài nguyên & Đánh giá Kiến trúc

Tài liệu này hướng dẫn quy trình tiêu hủy tài nguyên hệ thống an toàn, đồng thời tổng kết các bài học kiến trúc và định hướng phát triển cho **AI AWS Advisor**.

---

## 1. Tiêu hủy Tài nguyên Cloud Tự động

Do toàn bộ hạ tầng Backend được quản lý dưới dạng mã (IaC) qua AWS SAM CLI, việc dọn dẹp tài nguyên được thực hiện hoàn toàn tự động.

Để xóa CloudFormation stack và giải phóng tất cả Lambda functions, API Gateway, EventBridge rules và DynamoDB tables:

```bash
cd backend
sam delete
```

**Hình 1 - Kết quả SAM CLI `sam delete --no-prompts` (Successfully deleted stack):**

<img src="/aws-ojt-workshop-ja/images/5.6-Operations-cleanup/sam_delete.png?v=2026-08-01-r1" alt="Terminal PowerShell 7 hiển thị lệnh sam delete: CloudFormation stack deletion với 9 thao tác - Delete (Lambda functions, DynamoDB tables, SNS topic, API Gateway, EventBridge rule, IAM role), Successfully deleted stack ai-aws-advisor-backend, dọn dẹp S3 bucket, tiết kiệm ước tính $42.30/tháng" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

Xác nhận việc xóa khi được hỏi tên stack (`ai-aws-advisor`).

---

## 2. Danh mục Kiểm tra Sau khi Dọn dẹp

- **Amazon CloudWatch Log Groups:** Kiểm tra và xóa thủ công các nhóm log có tiền tố `/aws/lambda/ai-aws-advisor-*` để tránh chi phí lưu trữ tích lũy.
- **Thu hồi Customer IAM Role:** Xóa các IAM Role ủy quyền (`AIAdvisorAuditRole`) trên các tài khoản AWS của khách hàng.

---

## 3. Tổng kết Kiến trúc & Bài học Kinh nghiệm

1. **Mô hình Bảo mật Zero-Trust:** Áp dụng `sts:AssumeRole` giúp loại bỏ hoàn toàn nguy cơ rò rỉ Access Key dài hạn, đáp ứng các tiêu chuẩn tuân thủ doanh nghiệp (SOC2 / ISO27001).
2. **Tối ưu Chi phí với Serverless:** Sử dụng AWS Lambda và thiết kế Multi-Table DynamoDB (4 bảng chuyên biệt, tất cả dùng `PAY_PER_REQUEST`) giúp chi phí duy trì hệ thống ở mức $0/tháng khi nhàn rỗi.
3. **AI là Động cơ Vận hành:** Amazon Bedrock (Claude 3 Haiku) chứng minh LLM hoạt động cực kỳ hiệu quả như một công cụ phân tích cấu hình thô thành dữ liệu cấu trúc JSON chuẩn.

---

## 4. Hướng Phát triển Tương lai

- **Xử lý Sự kiện Real-time:** Chuyển từ quét định kỳ theo giờ sang xử lý luồng sự kiện CloudTrail theo thời gian thực qua EventBridge Event Bus.
- **Tự động Sửa lỗi (Autopilot):** Thêm quyền ghi có kiểm soát để AI Advisor tự động sửa lỗi (ví dụ: tự động bật mã hóa cho S3 bucket).
- **Real-time Ingestion:** Chuyển từ hourly cron scanning sang real-time CloudTrail event stream ingestion qua EventBridge Event Buses.
- **Automated Remediation (Autopilot):** Thêm write-enabled IAM permissions cho các autonomous patch đã được duyệt (vd: tự động mã hóa S3 bucket chưa encrypted).
- **Cross-Account Organization Audit:** Mở rộng Collector để duyệt từng account trong AWS Organization (qua `organizations:ListAccounts`) và gom tất cả finding vào một dashboard, thay vì mô hình one-project-per-IAM-Role hiện tại.
- **AI Cost Forecasting:** Mở rộng AI Analyzer để dự báo cost trajectory 30 ngày tới theo từng project bằng CloudWatch metrics + Bedrock summarization.
- **Multi-Region Failover:** Replicate 4 bảng DynamoDB sang region phụ qua Global Tables cho HA/DR.

---

## 5. Chi phí Hàng tháng (Idle vs Active)

Con số $42.30/tháng trong ảnh là **chi phí idle steady-state** sau chu kỳ phát triển đầu tiên. Dưới đây là breakdown chi phí giả định tác giả workshop chạy stack 24/7 không có traffic:

| Service | Quantity | Pricing Model | Chi phí tháng (USD) |
|---|---|---|---|
| API Gateway REST API | 1 stage + 1 usage plan | $3.50/triệu request | ~$0.00 (dưới quota) |
| Lambda invocations | 6 function | $0.20/triệu + GB-second | ~$0.50 (1 scan/giờ) |
| DynamoDB on-demand | 4 bảng | $1.25/triệu WCU + RRU | ~$0.50 (~10K write/ngày) |
| Cognito User Pool | 1 pool + 1 client | Free đến 50K MAU | $0.00 |
| SNS topic | 1 topic + 1 email sub | $0.50/triệu + $0.10/100K email | ~$0.10 (chỉ alerts) |
| EventBridge schedule | 1 rule | $1.00/triệu invocations | ~$0.20 (720/ngày) |
| CloudWatch Logs | ~6 log group | $0.50/GB ingested | ~$5.00 (verbose logs) |
| Bedrock Claude 3 Haiku | 1 model | $0.25/triệu input + $1.25/triệu output tokens | ~$30.00 (~120M tokens/tháng) |
| S3 (frontend hosting) | 1 bucket | $0.023/GB storage + requests | ~$0.50 |
| CloudFront | 1 distribution | $0.085/GB data transfer | ~$5.00 (low traffic) |
| **Tổng (idle)** | | | **~$42.30** |

Hai chi phí lớn nhất:

1. **Amazon Bedrock** chiếm ~70%. Cách giảm: cache kết quả prompt giống nhau trong DynamoDB 24h, dùng mazon.nova-lite-v1:0 (rẻ hơn, không cần duyệt Anthropic), hoặc batch insights generation theo dự án/ngày thay vì theo scan.
2. **CloudWatch Logs** chiếm ~12%. Cách giảm: đặt retention từ 'Never expire' xuống 7 ngày qua retention_in_days: 7 trong SAM template, hoặc chỉ log INFO ở hot path.

---

## 6. Checklist An toàn Trước khi Xóa

Trước khi chạy sam delete, đi qua checklist 7 điểm để tránh để lại orphan resource tiếp tục phát sinh chi phí:

- [ ] **Snapshot dữ liệu production** (nếu có) bằng export DynamoDB tables sang S3 qua aws dynamodb export-table-to-point-in-time. Stack mặc định không có data production, nhưng verify trước khi xóa.
- [ ] **Tắt EventBridge rule** nếu muốn dừng scan ngay mà chưa xóa stack: aws events disable-rule --name ai-advisor-schedule.
- [ ] **Confirm không có API call đang chạy** bằng tail CloudWatch logs trong giờ qua. Một scan đang chạy có thể để partial data trong DynamoDB sau khi delete.
- [ ] **Note danh sách Cognito users** - sẽ mất khi stack bị xóa. Backup qua aws cognito-idp list-users --user-pool-id <id> > users.json nếu cần khôi phục sau.
- [ ] **Disable API Gateway usage plan** để dừng tracking throttling trên stage đã xóa.
- [ ] **Xóa S3 deployment artifact** mà SAM đã tạo (sam deploy tạo bucket tên aws-sam-cli-managed-default-samclisourcebucket-...).
- [ ] **Thu hồi customer IAM role** trong tài khoản đích (các tài khoản AWS riêng mà tác giả workshop không kiểm soát, nhưng document action cho khách hàng).

Sau khi hoàn thành checklist và xác nhận stack deletion output, toàn bộ deploy footprint đã được dọn sạch và AWS bill về baseline.

---

## Tóm tắt Phần

Cleanup tập trung qua sam delete và hoàn tất dưới 60 giây. Tổng chi phí idle ~$42.30/tháng bị chi phối bởi Bedrock inference; log retention và prompt result caching là 2 lever lớn nhất để giảm thêm. Đi qua checklist 7 điểm đảm bảo không có orphan resource sống sót sau teardown.
