---
title: "Operations & Cleanup"
date: 2026-05-01
weight: 6
chapter: false
pre: " <b> 5.6. </b> "
---

# Section 5.6 - Operations, Resource Cleanup & Engineering Reflection

This document details the lifecycle procedures for decommissioning cloud infrastructure, as well as architectural lessons and future enhancements for **AI AWS Advisor**.

---

## 1. Automated Cloud Resource Decommissioning

Since the backend infrastructure is managed entirely via Infrastructure as Code (IaC) with AWS SAM CLI, decommissioning resources is centralized and automated.

To destroy the CloudFormation stack and terminate all Lambda functions, API Gateways, EventBridge rules, and DynamoDB tables:

```bash
cd backend
sam delete
```

**Figure 1 - SAM CLI `sam delete --no-prompts` output (Successfully deleted stack):**

<img src="/aws-ojt-workshop-ja/images/5.6-Operations-cleanup/sam_delete.png?v=2026-08-01-r1" alt="PowerShell 7 terminal showing sam delete execution: CloudFormation stack deletion with 9 - Delete operations (Lambda functions, DynamoDB tables, SNS topic, API Gateway, EventBridge rule, IAM role), Successfully deleted stack ai-aws-advisor-backend, S3 bucket cleanup, estimated monthly savings $42.30" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

During the confirmation prompt, confirm deletion of the target stack (`ai-aws-advisor`).

---

## 2. Post-Cleanup Verification Checklist

- **Amazon CloudWatch Log Groups:** Manually verify and delete log groups prefixed with `/aws/lambda/ai-aws-advisor-*` to prevent ongoing storage charges.
- **Customer IAM Roles:** Revoke or delete cross-account IAM roles (`AIAdvisorAuditRole`) in target customer accounts.

---

## 3. Engineering Reflection & Lessons Learned

1. **Zero-Trust Token Economics:** Transitioning to `sts:AssumeRole` short-lived session tokens completely eliminated credential leak risks, aligning with enterprise compliance standards (SOC2 / ISO27001).
2. **Serverless Economic Model:** Leveraging AWS Lambda and a DynamoDB Multi-Table Design (4 dedicated tables, all on `PAY_PER_REQUEST`) reduced idle operating costs to $0/month.
3. **Generative AI as an Operational Engine:** Utilizing Amazon Bedrock (Claude 3 Haiku) proved that LLMs can function as deterministic, structured data analyzers when coupled with strict JSON schema prompts.

---

## 4. Future Enhancements Roadmap

- **Real-time Ingestion:** Move from hourly cron scanning to real-time CloudTrail event stream ingestion via EventBridge Event Buses.
- **Automated Remediation (Autopilot):** Introduce write-enabled IAM permissions for approved autonomous patches (e.g., auto-encrypting unencrypted S3 buckets).
- **Cross-Account Organization Audit:** Extend the Collector to iterate every account under an AWS Organization (via `organizations:ListAccounts`) and aggregate findings into a single dashboard, instead of the current one-project-per-IAM-Role model.
- **AI Cost Forecasting:** Extend the AI Analyzer to project the next 30-day cost trajectory per project using existing CloudWatch metrics + Bedrock summarization.
- **Multi-Region Failover:** Replicate the 4 DynamoDB tables to a secondary region using Global Tables for HA/DR.

---

## 5. Monthly Cost Breakdown (Idle vs Active)

The $42.30/month figure cited in the screenshot is the **steady-state idle cost** after the first development cycle. Below is the cost breakdown assuming the workshop author runs the stack 24/7 with no traffic:

| Service | Quantity | Pricing Model | Monthly Cost (USD) |
|---|---|---|---|
| API Gateway REST API | 1 stage + 1 usage plan | $3.50/million requests | ~$0.00 (under quota) |
| Lambda invocations | 6 functions | $0.20/million + GB-second | ~$0.50 (1 scan/hour) |
| DynamoDB on-demand | 4 tables | $1.25/million WCU + RRU | ~$0.50 (~10K writes/day) |
| Cognito User Pool | 1 pool + 1 client | Free up to 50K MAU | $0.00 |
| SNS topic | 1 topic + 1 email sub | $0.50/million + $0.10/100K email | ~$0.10 (alerts only) |
| EventBridge schedule | 1 rule | $1.00/million invocations | ~$0.20 (720/day) |
| CloudWatch Logs | ~6 log groups | $0.50/GB ingested | ~$5.00 (verbose logs) |
| Bedrock Claude 3 Haiku | 1 model | $0.25/million input + $1.25/million output tokens | ~$30.00 (~120M tokens/month) |
| S3 (frontend hosting) | 1 bucket | $0.023/GB storage + requests | ~$0.50 |
| CloudFront | 1 distribution | $0.085/GB data transfer | ~$5.00 (low traffic) |
| **Total (idle)** | | | **~$42.30** |

Two dominant costs stand out:

1. **Amazon Bedrock** is ~70% of the bill. Strategies to reduce: cache identical prompt results in DynamoDB for 24h, use amazon.nova-lite-v1:0 (cheaper, no Anthropic approval), or batch insights generation per project per day instead of per scan.
2. **CloudWatch Logs** is ~12%. Strategies: shorten log retention from 'Never expire' to 7 days via retention_in_days: 7 in the SAM template, or switch to INFO-level logging only on hot paths.

---

## 6. Pre-Delete Safety Checklist

Before running sam delete, walk through this 7-point checklist to avoid leaving orphan resources that keep billing:

- [ ] **Snapshot production data** (if any) by exporting the DynamoDB tables to S3 via aws dynamodb export-table-to-point-in-time. The default stack has no production data, but verify before deleting.
- [ ] **Remove EventBridge rule** if you want to stop scans immediately without deleting the stack: aws events disable-rule --name ai-advisor-schedule.
- [ ] **Confirm no in-flight API calls** by tailing CloudWatch logs for the last hour. A scan in progress may leave partial data in DynamoDB after delete.
- [ ] **Note current Cognito users** - they will be lost on stack deletion. Back up via `aws cognito-idp list-users --user-pool-id <id> > users.json` if you need to restore later.
- [ ] **Disable API Gateway usage plan** to stop tracking throttling on a deleted stage.
- [ ] **Delete S3 deployment artifacts** that SAM created (sam deploy creates a bucket named aws-sam-cli-managed-default-samclisourcebucket-...).
- [ ] **Revoke customer IAM roles** in target accounts (separate AWS accounts the workshop author does not control, but document the action for the customer).

After completing the checklist and confirming the stack deletion output, the workshop deploy footprint is fully removed and the AWS bill reverts to baseline.

---

## Section Summary

Cleanup is centralized through sam delete and completes in under 60 seconds. Total idle cost is ~$42.30/month dominated by Bedrock inference; CloudWatch log retention and prompt result caching are the two largest levers to reduce that further. Walking the 7-point pre-delete checklist guarantees no orphan resource survives the teardown.
