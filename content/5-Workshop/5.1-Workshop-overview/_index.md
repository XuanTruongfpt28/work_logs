---
title: "Workshop Overview"
date: 2026-05-01
weight: 1
chapter: false
pre: " <b> 5.1. </b> "
---

# Section 5.1 - Workshop Overview

## Executive Summary

**AI AWS Advisor** is designed as a full-stack, enterprise-grade B2B SaaS platform that seamlessly scans customer multi-account AWS environments, collects resource configurations safely using temporary delegation, and delivers generative AI-powered optimization insights.

**Figure 1 - AI AWS Advisor High-Level Architecture (Web Dashboard → API Gateway → Lambda → DynamoDB ↔ Bedrock + STS AssumeRole):**

<img src="/images/5.1-Workshop-overview/workshop_architecture.png?v=2026-08-01-r3" alt="AI AWS Advisor High-Level Architecture diagram - Three independent zones: (1) Client Frontend with React 19 + Vite + Tailwind Dashboard (Recharts, TanStack Query) served via CloudFront+S3; (2) AI Advisor Backend containing API Gateway (REST, 11 routes, Cognito JWT Authorizer) routing to SIX Lambda functions — FIVE specialized API Handlers (ai-advisor-projects-api: 5 routes list/create/get/delete/sync, ai-advisor-resources-api: 2 routes list/get, ai-advisor-insights-api: 2 routes list/generate + Bedrock + SNS, ai-advisor-chat-api: 1 route chat + Bedrock streaming, ai-advisor-alerts-api: 1 route list) and ONE Collector Lambda (ai-advisor-collector triggered by EventBridge rate(1 hour), uses sts:AssumeRole for cross-account access, performs 23 AWS read-actions on EC2/S3/IAM/Lambda/CloudWatch); Amazon Bedrock Claude 3 Haiku (anthropic.claude-3-haiku-20240307-v1:0); Amazon SNS Topic ai-advisor-alerts + email subscription for critical-risk notifications; DynamoDB Multi-Table (4 dedicated tables: ai-advisor-projects PK=project_id+SK=sk, ai-advisor-resources PK=project_id+SK=resource_id + GSI resource_type-index, ai-advisor-insights PK=project_id+SK=insight_id, ai-advisor-alerts PK=project_id+SK=alert_id); (3) Customer Target AWS Accounts with STS AssumeRole accessing EC2/S3/IAM/Lambda/CloudWatch resources via the audit IAM Role AIAdvisorAuditRole." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

*The diagram above illustrates the high-level data flow of the AI AWS Advisor platform: users interact with the **Enterprise Web Dashboard**, which calls **Amazon API Gateway** over HTTPS/REST. The API Gateway dispatches requests to five specialized API Lambda handlers (Projects, Resources, Insights, Chat Copilot, Alerts) which read/write the four **Amazon DynamoDB** tables. In parallel, an **Hourly Scanning Collector Lambda** invokes `sts:AssumeRole` to safely read customer AWS accounts, then sends a structured Prompt JSON Context to **Amazon Bedrock** (Claude 3 Haiku) to generate AI-powered optimization insights. The total serverless compute inventory is **six Lambda functions** (5 API + 1 Collector).*

---

## Core Problem Statement

Managing modern AWS infrastructure across dynamic development, staging, and production environments presents critical challenges for CloudOps and Security teams:

1. **Hidden Security Misconfigurations:** Publicly exposed S3 buckets, permissive security group rules (`0.0.0.0/0`), and unencrypted volumes often go unnoticed until a data breach occurs.
2. **Cloud Resource Waste:** Unattached EBS volumes, idle EC2 instances, and unused Elastic IPs accumulate thousands of dollars in unnecessary monthly bills.
3. **Manual Audit Friction:** Security officers and DevOps engineers spend hundreds of hours manually reviewing AWS Trusted Advisor and raw JSON describe API calls.

---

## Technology Stack

- **Frontend Application:** React 19 (JavaScript SPA), Vite, Tailwind CSS, shadcn/ui-style components (Radix UI primitives + `class-variance-authority`), Recharts, TanStack React Query.
- **Serverless Backend:** Python 3.12, AWS Lambda, Amazon API Gateway, Amazon EventBridge, Amazon SNS.
- **Artificial Intelligence (GenAI):** Amazon Bedrock (Anthropic Claude 3 Haiku model `anthropic.claude-3-haiku-20240307-v1:0`).
- **Database & Storage:** Amazon DynamoDB (Multi-Table NoSQL Design — 4 dedicated tables + 1 GSI).
- **Security Framework:** AWS Security Token Service (STS `sts:AssumeRole`) for cross-account delegation.
- **Infrastructure as Code (IaC):** AWS Serverless Application Model (SAM CLI).

---

## Backend Lambda Inventory (6 Functions)

The serverless backend is composed of six Lambda functions (5 API handlers + 1 scheduled collector), each provisioned via `template.yaml`:

| # | Function Name | Handler | Trigger | Primary Purpose |
|---|---|---|---|---|
| 1 | `ai-advisor-projects-api` | `api.projects.lambda_handler` | API Gateway (5 routes) | CRUD for projects + sync trigger |
| 2 | `ai-advisor-resources-api` | `api.resources.lambda_handler` | API Gateway (2 routes) | List scanned AWS resources |
| 3 | `ai-advisor-insights-api` | `api.insights.lambda_handler` | API Gateway (2 routes) | List + generate AI insights |
| 4 | `ai-advisor-chat-api` | `api.chat.lambda_handler` | API Gateway (1 route) | Generative AI Copilot (Q&A) |
| 5 | `ai-advisor-alerts-api` | `api.alerts.lambda_handler` | API Gateway (1 route) | List critical risk alerts |
| 6 | `ai-advisor-collector` | `collector.main.lambda_handler` | EventBridge `rate(1 hour)` | Scan target accounts via STS |

All six functions run on **Python 3.12** runtime with AWS Lambda Powertools (logger, metrics, tracer) for observability.

---

## Frontend Application Structure

The React 19 SPA is built with **Vite** and bundles **TanStack React Query** for data fetching against the API Gateway endpoints. Six primary pages are organized under `frontend/src/pages/`:

| Page | Route | Purpose |
|---|---|---|
| **Dashboard** | `/` | High-level KPI summary across all projects |
| **Projects** | `/projects` | List, create, delete projects; paste Role ARN |
| **Cost** | `/cost` | Visualize cost optimization insights (Recharts) |
| **Performance** | `/performance` | Lambda cold starts, EC2 utilization metrics |
| **Security** | `/security` | Public S3, open security groups, IAM hygiene |
| **Copilot** | `/copilot` | AI chat with Bedrock Claude 3 Haiku |

UI primitives are sourced from **shadcn/ui** (Radix-based) and styled with **Tailwind CSS**; charts are rendered with **Recharts**. State is held in **TanStack React Query** cache with automatic retry on 5xx errors.

Below is the live UI of each page, captured from a workshop author session against the deployed stack in `us-east-1`:

**Figure 2 - Dashboard Overview (`/`) showing 4 KPI cards (System Health 78%, Resources 75, Critical Risks 4, Monthly Savings $2.5K), per-project tabs (ProDev / Beta Dev / Production) and the AI Analysis panel with severity counts and AI Chat input:**

<img src="/images/5.1-Workshop-overview/ui_dashboard_overview.png?v=2026-08-01-r4" alt="AI AWS Advisor Dashboard Overview page rendered against the live deployed backend - top row shows four KPI cards: System Health 78% (purple gradient), Resources 75 (blue gradient), Critical Risks 4 (orange gradient), Monthly Savings $2.5K (green gradient). Below is a tab switcher with ProDev (active, purple), Beta Dev, and Production tabs. Each tab loads a project summary with empty state and a sidebar AI Analysis panel showing severity counts (High: 4, Medium: 0, Low: 0) and an AI Chat input box with 'Ask about your infrastructure...' placeholder." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Figure 3 - Projects page (`/projects`) listing 3 AWS environments as gradient cards (ProDev with green checkmark status Active, Beta Dev amber pending status, Production red warning 4 critical issues), each card shows Project ID, Role ARN, Last Scan timestamp and 3 action buttons:**

<img src="/images/5.1-Workshop-overview/ui_projects_list.png?v=2026-08-01-r4" alt="AI AWS Advisor Projects page listing three customer AWS environments as gradient cards in a responsive grid: ProDev (green gradient, status Active, Project ID PRJ-1301, Role ARN arn:aws:iam::050912644653:role/AIAdvisorAuditRole, Last Scan 1/30/2026 with Sync Now and Add Project buttons); Beta Dev (amber gradient, status Pending); Production (red gradient, status showing 4 critical issues). Each card exposes Sync, View Details and Delete buttons." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Figure 4 - Cost Optimization page (`/cost`) showing AI-detected idle EC2 instance savings ($124.50/month), 'Potential Monthly Savings' hero card, and 3 optimization insights ranked by severity (Idle EC2 detected, Rightsizing recommendation, Reserved Instance opportunity):**

<img src="/images/5.1-Workshop-overview/ui_cost_optimization.png?v=2026-08-01-r4" alt="AI AWS Advisor Cost Optimization page with a hero card 'Potential Monthly Savings' showing $124.50/month. Below are three AI-generated cost insights ranked by severity: (1) Idle EC2 Instance Detected with $85.50/month potential savings and 'Implement rightsizing or terminate' recommendation; (2) Over-provisioned RDS Instance with $24.00/month savings and 'Downsize to db.t3.medium' recommendation; (3) Unused Elastic IP Address with $15.00/month savings and 'Release the Elastic IP' recommendation. Each insight card displays Category, Estimated Monthly Savings and a colored Severity badge." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Figure 5 - Performance Insights page (`/performance`) surfacing a critical DB Node Overloaded at 98.5% CPU, plus 3 performance insights (CPU saturation, I/O bottleneck, Lambda cold start) with utilization bars and AI recommendations:**

<img src="/images/5.1-Workshop-overview/ui_performance_insights.png?v=2026-08-01-r4" alt="AI AWS Advisor Performance Insights page showing the most critical finding as a hero card: 'DB Node Overloaded' at 98.5% CPU utilization with a red utilization bar at 98.5% and an AI recommendation 'Consider scaling vertically or enabling read replicas'. Below are three additional performance insights: (1) Lambda Cold Start Latency with a medium-severity badge and a 23% utilization bar; (2) I/O Bottleneck on EBS Volume with a low-severity badge; (3) Memory Pressure on App Server with an amber utilization bar." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Figure 6 - Security Risks page (`/security`) with 2 critical S3 bucket exposures (Public Access, Missing Encryption) and 1 medium IAM risk (Over-privileged Role), each risk card shows Severity badge, Resource ARN, Detection method and AI remediation steps:**

<img src="/images/5.1-Workshop-overview/ui_security_risks.png?v=2026-08-01-r4" alt="AI AWS Advisor Security Risks page listing 3 active vulnerabilities with severity badges: (1) CRITICAL - S3 Bucket Public Access on aws-glue-assets-prod, detected via GetBucketPublicAccessBlock, recommendation 'Enable Block Public Access and audit bucket ACL'; (2) CRITICAL - S3 Bucket Missing Encryption on deploy-bucket-artifacts, recommendation 'Enable default encryption with KMS key'; (3) MEDIUM - IAM Role Over-privileged on LambdaExecutionRole, recommendation 'Apply least-privilege policy and remove AdministratorAccess'. Each card displays Severity badge, Resource identifier, Detection method, and AI-generated remediation steps." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Figure 7 - AI Copilot chat (`/copilot`) with 3-turn conversation between the operator and Claude 3 Haiku — question about the most expensive resource, AI-ranked answer pointing at the Production EC2 fleet, and a follow-up asking for rightsizing options the AI returns as a numbered action plan:**

<img src="/images/5.1-Workshop-overview/ui_ai_copilot.png?v=2026-08-01-r4" alt="AI AWS Advisor AI Copilot chat interface showing a 3-turn conversation in Vietnamese between the operator and Claude 3 Haiku: (1) 'tài nguyên nào đang tốn kém nhất' - 'Resource nào đang tốn kém nhất?'; (2) AI response analyzing that the 4 Production EC2 instances represent the largest cost at ~$720/month and recommending termination of 2 idle ones; (3) follow-up 'có thể tối ưu không?' - 'Có thể tối ưu không?'; (4) AI returns a numbered action plan with 4 steps: rightsize Production instances, switch to Compute Savings Plans, delete the 4 stopped instances, enable S3 Intelligent-Tiering. The chat header shows 'AI Advisor Assistant' with Powered by Claude 3 Haiku badge." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

---

## REST API Endpoints Catalog (11 Routes)

All 11 routes are deployed under a single API Gateway stage (`/prod`) and protected by **Amazon Cognito JWT authorizer**. CORS is configured to allow `*` origin (production should restrict this):

| Method | Path | Lambda | Purpose |
|---|---|---|---|
| `GET` | `/projects` | ProjectsFunction | List all projects owned by current user |
| `POST` | `/projects` | ProjectsFunction | Create a new project (accepts Role ARN + region) |
| `GET` | `/projects/{project_id}` | ProjectsFunction | Get one project detail |
| `DELETE` | `/projects/{project_id}` | ProjectsFunction | Delete a project (cascades to its resources/insights) |
| `POST` | `/projects/{project_id}/sync` | ProjectsFunction | Async invoke Collector for this project |
| `GET` | `/projects/{project_id}/resources` | ResourcesFunction | List all AWS resources scanned for this project |
| `GET` | `/projects/{project_id}/resources/{resource_id}` | ResourcesFunction | Get full raw_data JSON for one resource |
| `GET` | `/projects/{project_id}/insights` | InsightsFunction | List AI-generated insights (paginated) |
| `POST` | `/projects/{project_id}/insights/generate` | InsightsFunction | Trigger Bedrock to generate fresh insights |
| `POST` | `/projects/{project_id}/chat` | ChatFunction | Send user prompt + resource context to Bedrock, return answer |
| `GET` | `/projects/{project_id}/alerts` | AlertsFunction | List critical-risk alerts sent to SNS |

API Gateway is throttled at **100 requests/second** with **50 burst** and a monthly quota of **1000 requests** via the `AdvisorUsagePlan`.

---

## Repository Layout

```
aws-advisor/
├── backend/                     # AWS SAM Python 3.12 serverless application
│   ├── api/                     # 5 API handlers (projects, resources, insights, chat, alerts)
│   ├── collector/               # 6 collectors (ec2, s3, iam, lambda, cloudwatch, main)
│   ├── ai/                      # Bedrock Claude 3 prompt engineering + rule engine
│   ├── shared/                  # aws_client (STS AssumeRole), db, models
│   ├── tests/                   # pytest + moto (26 tests)
│   └── template.yaml            # CloudFormation / SAM IaC
├── frontend/                    # Vite + React 19 + JavaScript SPA (JSX, no TypeScript)
│   ├── src/pages/               # 6 primary pages (Dashboard, Projects, Cost, ...)
│   ├── src/components/          # shadcn/ui primitives + custom cards
│   ├── src/services/            # API client (apiClient.js, queryKeys.js)
│   └── src/__tests__/           # Vitest + RTL (5 test files)
└── docs/                        # Engineering reflection + future roadmap
```

---

## Section Summary

This overview sets the stage for the rest of the workshop. Subsequent sections dive into system requirements (§5.2), end-to-end architecture (§5.3), deployment strategy (§5.4), quality assurance (§5.5), and operations & cleanup (§5.6).