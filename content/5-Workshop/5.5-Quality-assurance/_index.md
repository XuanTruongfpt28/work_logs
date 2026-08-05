---
title: "Testing & Quality"
date: 2026-07-07
weight: 5
chapter: false
pre: " <b> 5.5. </b> "
---

# Section 5.5 - Testing & Quality Assurance

To ensure high reliability, safety, and data integrity for **AI AWS Advisor**, the project uses a two-layer, independent automated testing architecture.

---

## 1. Backend Testing Environment (Pytest + Moto)

The backend uses `pytest` together with the AWS-mocking library `moto` to test business logic without incurring cost or hitting real APIs.

### Technology used:
- **`pytest` & `pytest-mock`:** Testing framework and fixture mocking.
- **`moto`:** Intercepts `boto3` AWS SDK calls, spinning up a virtual DynamoDB database running purely in RAM.
- **Bedrock mocking:** Intercepts Bedrock's `invoke_model()` call to return a standardized JSON response, testing the AI data-handling logic and error handling.

```bash
cd backend
python -m pytest tests/ -v
```
**Figure 1.** **Backend** test results from `pytest tests/ -v`, showing all **26 tests** across **7 test files** (API Handlers, AI Analyzer, and the Shared Database Layer) passing successfully. The test run completes in **4.32 seconds** and reaches **93% code coverage**, showing that the system's core components have been verified and behave reliably.



![Pytest_output](/images/5-Workshop/5.5-Quality-assurance/pytest_output.png)




---

## 2. Frontend Testing Environment (Vitest + React Testing Library)

The React application uses UI testing focused on user experience and chart data rendering.

### Technology used:
- **`Vitest`:** A high-speed testing framework built into Vite.
- **`React Testing Library (RTL)`:** Renders components against a virtual DOM (`jsdom`).
- **`vi.mock()`:** Intercepts API calls from TanStack React Query and Axios.

```bash
cd frontend
npm run test
```

**Figure 2.** **Frontend** test results from `npm run test` (Vitest), showing all **7 tests** across **5 test files** (Dashboard, Copilot, Project Context, and API) passing successfully. The test run completes in **under 3 seconds**, and supports **Vite Watch Mode** to automatically re-run tests when source code changes, shortening the development and UI-verification loop.

![npm_test_output](/images/5-Workshop/5.5-Quality-assurance/npm_test_output.png)



---

## 3. Test Execution Workflow

Both test suites are designed to run without any external service or cloud round-trip. The local workflow below is what every developer runs before pushing code:

```bash
# Backend tests (~4.32s average)
cd backend
python -m pytest tests/ -v --tb=short

# Backend coverage
python -m pytest tests/ --cov=. --cov-report=term-missing

# Frontend tests (~2.5s average)
cd frontend
npm run test -- --run
```

{{% notice tip %}}The backend test suite relies on `moto` to mock every AWS service (Lambda, DynamoDB, Bedrock, STS, SNS), so tests run with **zero AWS API calls** and are safe to execute on any laptop or CI runner without credentials.{{% /notice %}}

---

## 4. Detailed Test Suite Breakdown (26 Backend + 7 Frontend = 33 Tests)

The full test suite is split across 12 files, totaling 33 tests, and completes in under 8 seconds with no cloud round-trip. The breakdown below helps identify which tests protect which subsystem:

| Test File | Tests | Purpose |
|---|---|---|
| backend/tests/api/test_projects.py | 5 | Projects CRUD endpoint + sync trigger |
| backend/tests/api/test_resources.py | 4 | List/get resource endpoint + pagination |
| backend/tests/api/test_insights.py | 3 | List insights + on-demand generation |
| backend/tests/api/test_alerts.py | 2 | List alerts with severity filter |
| backend/tests/api/test_chat.py | 2 | Bedrock chat prompt assembly + fallback |
| backend/tests/ai/test_analyzer.py | 5 | Prompt construction + JSON schema validation |
| backend/tests/shared/test_db.py | 5 | DynamoDB marshalling, GSI key encoding |
| frontend/src/pages/__tests__/Dashboard.test.jsx | 3 | Dashboard component rendering + health score widgets |
| frontend/src/tests/pages/Dashboard.test.jsx | 1 | Dashboard page integration test |
| frontend/src/tests/pages/Copilot.test.jsx | 1 | Copilot chat UI smoke test |
| frontend/src/tests/context/ProjectContext.test.jsx | 1 | Project context provider state |
| frontend/src/services/__tests__/api.test.js | 1 | Axios API client + Cognito interceptor |
| **Total** | **33** | 7 backend test files + 5 frontend test files |

---

## 5. HTML Coverage Report

pytest-cov writes an interactive HTML coverage report to htmlcov/index.html. Generate and open it locally:

```bash
cd backend
python -m pytest tests/ --cov=. --cov-report=html
# open htmlcov/index.html in your browser
```

The HTML report lets you drill down file-by-file and line-by-line. The 93% aggregate figure is dragged down mainly by collector/ (some error branches are intentionally left uncovered to keep tests fast) and shared/aws_client.py (STS AssumeRole retries that depend on timing).

{{% notice info %}}The HTML report is **gitignored**. Re-run the command above after pulling new code if you want a current snapshot.{{% /notice %}}

---

## 6. CI/CD Pipeline Readiness

Both test suites run independently in under **8 seconds** total (4.32s pytest + ~2.5s vitest + ~1s setup) with no internet or cloud dependency. The full pipeline is ready to drop into a GitHub Actions workflow at github/workflows/test.yml:

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

This workflow can be extended to deploy on release tags (on: push: tags: ['v*']) using sam deploy --no-confirm-changeset once tests pass.

---

## Section Summary

The two-layer testing strategy, combining **Pytest** and **Moto** for the backend with **Vitest** and **React Testing Library (RTL)** for the frontend, delivers a total of **33 tests** with fast, deterministic execution and **93% code coverage**. The entire suite completes in **under 8 seconds**, has no external dependencies, and integrates easily into virtually any **Continuous Integration (CI)** platform.