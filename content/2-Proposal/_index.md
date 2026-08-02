---
title: "Proposal"
date: 2026-05-01
weight: 2
chapter: false
pre: " <b> 2. </b> "
---

# Proposal: AI AWS Advisor (Enterprise SaaS)
## An Automated Multi-Tenant Cloud Audit & Optimization Platform

### 1. Executive Summary

The **AI AWS Advisor** platform is proposed as an enterprise-grade B2B SaaS platform designed to automate cloud infrastructure auditing, security compliance checks, and cost optimization for multi-account AWS environments. 

By leveraging **Amazon Bedrock (Claude 3 Haiku)** alongside a 100% Serverless architecture (**AWS Lambda, Amazon API Gateway, Amazon DynamoDB, Amazon EventBridge**), the system automatically collects raw AWS resource configurations, evaluates risks, calculates potential cost savings, and delivers actionable recommendations through an interactive web dashboard and AI Copilot.

---

### 2. Problem Statement

#### The Problem
Modern organizations running workloads on AWS face three major operational challenges:
1. **Security Vulnerabilities:** Misconfigurations such as publicly accessible S3 buckets, open security groups (`0.0.0.0/0`), and over-privileged IAM roles often go undetected until a security breach occurs.
2. **Cloud Resource Waste:** Unattached EBS volumes, idle EC2 instances, and unutilized Elastic IPs accumulate thousands of dollars in unnecessary monthly charges.
3. **High Audit Friction:** Security officers and DevOps engineers spend hundreds of hours manually inspecting complex JSON configurations across multiple accounts.

#### The Proposed Solution
**AI AWS Advisor** provides a unified, zero-trust cloud auditing solution:
- **Zero-Trust Cross-Account Delegation:** Uses AWS Security Token Service (`sts:AssumeRole`) to request temporary audit credentials without ever storing long-term customer Access Keys.
- **Automated Event-Driven Scanning:** EventBridge triggers hourly background sweeps to collect infrastructure configurations across all registered customer accounts.
- **Generative AI Analysis Engine:** Integrates Amazon Bedrock (Claude 3 Haiku) to translate unstructured JSON configurations into structured, prioritized insights categorized into **Security**, **Cost Optimization**, and **Performance**.
- **Real-Time AI Copilot:** Empowers users to query their infrastructure state in natural language via a built-in AI Chatbot.

**Figure 1 - Cross-Account Role Assumption flow via AWS STS:**

<img src="/aws-ojt-workshop-ja/images/2-Proposal/cross_account_role_assumption.png?v=2026-07-31" alt="Sequence Diagram describing STS AssumeRole flow - SaaS Lambda calls AssumeRole, AWS STS validates Trust Policy, returns temporary credentials to access EC2, S3 in customer accounts" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

*The diagram above illustrates the **Zero-Trust Cross-Account Delegation** mechanism across 6 steps: (1) Lambda in the Provider Account calls `sts:AssumeRole` with the ARN of the Cross-Account IAM Role (and the optional `ExternalId`); (2) AWS STS validates the trust policy — checking that the calling principal matches, that the `ExternalId` matches (if any), and that the role's permission boundary (if any) is satisfied; (3) Trust Policy is validated as legitimate; (4) STS issues a **session token** (`AccessKeyId`, `SecretAccessKey`, `SessionToken`) valid for 1 hour via `DurationSeconds=3600`; (5) Lambda uses these temporary credentials to build a fresh `boto3.Session` and call read-only APIs on **EC2** / **S3** / **IAM** / **Lambda** / **CloudWatch** in the customer account without storing fixed Access Keys — enforcing the **Least Privilege** principle and minimizing credential leakage risks; (6) after 1 hour the session auto-expires and the next hourly scan re-issues a fresh session. The full list of 23 read-only actions is documented in section 5.3.10.*

#### Return on Investment (ROI) & Business Benefits
- **Time Savings:** Reduces manual audit duration by over 90% (from days to minutes).
- **Cost Reduction:** Typically identifies 15% to 35% in monthly AWS infrastructure savings for onboarded accounts.
- **Near-Zero Operating Overhead:** Operating costs scale with usage on a pay-as-you-go serverless model, with an estimated idle cost of $0.00/month.

---

### 3. Solution Architecture

The system is engineered into three isolated security zones:

**Figure 2 - Overall AWS Architecture diagram of the AI AWS Advisor system:**

<img src="/aws-ojt-workshop-ja/images/2-Proposal/aws_advisor_architecture.png?v=2026-08-01-r3" alt="AWS Architecture diagram of the AI AWS Advisor - Three independent zones: (1) Client Frontend with React 19 + Vite + Tailwind Dashboard (Recharts, TanStack Query) served via CloudFront + Route 53; (2) AI Advisor Backend containing API Gateway (REST + Cognito JWT + Rate Limiting), SIX Lambda Handlers split into FIVE specialized API Handlers (ai-advisor-projects-api 5 routes, ai-advisor-resources-api 2 routes, ai-advisor-insights-api 2 routes + Bedrock + SNS, ai-advisor-chat-api 1 route + Bedrock streaming, ai-advisor-alerts-api 1 route) and ONE Collector Lambda (ai-advisor-collector triggered by EventBridge rate(1 hour), uses sts:AssumeRole + 23 AWS read-actions), DynamoDB Multi-Table (4 dedicated tables ai-advisor-projects/resources/insights/alerts + 1 GSI resource_type-index, all sharing project_id as Partition Key for tenant isolation), Amazon Bedrock Claude 3 Haiku (anthropic.claude-3-haiku-20240307-v1:0), Amazon SNS Topic ai-advisor-alerts with email subscription for critical-risk alerts; (3) Customer Target AWS Accounts with Cross-Account IAM Role AIAdvisorAuditRole + trust policy + sts:AssumeRole accessing EC2, S3, IAM, Lambda, CloudWatch." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

*The diagram above illustrates the overall architecture of the system at the **AWS infrastructure level**, split into two primary zones:*

- **Zone 1 - SaaS Provider Backend (Serverless)**: Edge Layer (CloudFront, Route 53) → Frontend (React 19 Web Dashboard, JavaScript SPA) authenticated by Amazon Cognito → API Layer (API Gateway + 5 Lambda API Handlers) → AI Layer (Amazon Bedrock with Claude 3 Haiku) → Data Layer (DynamoDB Multi-Table: 4 dedicated tables + 1 GSI) → Automation (EventBridge cron + Collector Lambda + SNS alerts).
- **Zone 2 - Customer AWS Accounts**: The Collector Lambda uses a **Cross-Account IAM Role** with `sts:AssumeRole` to scan EC2, S3, IAM, Lambda and CloudWatch resources without storing fixed Access Keys.

**Figure 3 - Detailed interaction flow of the AI Analysis process:**

<img src="/aws-ojt-workshop-ja/images/2-Proposal/ai_analysis.png?v=2026-07-31" alt="Detailed interaction flow between Frontend, API Gateway, Lambda, Bedrock, DynamoDB and SNS during the AI Analysis process" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

*The figure above illustrates the sequence of interactions between system components during AI analysis: the Frontend sends an analysis request via API Gateway; the Lambda invokes Amazon Bedrock (Claude 3 Haiku) with context loaded from DynamoDB; structured recommendations are returned; results are persisted and SNS alerts are emitted when critical thresholds are breached.*

#### AWS Managed Services Used
- **AWS Lambda:** Executes API endpoints, AI chat queries, and cron data collection.
- **Amazon API Gateway:** Provides secure, rate-limited REST endpoints for the frontend.
- **Amazon DynamoDB:** Multi-Table NoSQL database (4 dedicated tables: `projects`, `resources`, `insights`, `alerts`) storing project metadata, resource snapshots and AI insights with `project_id` Partition Key for tenant isolation.
- **Amazon Bedrock (Claude 3 Haiku):** Generative AI reasoning engine parsing raw AWS JSON into structured remediation plans.
- **Amazon EventBridge & SNS:** Cron scheduling for hourly audits and automated email alert notifications.
- **AWS STS:** Cross-account role delegation (`sts:AssumeRole`).

---

### 4. Technical Implementation Plan

#### Implementation Phases

1. **Phase 1: Security & Architecture Setup (Month 1):** Define Cross-Account IAM trust policies, set up AWS SAM CLI templates, and design the DynamoDB Multi-Table schema (4 tables: `projects`, `resources`, `insights`, `alerts`; plus 1 GSI on `resource_type`).
2. **Phase 2: Core Scanner & Bedrock Integration (Month 2):** Implement `boto3` resource collectors (EC2, S3, IAM, Lambda, CloudWatch), configure Amazon Bedrock Claude 3 prompt engineering, and write automated Pytest unit tests with `moto`. The detailed interaction flow between components has already been illustrated in Figure 1 (STS AssumeRole) and Figure 3 (AI Analysis) in §1/§3 above.

3. **Phase 3: Frontend Dashboard & AI Chatbot (Month 3):** Develop React 19 frontend dashboard (JavaScript SPA) with Vite, Tailwind CSS, and Recharts; integrate AI Copilot endpoint; execute end-to-end testing and SAM CloudFormation deployment.

---

### 5. Timeline & Key Milestones

**Figure 3 - 3-Month Implementation Roadmap with Key Milestones:**

<img src="/aws-ojt-workshop-ja/images/2-Proposal/implementation_roadmap_en.png?v=2026-08-01" alt="3-Month Implementation Roadmap for the AI AWS Advisor project - 3 phase boxes M1, M2, M3 connected by downward arrows showing the progression Architecture & SAM IaC → Collector Lambda & Bedrock → React Dashboard & AI Chatbot" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

*The roadmap above illustrates the project execution plan split across 3 months with the corresponding milestones. **Month 1** focuses on Security & Architecture Setup (Cross-Account Trust Policy, SAM IaC, DynamoDB Multi-Table schema). **Month 2** delivers the Core Scanner & Bedrock Integration (`boto3` Collectors, prompt engineering, Pytest unit tests). **Month 3** ships the Frontend Dashboard & AI Chatbot (React 19 + Vite + Tailwind, end-to-end tests, SAM CloudFormation deployment).*

---

### 6. Budget Estimation

Estimated monthly cost based on 10 active customer projects auditing 1,000 AWS resources daily:

| AWS Service | Usage / Metric | Estimated Cost / Month |
| :--- | :--- | :--- |
| **AWS Lambda** | 100,000 invocations, 512 MB memory | $0.00 (Free Tier) |
| **Amazon API Gateway** | 50,000 REST requests | $0.05 |
| **Amazon DynamoDB** | On-Demand (2 GB storage, 500k reads/writes) | $0.25 |
| **Amazon Bedrock** | Claude 3 Haiku (1M Input tokens, 200k Output tokens) | $1.20 |
| **Amazon EventBridge & SNS** | 720 triggers/month, 100 emails | $0.01 |
| **Total Estimated Monthly Cost** | **Serverless Pay-Per-Use** | **~$1.51 / month** |

*Annual Projected Infrastructure Cost:* **~$18.12 USD / year**.

---

### 7. Risk Assessment & Mitigation

| Identified Risk | Impact | Probability | Mitigation Strategy |
| :--- | :--- | :--- | :--- |
| **Bedrock API Rate Limits** | Medium | Low | Implement exponential backoff retries & caching insights in DynamoDB. |
| **Cross-Account Access Revocation** | High | Medium | Gracefully catch `ClientError` during `sts:AssumeRole` and flag project as disconnected. |
| **LLM Output Hallucinations** | High | Low | Enforce strict JSON schema prompt outputs & fallback regex JSON parsers in Python. |
| **Unbounded Cloud Costs** | Medium | Low | Configure AWS Budgets alerts ($5/month limit) & limit cron frequency. |

---

### 8. Expected Outcomes

1. **Automated Audit Pipeline:** Replaces manual inspections with automated, hourly AI-driven cloud audits.
2. **Zero Credential Liability:** Guaranteed data safety via temporary `sts:AssumeRole` session credentials.
3. **Reusable Cloud Architecture:** Establishes a production-ready blueprint for serverless B2B SaaS platforms on AWS.