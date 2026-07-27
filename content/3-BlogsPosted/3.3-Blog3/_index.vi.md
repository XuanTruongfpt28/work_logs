---
title: "Blog 3"
date: 2026-06-16
weight: 3
chapter: false
pre: " <b> 3.3. </b> "
---
 
# HIỆN ĐẠI HÓA QUY TRÌNH KYC VỚI SERVERLESS & AGENTIC AI

Trong quá trình thực tập, mình đã tìm hiểu một bài viết trên **AWS Architecture Blog** giới thiệu cách IBM và AWS hiện đại hóa quy trình **Know Your Customer (KYC)** bằng cách kết hợp các công nghệ **Serverless**, **Event-Driven Architecture**, **Retrieval-Augmented Generation (RAG)** và **Agentic AI**. Bài viết trình bày một kiến trúc giúp tự động hóa quá trình xác minh danh tính khách hàng, đồng thời nâng cao khả năng mở rộng, đáp ứng các yêu cầu tuân thủ và cải thiện hiệu quả vận hành.

## Tóm tắt nội dung

Kiến trúc được đề xuất tập trung vào việc chuyển đổi các hệ thống KYC truyền thống, vốn phụ thuộc nhiều vào việc xác minh thủ công và xử lý theo lô (batch processing), sang một quy trình thông minh có khả năng xử lý gần như theo thời gian thực.

Một số dịch vụ AWS đóng vai trò quan trọng trong giải pháp này gồm:

- Amazon MSK hỗ trợ xử lý các yêu cầu KYC theo mô hình Event-Driven.
- AWS Lambda thực thi các tác vụ nghiệp vụ theo mô hình Serverless.
- Amazon Bedrock cung cấp các mô hình nền tảng để triển khai AI Agents.
- Amazon OpenSearch Serverless lưu trữ vector embeddings phục vụ kỹ thuật Retrieval-Augmented Generation (RAG).
- AgentCore Gateway kết nối các dịch vụ AI trên AWS với các hệ thống ngân hàng đang vận hành tại chỗ (On-premises).

Bên cạnh đó, kiến trúc còn sử dụng một **Supervisor Agent** để điều phối nhiều AI Agent chuyên biệt, chẳng hạn như xác minh giấy tờ, phát hiện gian lận, kiểm tra danh sách cấm vận và đánh giá mức độ rủi ro của khách hàng.

## Những điều mình học được

Qua bài viết này, mình học được nhiều khái niệm kiến trúc quan trọng như:

- Event-Driven Architecture giúp loại bỏ độ trễ do xử lý theo lô và rút ngắn thời gian xác minh khách hàng xuống gần thời gian thực.
- Multi-Agent AI cho phép nhiều AI Agent phối hợp với nhau để thực hiện các nhiệm vụ xác minh chuyên biệt.
- Retrieval-Augmented Generation (RAG) giúp AI đưa ra kết quả chính xác hơn bằng cách truy xuất các tài liệu và quy định mới nhất thay vì chỉ dựa trên kiến thức đã được huấn luyện trước.
- Kiến trúc Hybrid Cloud giúp các tổ chức hiện đại hóa hệ thống ngân hàng cũ mà không cần phải di chuyển toàn bộ hạ tầng lên môi trường đám mây.

## Phân tích và đánh giá

Bên cạnh việc tìm hiểu kiến trúc được đề xuất, mình cũng có một số góc nhìn về những thách thức thực tế mà bài viết đề cập hoặc chưa làm rõ.

### Góc độ kỹ thuật

Bài viết cho biết thời gian xử lý KYC có thể giảm từ vài ngày xuống chỉ còn vài phút. Tuy nhiên, bài viết chưa giải thích rõ cách hệ thống xử lý các trường hợp phức tạp như khách hàng là người có ảnh hưởng chính trị (PEP), khách hàng có hai quốc tịch hoặc các loại giấy tờ hiếm gặp.

### Góc độ tuân thủ

Trong lĩnh vực tài chính, các tổ chức vẫn phải chịu trách nhiệm pháp lý đối với mọi quyết định phê duyệt, ngay cả khi AI tham gia vào quá trình xử lý. Vì vậy, các quyết định do AI đưa ra cần có khả năng giải thích và kiểm chứng để đáp ứng các yêu cầu của cơ quan quản lý.

### Góc độ bảo mật

Kiến trúc có đề cập đến việc xác minh giấy tờ nhưng chưa trình bày chi tiết về cách phòng chống các mối đe dọa hiện đại như tài liệu giả mạo bằng AI (deepfake), danh tính tổng hợp (synthetic identity), tấn công đối kháng (adversarial attacks) hoặc prompt injection nhằm vào các AI Agent.

### Góc độ chi phí

Mặc dù Serverless giúp giảm chi phí quản lý hạ tầng, nhưng tổng chi phí vận hành của toàn bộ hệ thống, bao gồm Amazon MSK, AWS Lambda, Amazon Bedrock, OpenSearch Serverless và việc tích hợp với các hệ thống hiện có, vẫn cần được đánh giá cẩn thận trước khi triển khai trong môi trường thực tế.

## Kỹ năng đạt được

Việc hoàn thành bài blog này giúp mình phát triển nhiều kỹ năng thực tế như:

- Hiểu rõ hơn về các mô hình kiến trúc hiện đại trên nền tảng điện toán đám mây.
- Tìm hiểu cách Agentic AI có thể được ứng dụng trong lĩnh vực tài chính.
- Phân tích kiến trúc cloud dưới nhiều góc nhìn như kỹ thuật, bảo mật, tuân thủ và kinh doanh.
- Đọc và phân tích các bài viết chuyên sâu trên AWS Architecture Blog.
- Tóm tắt các chủ đề kỹ thuật phức tạp thành nội dung rõ ràng, có cấu trúc và dễ hiểu.

## Cảm nhận

Thông qua bài blog này, mình nhận ra rằng việc thiết kế một kiến trúc cloud không chỉ đơn giản là lựa chọn các dịch vụ AWS phù hợp. Một hệ thống triển khai thực tế còn phải xem xét nhiều yếu tố khác như yêu cầu pháp lý, rủi ro bảo mật, chi phí vận hành và khả năng đảm bảo tính ổn định của hệ thống.

Mình cũng hiểu rằng các bài viết trên AWS Architecture Blog mang lại nhiều ý tưởng và định hướng kiến trúc hữu ích. Tuy nhiên, trước khi áp dụng vào môi trường thực tế, các kỹ sư vẫn cần đánh giá kỹ các giả định kỹ thuật cũng như những thách thức có thể phát sinh trong quá trình triển khai.

...Hình ảnh...
![Modernizing KYC Architecture](/images/blog3.jpg)

## Liên kết tham khảo

- AWS Architecture Blog: https://aws.amazon.com/blogs/architecture/modernizing-kyc-with-aws-serverless-and-agentic-ai/
- Facebook Post: https://www.facebook.com/groups/awsstudygroupfcj/permalink/2185226422242318/