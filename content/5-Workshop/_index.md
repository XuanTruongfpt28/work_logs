---
title: "Workshop"
date: 2026-07-07
weight: 5
chapter: false
pre: " <b> 5. </b> "
---

# AI AWS Advisor (Enterprise SaaS)

#### Overview

**AI AWS Advisor** is an enterprise-grade B2B SaaS (Software as a Service) platform that applies next-generation AI (**Amazon Bedrock - Claude 3 Haiku**) to automatically scan, analyze, and generate optimization recommendations for a customer's AWS infrastructure.

The system addresses 3 core CloudOps challenges:
1. **Security:** Detecting security vulnerabilities such as public S3 Buckets and over-privileged IAM Roles.
2. **Cost Optimization:** Detecting wasted resources (idle EC2 instances, unattached EBS Volumes, unused Elastic IPs) and calculating monthly savings.
3. **Performance & Reliability:** Recommending architectural improvements (e.g. configuring Provisioned Concurrency for AWS Lambda to avoid cold starts).

---

#### Technical Highlights

- **Zero-Trust Security (Cross-Account STS):** Uses `sts:AssumeRole` to generate short-lived temporary credentials, never storing the customer's long-lived Access Keys.
- **100% Serverless Architecture:** Built on AWS Lambda, Amazon API Gateway, and Amazon EventBridge, keeping idle cost at approximately $0.
- **Multi-Table Design (Amazon DynamoDB):** Four dedicated tables (projects, resources, insights, alerts) sharing a common `project_id` Partition Key for tenant isolation, plus 1 GSI (`resource_type-index`) on `ai-advisor-resources` for cross-project queries.
- **Generative AI Copilot (Amazon Bedrock):** Integrates Claude 3 Haiku to automatically generate reports and hold live conversations about the infrastructure.

---

#### Report Contents

1. [Workshop Overview](5.1-workshop-overview/)
2. [Requirements & Environment Setup](5.2-prerequiste/)
3. [Architecture & Technical Design](5.3-architecture-design/)
4. [Deployment Strategy & Customer Integration](5.4-deployment-strategy/)
5. [Testing & Quality Assurance](5.5-quality-assurance/)
6. [Operations, Cleanup & Architecture Review](5.6-operations-cleanup/)