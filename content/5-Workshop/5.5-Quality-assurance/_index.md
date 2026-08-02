---
title: "Quality Assurance & Testing"
date: 2026-05-01
weight: 5
chapter: false
pre: " <b> 5.5. </b> "
---

# Section 5.5 - Quality Assurance & Testing Strategy

To guarantee the high reliability, resilience, and data integrity of **AI AWS Advisor**, the project implements a comprehensive dual-layered automated unit testing architecture.

---

## 1. Backend Testing Framework (Pytest + Moto)

The backend utilizes `pytest` with specialized AWS mocking libraries to test business logic and cloud integrations without making real AWS API calls or incurring cloud charges.

### Key Tools & Mocking Architecture:
- **`pytest` & `pytest-mock`:** Test discovery, assertions, and fixture mocking.
- **`moto`:** Intercepts `boto3` AWS SDK calls, creating an in-memory virtual DynamoDB database and STS service.
- **Bedrock Mocking:** Intercepts `boto3.client('bedrock-runtime').invoke_model()` calls to return deterministic JSON responses, testing AI output parsing and fallback handlers.

```bash
cd backend
python -m pytest tests/ -v
```

**Figure 1 - Backend test suite — `pytest tests/ -v` shows 26 tests passed across 7 test files (API handlers + AI analyzer + shared DB layer), executed in 4.32s with 93% code coverage:**

<img src="/aws-ojt-workshop-ja/images/5.5-Quality-assurance/pytest_output.png?v=2026-08-01-r1" alt="PowerShell 7 terminal showing pytest -v execution: 26 tests collected and passed across 7 test files (api/test_projects.py, api/test_resources.py, api/test_insights.py, api/test_alerts.py, api/test_chat.py, ai/test_analyzer.py, shared/test_db.py). Footer summary shows 26 passed in 4.32s and a coverage table with 93% total. No failures, no skips." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

---

## 2. Frontend Testing Framework (Vitest + React Testing Library)

The React client implements component testing focusing on user interaction and data visual rendering.

### Key Tools:
- **`Vitest`:** Lightning-fast Vite-native testing framework.
- **`React Testing Library (RTL)`:** Renders components in `jsdom` headless DOM environment.
- **`vi.mock()`:** Intercepts TanStack React Query and Axios HTTP calls.

```bash
cd frontend
npm run test
```

**Figure 2 - Frontend test suite — `npm run test` (vitest run) shows 7 component/hook tests passed across 5 test files (Dashboard in 2 locations, Copilot, ProjectContext, api), executed in under 3s with Vite watch mode:**

<img src="/aws-ojt-workshop-ja/images/5.5-Quality-assurance/npm_test_output.png?v=2026-08-01-r1" alt="PowerShell 7 terminal showing npm run test (vitest run) execution: 7 tests passed across 5 test files (src/pages/__tests__/Dashboard.test.jsx with 3 tests, src/tests/pages/Dashboard.test.jsx with 1 test, src/tests/pages/Copilot.test.jsx with 1 test, src/tests/context/ProjectContext.test.jsx with 1 test, src/services/__tests__/api.test.js with 1 test). Footer summary shows 5 Test Files passed (5), 7 Tests passed (7), Duration ~2.5s. No failures." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

---

## 3. Test Execution Workflow

Both suites are designed to run without any external service or cloud round-trip. The local workflow below is what every developer uses before pushing code:

```bash
# Backend tests (4.32s typical)
cd backend
python -m pytest tests/ -v --tb=short

# Backend coverage
python -m pytest tests/ --cov=. --cov-report=term-missing

# Frontend tests (~2.5s typical)
cd frontend
npm run test -- --run
```

{{% notice tip %}}The backend suite relies on `moto` to mock all AWS services (Lambda, DynamoDB, Bedrock, STS, SNS), so tests run with **zero AWS API calls** and are safe to execute on any laptop or CI runner without credentials.{{% /notice %}}

---

## 4. Test Suite Breakdown (26 Backend + 7 Frontend = 33 Tests)

The full test suite is split across 12 files totalling 33 tests, executed in under 8 seconds without any cloud round-trips. The breakdown makes it easy to identify which subsystem each test guards:

| Test File | Tests | Purpose |
|---|---|---|
| backend/tests/api/test_projects.py | 5 | CRUD for projects endpoint + sync trigger |
| backend/tests/api/test_resources.py | 4 | List/get resource endpoints + pagination |
| backend/tests/api/test_insights.py | 3 | Insights list + on-demand generation |
| backend/tests/api/test_alerts.py | 2 | Alerts list with severity filter |
| backend/tests/api/test_chat.py | 2 | Bedrock chat prompt assembly + fallback |
| backend/tests/ai/test_analyzer.py | 5 | Prompt construction + JSON schema validation |
| backend/tests/shared/test_db.py | 5 | DynamoDB marshalling, GSI key encoding |
| frontend/src/pages/__tests__/Dashboard.test.jsx | 3 | Dashboard component render + health score widgets |
| frontend/src/tests/pages/Dashboard.test.jsx | 1 | Dashboard page integration test |
| frontend/src/tests/pages/Copilot.test.jsx | 1 | Copilot chat UI smoke test |
| frontend/src/tests/context/ProjectContext.test.jsx | 1 | Project context provider state |
| frontend/src/services/__tests__/api.test.js | 1 | Axios API client + Cognito interceptor |
| **Total** | **33** | 7 backend test files + 5 frontend test files |

---

## 5. HTML Coverage Report

pytest-cov writes an interactive HTML coverage report next to htmlcov/index.html. Generate and open it locally:

```bash
cd backend
python -m pytest tests/ --cov=. --cov-report=html
# open htmlcov/index.html in your browser
```

The HTML report drills down file-by-file and line-by-line. The 93% aggregate score is concentrated in collector/ (where some error branches are intentionally uncovered to keep tests fast) and shared/aws_client.py (where STS AssumeRole retries are time-dependent).

{{% notice info %}}The HTML report is **gitignored**. Re-run the command above locally after pulling new code if you want a current snapshot.{{% /notice %}}

---

## 6. Continuous Integration Readiness

Both test suites execute independently in under **8 seconds** (4.32s pytest + ~2.5s vitest + ~1s setup) without external internet or cloud dependencies. The full sequence is ready to be added to a GitHub Actions workflow under .github/workflows/test.yml:

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

This workflow can be extended to deploy on tagged releases (on: push: tags: ['v*']) using sam deploy --no-confirm-changeset after the tests pass.

---

## Section Summary

The dual-layered test strategy (pytest + moto on backend, Vitest + RTL on frontend) gives 33 fast deterministic tests with 93% coverage. All tests run in <8 seconds without external dependencies, making the suite trivial to plug into any CI provider.
