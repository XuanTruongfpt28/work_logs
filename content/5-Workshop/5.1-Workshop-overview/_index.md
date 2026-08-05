---
title : "Introduction"
date : 2026-07-07
weight : 1
chapter : false
pre : " <b> 5.1. </b> "
---

# Section 5.1 - Workshop Overview

## Project Summary

**AI AWS Advisor** is designed as a comprehensive enterprise-grade B2B SaaS system, capable of securely scanning a customer's multi-account AWS infrastructure, collecting configuration data through a temporary-credential delegation mechanism, and analyzing it with Artificial Intelligence (Generative AI).

**Figure 1 - AI AWS Advisor High-Level Architecture Diagram**


![Architecture](/images/5-Workshop/5.1-Workshop-overview/architecture.png)


The diagram above illustrates the overall data flow of the **AI AWS Advisor** platform. Users access the **Enterprise Web Dashboard**, which sends requests over **HTTPS/REST** to **Amazon API Gateway**. API Gateway receives and routes requests to five specialized **AWS Lambda API Handlers** (**Projects, Resources, Insights, Chat Copilot**, and **Alerts**), which read from and write to **four Amazon DynamoDB tables**.

In parallel with user request processing, the **Hourly Scanning Collector Lambda** periodically uses `sts:AssumeRole` to securely access the customer's AWS account, collects resource information, and builds a **Prompt JSON Context**. This data is sent to **Amazon Bedrock** (Claude 3 Haiku) for analysis, which generates AI-driven optimization recommendations.

The entire backend is deployed on a serverless architecture with **six Lambda functions**, comprising **five API Lambda Handlers** and **one Collector Lambda**.


---

## The Real-World Problem

Managing large-scale AWS environments in production comes with three major challenges:

1. **Hidden Security Misconfigurations:** Publicly open S3 buckets, security groups open to `0.0.0.0/0`, or unencrypted data are often overlooked until a data leak actually occurs.
2. **Wasted Cloud Spend:** Idle EBS volumes, unused EC2 instances, and unattached Elastic IPs quietly burn through thousands of dollars every month.
3. **Time-Consuming Manual Auditing:** DevOps and Security teams spend hundreds of hours manually combing through raw JSON configuration files.

---

## Technology Stack

- **Frontend:** React 19 (JavaScript SPA), Vite, Tailwind CSS, shadcn/ui-style components (Radix UI primitives + `class-variance-authority`), Recharts, TanStack React Query.
- **Serverless Backend:** Python 3.12, AWS Lambda, Amazon API Gateway, Amazon EventBridge, Amazon SNS.
- **Generative AI:** Amazon Bedrock (Anthropic Claude 3 Haiku `anthropic.claude-3-haiku-20240307-v1:0`).
- **Database:** Amazon DynamoDB (Multi-Table NoSQL design — 4 dedicated tables + 1 GSI).
- **Security:** AWS Security Token Service (STS `sts:AssumeRole`) for cross-account delegation.
- **IaC:** AWS Serverless Application Model (SAM CLI).

---

## Backend Lambda Inventory (6 Functions)

The entire serverless backend consists of **6 Lambda functions** (5 API handlers + 1 scheduled Collector), declared in `template.yaml`:

| # | Function Name | Handler | Trigger | Primary Purpose |
|---|---|---|---|---|
| 1 | `ai-advisor-projects-api` | `api.projects.lambda_handler` | API Gateway (5 routes) | Project CRUD + trigger sync |
| 2 | `ai-advisor-resources-api` | `api.resources.lambda_handler` | API Gateway (2 routes) | List scanned AWS resources |
| 3 | `ai-advisor-insights-api` | `api.insights.lambda_handler` | API Gateway (2 routes) | List + generate AI insights |
| 4 | `ai-advisor-chat-api` | `api.chat.lambda_handler` | API Gateway (1 route) | Generative AI Copilot (Q&A) |
| 5 | `ai-advisor-alerts-api` | `api.alerts.lambda_handler` | API Gateway (1 route) | List critical-risk alerts |
| 6 | `ai-advisor-collector` | `collector.main.lambda_handler` | EventBridge `rate(1 hour)` | Scan target account via STS |

All 6 functions run on the **Python 3.12** runtime and integrate **AWS Lambda Powertools** (logger, metrics, tracer) for observability.

---

## React Frontend Structure

The React 19 SPA is built on **Vite** and uses **TanStack React Query** to fetch data from API Gateway. Six main pages live under `frontend/src/pages/`:

| Page | Route | Purpose |
|---|---|---|
| **Dashboard** | `/` | Overall KPI overview across all projects |
| **Projects** | `/projects` | List, create, delete projects; enter Role ARN |
| **Cost** | `/cost` | Cost-saving recommendation charts (Recharts) |
| **Performance** | `/performance` | Lambda cold starts, EC2 utilization |
| **Security** | `/security` | Public S3 buckets, open security groups, IAM hygiene |
| **Copilot** | `/copilot` | Chat with Bedrock Claude 3 Haiku |

UI primitives use **shadcn/ui** (Radix-based), styled with **Tailwind CSS**; charts are rendered with **Recharts**. State lives in the **TanStack React Query** cache and automatically retries on 5xx errors.

Below are actual screenshots of each page, captured from the workshop author's session with the stack deployed to `us-east-1`:

**Figure 2.** The **Dashboard Overview** page (`/`) shows four main KPI cards: **System Health (78%)**, **Resources (75)**, **Critical Risks (4)**, and **Monthly Savings ($2.5K)**. Below that is a project-switcher area (**ProDev**, **Beta Dev**, and **Production**). On the right side is the **AI Analysis Panel**, showing alert counts by severity level along with an **AI Chat** input box for asking questions about the AWS infrastructure.



![dashboard](/images/5-Workshop/5.1-Workshop-overview/dashboard_overview.png)




**Figure 3.** The **Projects** page (`/projects`) displays three AWS environments as cards, color-coded by status: **ProDev** (Active — green checkmark), **Beta Dev** (Pending — amber), and **Production** (Warning — 4 Critical Issues, red). Each card shows key details such as **Project ID**, **IAM Role ARN**, **Last Scan** time, and three action buttons for managing the project.


![projects_list](/images/5-Workshop/5.1-Workshop-overview/projects_list.png)

**Figure 4.** The **Cost Optimization** page (`/cost`) shows AI-generated cost analysis results, including a **Hero Card – Potential Monthly Savings** with an estimated savings of **$124.50/month** from detecting an idle **EC2 instance**. Below that are three **Cost Optimization Insights** ranked by severity: **Idle EC2 Detected**, **Rightsizing Recommendation**, and **Reserved Instance Opportunity**, helping users quickly identify cost-saving opportunities across their AWS infrastructure.


![cost_optimization](/images/5-Workshop/5.1-Workshop-overview/cost_optimization.png)


**Figure 5.** The **Performance Insights** page (`/performance`) shows system performance analysis results, highlighted by a **DB Node Overloaded** warning with **CPU utilization at 98.5%**. Below that are three AI-analyzed **Performance Insights**: **CPU Saturation**, **I/O Bottleneck**, and **Lambda Cold Start**. Each item shows a **Utilization** bar along with AI-recommended actions, helping users quickly pinpoint the causes of performance degradation and choose the right remediation.


![cost_optimization](/images/5-Workshop/5.1-Workshop-overview/cost_optimization.png)



**Figure 6.** The **Security Risks** page (`/security`) shows security risks detected by AI across the AWS infrastructure, including two **Critical**-level alerts related to **S3 Bucket Exposure** (*Public Access* and *Missing Encryption*), plus one **Medium**-level risk for an **IAM Over-privileged Role**. Each **Risk Card** provides key details such as a **Severity Badge**, **Resource ARN**, **Detection Method**, and **AI Remediation Steps**, helping users quickly assess impact and apply the recommended fixes.


![security_risks](/images/5-Workshop/5.1-Workshop-overview/security_risks.png)



**Figure 7.** The **AI Copilot** page (`/copilot`) illustrates a three-turn conversation between an operator and **Claude 3 Haiku**. The user asks which resource is generating the highest cost, and the AI analyzes the data and identifies the **Production EC2 Fleet** as the top optimization priority. In the following turn, the AI continues answering questions about permissions and optimization options, presented as a numbered step-by-step **Action Plan** that's easy for the user to follow.



![ai_copilot](/images/5-Workshop/5.1-Workshop-overview/ai_copilot.png)


---

## REST API Endpoint Catalog (11 Routes)

All 11 routes are deployed under a single API Gateway stage (`/prod`), protected by an **Amazon Cognito JWT authorizer**. CORS is currently open to `*` (should be restricted in production):

| Method | Path | Lambda | Purpose |
|---|---|---|---|
| `GET` | `/projects` | ProjectsFunction | List the current user's projects |
| `POST` | `/projects` | ProjectsFunction | Create a new project (accepts Role ARN + region) |
| `GET` | `/projects/{project_id}` | ProjectsFunction | Get details of a single project |
| `DELETE` | `/projects/{project_id}` | ProjectsFunction | Delete a project (cascades resources/insights) |
| `POST` | `/projects/{project_id}/sync` | ProjectsFunction | Trigger the Collector asynchronously |
| `GET` | `/projects/{project_id}/resources` | ResourcesFunction | List scanned AWS resources |
| `GET` | `/projects/{project_id}/resources/{resource_id}` | ResourcesFunction | Retrieve the full raw_data JSON |
| `GET` | `/projects/{project_id}/insights` | InsightsFunction | List AI insights (paginated) |
| `POST` | `/projects/{project_id}/insights/generate` | InsightsFunction | Request Bedrock to generate new insights |
| `POST` | `/projects/{project_id}/chat` | ChatFunction | Send a prompt + resource context to Bedrock |
| `GET` | `/projects/{project_id}/alerts` | AlertsFunction | List critical-risk alerts |

API Gateway throttles at **100 requests/second** with a **burst of 50** and a **1000 requests/month** quota via `AdvisorUsagePlan`.

---

## Repository Structure

```
aws-advisor/
├── backend/                     # AWS SAM Python 3.12 serverless application
│   ├── api/                     # 5 API handlers (projects, resources, insights, chat, alerts)
│   ├── collector/               # 6 collectors (ec2, s3, iam, lambda, cloudwatch, main)
│   ├── ai/                      # Bedrock Claude 3 prompt + rule engine
│   ├── shared/                  # aws_client (STS AssumeRole), db, models
│   ├── tests/                   # pytest + moto (26 tests)
│   └── template.yaml            # CloudFormation / SAM IaC
├── frontend/                    # Vite + React 19 + JavaScript SPA (JSX, no TypeScript)
│   ├── src/pages/               # 6 main pages (Dashboard, Projects, Cost, ...)
│   ├── src/components/          # shadcn/ui primitives + custom cards
│   ├── src/services/            # API client (apiClient.js, queryKeys.js)
│   └── src/__tests__/           # Vitest + RTL (5 test files)
└── docs/                        # Engineering reflection + future roadmap
```

---

## Section Summary

This overview lays the foundation for the entire workshop. The following sections dive into system requirements (5.2), end-to-end architecture (5.3), deployment strategy (5.4), quality assurance (5.5), and operations & cleanup (5.6).