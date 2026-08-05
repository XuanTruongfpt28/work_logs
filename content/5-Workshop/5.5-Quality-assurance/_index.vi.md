---
title: "Kiểm thử & Chất lượng"
date: 2026-07-07
weight: 5
chapter: false
pre: " <b> 5.5. </b> "
---

# Phần 5.5 - Kiểm thử & Đảm bảo Chất lượng

Để đảm bảo tính tin cậy cao, độ an toàn và toàn vẹn dữ liệu cho **AI AWS Advisor**, dự án áp dụng kiến trúc kiểm thử tự động 2 lớp độc lập.

---

## 1. Môi trường Kiểm thử Backend (Pytest + Moto)

Backend sử dụng `pytest` kết hợp với thư viện giả lập môi trường AWS (`moto`) để kiểm thử logic nghiệp vụ mà không phát sinh chi phí hay gọi đến API thật.

### Công nghệ sử dụng:
- **`pytest` & `pytest-mock`:** Khung kiểm thử và giả lập hàm fixture.
- **`moto`:** Chặn các cuộc gọi `boto3` AWS SDK, tạo cơ sở dữ liệu DynamoDB ảo chạy trên bộ nhớ RAM.
- **Giả lập Bedrock:** Chặn hàm `invoke_model()` của Bedrock để trả về phản hồi JSON chuẩn, kiểm thử khả năng xử lý dữ liệu AI và xử lý lỗi.

```bash
cd backend
python -m pytest tests/ -v
```
**Hình 1.** Kết quả kiểm thử **Backend** bằng lệnh `pytest tests/ -v`, trong đó toàn bộ **26 bài kiểm thử** thuộc **7 tệp kiểm thử** (API Handlers, AI Analyzer và Shared Database Layer) đều thực thi thành công. Quá trình kiểm thử hoàn tất trong **4,32 giây** và đạt **93% độ bao phủ mã nguồn (Code Coverage)**, cho thấy các thành phần cốt lõi của hệ thống đã được kiểm chứng và hoạt động ổn định.



![Pytest_output](/images/5-Workshop/5.5-Quality-assurance/pytest_output.png)




---

## 2. Môi trường Kiểm thử Frontend (Vitest + React Testing Library)

Ứng dụng React áp dụng kiểm thử giao diện tập trung vào trải nghiệm người dùng và hiển thị dữ liệu biểu đồ.

### Công nghệ sử dụng:
- **`Vitest`:** Khung kiểm thử tốc độ cao tích hợp sẵn với Vite.
- **`React Testing Library (RTL)`:** Render các component trên DOM ảo (`jsdom`).
- **`vi.mock()`:** Chặn các lệnh gọi API từ TanStack React Query và Axios.

```bash
cd frontend
npm run test
```

**Hình 2.** Kết quả kiểm thử **Frontend** bằng lệnh `npm run test` (Vitest), trong đó toàn bộ **7 bài kiểm thử** thuộc **5 tệp kiểm thử** (Dashboard, Copilot, Project Context và API) đều thực thi thành công. Quá trình kiểm thử hoàn tất trong **dưới 3 giây**, đồng thời hỗ trợ **Vite Watch Mode** để tự động chạy lại các bài kiểm thử khi mã nguồn thay đổi, giúp rút ngắn thời gian phát triển và kiểm tra giao diện.

![npm_test_output](/images/5-Workshop/5.5-Quality-assurance/npm_test_output.png)



---

## 3. Quy trình Thực thi Test

Cả hai bộ test được thiết kế để chạy mà không cần dịch vụ bên ngoài hay cloud round-trip. Quy trình local dưới đây là quy trình mà mọi developer sử dụng trước khi push code:

```bash
# Backend tests (4.32s trung bình)
cd backend
python -m pytest tests/ -v --tb=short

# Backend coverage
python -m pytest tests/ --cov=. --cov-report=term-missing

# Frontend tests (~2.5s trung bình)
cd frontend
npm run test -- --run
```

{{% notice tip %}}Bộ test backend dựa vào `moto` để mock tất cả AWS services (Lambda, DynamoDB, Bedrock, STS, SNS), do đó test chạy với **zero AWS API call** và an toàn để thực thi trên bất kỳ laptop hay CI runner nào mà không cần credentials.{{% /notice %}}

---

## 4. Phân tích Chi tiết Test Suite (26 Backend + 7 Frontend = 33 Tests)

Toàn bộ test suite được chia trên 12 file, tổng cộng 33 test, thực thi dưới 8 giây mà không cần cloud round-trip. Bảng phân tích giúp xác định test nào bảo vệ subsystem nào:

| Test File | Tests | Mục đích |
|---|---|---|
| backend/tests/api/test_projects.py | 5 | CRUD endpoint projects + sync trigger |
| backend/tests/api/test_resources.py | 4 | List/get resource endpoint + pagination |
| backend/tests/api/test_insights.py | 3 | List insights + generate on-demand |
| backend/tests/api/test_alerts.py | 2 | List alerts với severity filter |
| backend/tests/api/test_chat.py | 2 | Bedrock chat prompt assembly + fallback |
| backend/tests/ai/test_analyzer.py | 5 | Prompt construction + JSON schema validation |
| backend/tests/shared/test_db.py | 5 | DynamoDB marshalling, GSI key encoding |
| frontend/src/pages/__tests__/Dashboard.test.jsx | 3 | Dashboard component render + health score widgets |
| frontend/src/tests/pages/Dashboard.test.jsx | 1 | Dashboard page integration test |
| frontend/src/tests/pages/Copilot.test.jsx | 1 | Copilot chat UI smoke test |
| frontend/src/tests/context/ProjectContext.test.jsx | 1 | Project context provider state |
| frontend/src/services/__tests__/api.test.js | 1 | Axios API client + Cognito interceptor |
| **Tổng** | **33** | 7 file test backend + 5 file test frontend |

---

## 5. Báo cáo Coverage HTML

pytest-cov ghi báo cáo coverage HTML tương tác tại htmlcov/index.html. Tạo và mở local:

```bash
cd backend
python -m pytest tests/ --cov=. --cov-report=html
# open htmlcov/index.html trong trình duyệt
```

Báo cáo HTML drill down file-by-file và line-by-line. Điểm 93% aggregate tập trung ở collector/ (một số nhánh lỗi cố ý không cover để giữ test nhanh) và shared/aws_client.py (STS AssumeRole retries phụ thuộc thời gian).

{{% notice info %}}Báo cáo HTML được **gitignore**. Chạy lại lệnh trên sau khi pull code mới nếu muốn snapshot hiện tại.{{% /notice %}}

---

## 6. Sẵn sàng cho CI/CD Pipeline

Cả hai test suite chạy độc lập dưới **8 giây** (4.32s pytest + ~2.5s vitest + ~1s setup) mà không cần internet hay cloud dependency. Chuỗi đầy đủ sẵn sàng thêm vào GitHub Actions workflow tại github/workflows/test.yml:

```yaml
name: tests
on: [push, pull_request]
jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install -r backend/requirements.txt
      - run: cd backend && python -m pytest tests/ -v
  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: cd frontend && npm ci && npm run test
```

Workflow này có thể mở rộng để deploy khi tag release (on: push: tags: ['v*']) dùng sam deploy --no-confirm-changeset sau khi tests pass.

---

## Tóm tắt Phần

Chiến lược kiểm thử hai lớp, kết hợp **Pytest** và **Moto** cho backend với **Vitest** và **React Testing Library (RTL)** cho frontend, cung cấp tổng cộng **33 bài kiểm thử** có thời gian thực thi nhanh, kết quả ổn định (deterministic) và đạt **93% độ bao phủ mã nguồn (Code Coverage)**. Toàn bộ các bài kiểm thử hoàn thành trong **dưới 8 giây**, không phụ thuộc vào các dịch vụ bên ngoài (external dependencies), đồng thời có thể dễ dàng tích hợp vào hầu hết các nền tảng **Continuous Integration (CI)**.
