---
title: "Blog 2"
date: 2026-06-06
weight: 2
chapter: false
pre: " <b> 3.2. </b> "
---
# Blog 2 – AWS Shield Advanced Attack Flow Logs trong việc giám sát tấn công DDoS

## Giới thiệu

Trong quá trình thực tập, mình đã nghiên cứu và viết một bài blog với chủ đề **"AWS Shield Advanced Attack Flow Logs trong việc giám sát tấn công DDoS"**. Bài viết được thực hiện dựa trên bài giới thiệu chính thức của AWS nhằm tìm hiểu tính năng mới Attack Flow Logs của AWS Shield Advanced và cách tính năng này hỗ trợ doanh nghiệp theo dõi, phân tích cũng như điều tra các cuộc tấn công từ chối dịch vụ (DDoS).

Mục tiêu của bài blog là giúp bản thân hiểu rõ hơn về cơ chế giám sát lưu lượng tấn công trên AWS, đồng thời chia sẻ những kiến thức này với cộng đồng AWS Study Group.

## Quá trình thực hiện

Để hoàn thành bài viết, mình đã thực hiện các công việc sau:

- Đọc bài viết chính thức trên AWS Security Blog.
- Tìm hiểu về AWS Shield Advanced và các dịch vụ được bảo vệ.
- Nghiên cứu cách hoạt động của Attack Flow Logs.
- Tìm hiểu các trường dữ liệu được ghi nhận trong quá trình xảy ra tấn công DDoS.
- Tổng hợp và trình bày lại nội dung theo góc nhìn của một sinh viên đang tìm hiểu về AWS Security.

## Nội dung chính của bài viết

Trong bài blog, mình đã trình bày các nội dung chính sau:

- Giới thiệu AWS Shield Advanced và khả năng bảo vệ chống tấn công DDoS.
- Khái niệm Attack Flow Logs và vai trò của tính năng này trong việc giám sát lưu lượng tấn công.
- Các loại thông tin được ghi nhận như:
  - Địa chỉ IP nguồn và đích.
  - Giao thức mạng.
  - Số lượng packet và byte.
  - Quốc gia phát sinh lưu lượng.
  - AWS Edge Location.
  - Hành động giảm thiểu của AWS Shield.
- Khả năng xuất dữ liệu đến Amazon S3, Amazon CloudWatch Logs và Amazon Data Firehose.
- Khả năng tích hợp với Amazon Athena, CloudWatch Logs Insights và các hệ thống SIEM như Splunk để phục vụ điều tra và phân tích.

## Kiến thức và kỹ năng đạt được

Thông qua việc nghiên cứu và viết bài blog, mình đã:

- Hiểu rõ hơn về dịch vụ AWS Shield Advanced.
- Nắm được cách AWS ghi nhận và phân tích lưu lượng trong quá trình xảy ra tấn công DDoS.
- Hiểu được vai trò của Attack Flow Logs trong việc điều tra và giám sát sự cố an ninh.
- Nâng cao kỹ năng đọc tài liệu kỹ thuật chính thức của AWS.
- Rèn luyện kỹ năng tổng hợp, phân tích và trình bày các nội dung kỹ thuật theo cách dễ hiểu.

## Kết quả đạt được

Thông qua hoạt động này, mình không chỉ củng cố kiến thức về AWS Shield Advanced mà còn hiểu rõ hơn quy trình giám sát, phân tích và xử lý các cuộc tấn công DDoS trong môi trường điện toán đám mây. Đồng thời, mình cũng cải thiện kỹ năng nghiên cứu tài liệu kỹ thuật và viết bài chia sẻ kiến thức.

...Hình ảnh...

![AWS Shield Advanced Attack Flow Logs](/images/blog2.jpg)
## Link bài viết

-   https://www.facebook.com/groups/awsstudygroupfcj/posts/2175946893170271

  ## Tài liệu tham khảo
- AWS Security Blog:
  https://aws.amazon.com/blogs/security/gain-visibility-into-ddos-attacks-with-flow-logs-in-aws-shield-advanced/
