---
title: "Worklog Tuần 6"
date: 2026-06-15
weight: 6
chapter: false
pre: " <b> 1.6. </b> "
---
{{% notice warning %}}
⚠️ **Lưu ý:** Các thông tin dưới đây chỉ nhằm mục đích tham khảo, vui lòng **không sao chép nguyên văn** cho bài báo cáo của bạn kể cả warning này.
{{% /notice %}}


### Mục tiêu tuần 6:

- Tìm hiểu dịch vụ Elastic Load Balancing (ELB) trên AWS. 
- Hiểu vai trò của Auto Scaling trong việc mở rộng và duy trì tính sẵn sàng của hệ thống. 
- Thực hành triển khai Load Balancer và Auto Scaling Group. 
- Tìm hiểu cách xây dựng hệ thống có khả năng chịu tải và tự động mở rộng.

### Các công việc cần triển khai trong tuần này:
| Ngày | Công việc | Ngày bắt đầu | Ngày hoàn thành | Tài liệu tham khảo |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | --------------- | ----------------------------------------- |
| 2 | - Ôn tập kiến thức về Amazon RDS đã học ở tuần trước.<br>- Tìm hiểu các khái niệm cơ bản của Elastic Load Balancing (ELB) và các loại Load Balancer trên AWS. | 15/06/2026 | 15/06/2026 | https://000058.awsstudygroup.com/vi/1-introduce/ |
| 3 | - Tìm hiểu cách hoạt động của Application Load Balancer (ALB).<br>- Thực hành tạo Target Group và cấu hình Health Check cho các EC2 Instance. | 16/06/2026 | 16/06/2026 | https://000058.awsstudygroup.com/vi/2-prerequiste/ |
| 4 | - Triển khai Application Load Balancer.<br>- Đăng ký nhiều EC2 Instance vào Target Group.<br>- Kiểm tra việc phân phối lưu lượng giữa các EC2 Instance. | 17/06/2026 | 17/06/2026 | https://000058.awsstudygroup.com/vi/3-createalb/ |
| 5 | - Tìm hiểu về Amazon EC2 Auto Scaling.<br>- Tạo Launch Template và Auto Scaling Group.<br>- Cấu hình chính sách tự động mở rộng dựa trên mức sử dụng CPU. | 18/06/2026 | 18/06/2026 | https://000058.awsstudygroup.com/vi/4-createasg/ |
| 6 | - Kiểm tra hoạt động của Load Balancer và Auto Scaling Group.<br>- Mô phỏng lưu lượng truy cập để quan sát quá trình Scale Out và Scale In.<br>- Ôn tập nội dung trong tuần và hoàn thành bài thực hành. | 19/06/2026 | 19/06/2026 | https://000058.awsstudygroup.com/vi/5-cleanup/ |


### Kết quả đạt được tuần 6:
- Hiểu được vai trò của Elastic Load Balancing (ELB) trong việc phân phối lưu lượng truy cập giữa nhiều EC2 Instance. 
- Nắm được các thành phần chính của Elastic Load Balancing, bao gồm: 
  - Application Load Balancer (ALB) 
  - Target Group 
  - Listener 
  - Health Check 
- Tạo thành công Application Load Balancer và cấu hình Target Group cho các EC2 Instance. 
- Hiểu cách Health Check hoạt động và biết cách kiểm tra trạng thái của các máy chủ phía sau Load Balancer. 
- Tìm hiểu dịch vụ Amazon EC2 Auto Scaling và vai trò của nó trong việc tự động mở rộng hoặc thu hẹp số lượng EC2 Instance theo nhu cầu sử dụng. 
- Thực hành tạo: 
  - Launch Template 
  - Auto Scaling Group 
  - Scaling Policy 
- Quan sát quá trình Scale Out và Scale In khi hệ thống thay đổi tải, từ đó hiểu được cách AWS tự động duy trì hiệu năng và tính sẵn sàng của ứng dụng. 
- Hoàn thành các bài thực hành về Elastic Load Balancing và Auto Scaling theo lộ trình Cloud Journey. 
- Có nền tảng để tiếp tục tìm hiểu về triển khai ứng dụng có tính sẵn sàng cao và kiến trúc AWS trong những tuần tiếp theo.

