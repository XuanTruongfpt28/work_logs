---
title: "Workshop"
date: 2026-05-01
weight: 5
chapter: false
pre: " <b> 5. </b> "
---

# AI AWS Advisor (Enterprise SaaS)

#### Tổng quan

**AI AWS Advisor** là nền tảng B2B SaaS (Software as a Service) cấp doanh nghiệp ứng dụng AI thế hệ mới (**Amazon Bedrock - Claude 3 Haiku**) để tự động quét, phân tích và đưa ra khuyến nghị tối ưu hóa cho hạ tầng AWS của khách hàng.

Hệ thống giải quyết 3 thách thức cốt lõi trong Vận hành Đám mây (CloudOps):
1. **Bảo mật (Security):** Phát hiện lỗ hổng bảo mật như S3 Buckets công khai, IAM Roles cấp thừa quyền.
2. **Tối ưu Chi phí (Cost Optimization):** Phát hiện lãng phí tài nguyên (EC2 nhàn rỗi, EBS Volume không gắn vào máy chủ, Elastic IP không sử dụng) và tính toán số tiền tiết kiệm hàng tháng.
3. **Hiệu năng & Độ tin cậy (Performance & Reliability):** Đề xuất cải tiến kiến trúc (ví dụ: cấu hình Provisioned Concurrency cho AWS Lambda để tránh cold start).

---

#### Đặc điểm Kỹ thuật & Nổi bật

- **Bảo mật Zero-Trust (Cross-Account STS):** Sử dụng `sts:AssumeRole` tạo credential tạm thời ngắn hạn, không lưu giữ Access Key dài hạn của khách hàng.
- **Kiến trúc Serverless 100%:** Xây dựng trên AWS Lambda, Amazon API Gateway, Amazon EventBridge giúp chi phí duy trì nhàn rỗi xấp xỉ $0.
- **Thiết kế Multi-Table (Amazon DynamoDB):** Bốn bảng chuyên biệt (projects, resources, insights, alerts) dùng chung `project_id` Partition Key để cách ly tenant, cùng 1 GSI (`resource_type-index`) trên `ai-advisor-resources` cho truy vấn cross-project.
- **Generative AI Copilot (Amazon Bedrock):** Tích hợp Claude 3 Haiku tự động tạo báo cáo và trò chuyện trực tiếp về hạ tầng.

---

#### Nội dung Báo cáo

1. [Tổng quan Workshop](5.1-workshop-overview/)
2. [Yêu cầu & Chuẩn bị Môi trường](5.2-prerequiste/)
3. [Kiến trúc & Thiết kế Kỹ thuật](5.3-architecture-design/)
4. [Chiến lược Triển khai & Tích hợp Khách hàng](5.4-deployment-strategy/)
5. [Kiểm thử & Đảm bảo Chất lượng](5.5-quality-assurance/)
6. [Vận hành, Dọn dẹp & Đánh giá Kiến trúc](5.6-operations-cleanup/)