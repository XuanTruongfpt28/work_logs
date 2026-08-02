---
title: "Workshop"
date: 2026-05-01
weight: 5
chapter: false
pre: " <b> 5. </b> "
---

# AI AWS Advisor (Enterprise SaaS)

#### Overview

**AI AWS Advisor** is an enterprise-grade B2B SaaS (Software as a Service) platform that leverages Generative AI (**Amazon Bedrock - Claude 3 Haiku**) to automatically scan, analyze, and generate optimization recommendations for customer AWS infrastructure.

The platform solves three core challenges in Cloud Operations (CloudOps):
1. **Security:** Identifies vulnerabilities such as Public S3 Buckets, Over-privileged IAM Roles, and unencrypted storage.
2. **Cost Optimization:** Detects wasted resources (Idle EC2 instances, Unattached EBS volumes, unutilized Elastic IPs) and calculates potential monthly savings.
3. **Performance & Reliability:** Proposes architectural improvements (e.g., configuring Provisioned Concurrency for AWS Lambda to prevent cold starts).

---

#### Key Features & Architecture Highlights

- **Zero-Trust Security (Cross-Account STS):** Uses `sts:AssumeRole` to generate temporary, short-lived audit credentials without storing long-term AWS Access Keys.
- **100% Serverless Architecture:** Built on AWS Lambda, Amazon API Gateway, and Amazon EventBridge with $0 idle cost.
- **Multi-Table Design (Amazon DynamoDB):** Four dedicated tables (projects, resources, insights, alerts) sharing `project_id` Partition Key for tenant isolation, with one GSI (`resource_type-index`) on `ai-advisor-resources` for cross-project queries.
- **Generative AI Copilot (Amazon Bedrock):** Powered by Claude 3 Haiku for automated insights and real-time infrastructure Q&A.

---

#### Content

1. [Workshop Overview](5.1-workshop-overview/)
2. [Prerequisites & Setup](5.2-prerequiste/)
3. [Architecture & Technical Design](5.3-architecture-design/)
4. [Deployment Strategy & Customer Onboarding](5.4-deployment-strategy/)
5. [Quality Assurance & Testing](5.5-quality-assurance/)
6. [Operations, Cleanup & Reflection](5.6-operations-cleanup/)