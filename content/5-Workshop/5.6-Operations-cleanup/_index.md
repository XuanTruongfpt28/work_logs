---
title: "Operations & Cleanup"
date: 2026-07-07
weight: 6
chapter: false
pre: " <b> 5.6. </b> "
---

# Section 5.6 - Operations, Resource Cleanup & Architecture Review

This document walks through the process for safely tearing down system resources, and summarizes the architecture and future direction for **AI AWS Advisor**.

---

## 1. Automated Cloud Resource Teardown

Since the entire Backend infrastructure is managed as code (IaC) via the AWS SAM CLI, resource cleanup is fully automated.

To delete the CloudFormation stack and release all Lambda functions, API Gateway, EventBridge rules, and DynamoDB tables:

```bash
cd backend
sam delete
```

**Figure 1 - SAM CLI `sam delete --no-prompts` output (Successfully deleted stack):**

![Sam_delete](/images/5-Workshop/5.6-Operations-cleanup/sam_delete.png)


Confirm the deletion when prompted for the stack name (`ai-aws-advisor`).

---

## 2. Post-Cleanup Checklist

- **Amazon CloudWatch Log Groups:** Check and manually delete log groups prefixed `/aws/lambda/ai-aws-advisor-*` to avoid accumulating storage costs.
- **Revoke the Customer IAM Role:** Delete the delegation IAM Roles (`AIAdvisorAuditRole`) on the customer's AWS accounts.

---

## 3. Architecture Summary & Lessons Learned

1. **Zero-Trust Security Model:** Using `sts:AssumeRole` completely eliminates the risk of long-lived Access Key leaks, meeting enterprise compliance standards (SOC2 / ISO27001).
2. **Cost Optimization with Serverless:** Using AWS Lambda and a Multi-Table DynamoDB design (4 dedicated tables, all on `PAY_PER_REQUEST`) keeps the system's idle cost at $0/month.
3. **AI as the Operating Engine:** Amazon Bedrock (Claude 3 Haiku) proves that an LLM works extremely effectively as a tool for turning raw configuration data into standardized, structured JSON.

---

## 4. Future Direction

- **Real-Time Event Processing:** Move from hourly scheduled scanning to real-time CloudTrail event-stream processing via an EventBridge Event Bus.
- **Automated Remediation (Autopilot):** Add controlled write permissions so the AI Advisor can auto-fix issues (e.g. automatically enabling encryption on an S3 bucket).
- **Real-time Ingestion:** Move from hourly cron scanning to real-time CloudTrail event stream ingestion via EventBridge Event Buses.
- **Automated Remediation (Autopilot):** Add write-enabled IAM permissions for approved autonomous patches (e.g. automatically encrypting an unencrypted S3 bucket).
- **Cross-Account Organization Audit:** Extend the Collector to walk every account in an AWS Organization (via `organizations:ListAccounts`) and roll up every finding into a single dashboard, replacing today's one-project-per-IAM-Role model.
- **AI Cost Forecasting:** Extend the AI Analyzer to forecast each project's cost trajectory over the next 30 days using CloudWatch metrics + Bedrock summarization.
- **Multi-Region Failover:** Replicate the 4 DynamoDB tables to a secondary region via Global Tables for HA/DR.

---

## 5. Monthly Cost (Idle vs. Active)

The $42.30/month figure shown in the screenshot is the **idle steady-state cost** after the first development cycle. Below is a cost breakdown assuming the workshop author runs the stack 24/7 with no traffic:

| Service | Quantity | Pricing Model | Monthly Cost (USD) |
|---|---|---|---|
| API Gateway REST API | 1 stage + 1 usage plan | $3.50/million requests | ~$0.00 (under quota) |
| Lambda invocations | 6 functions | $0.20/million + GB-second | ~$0.50 (1 scan/hour) |
| DynamoDB on-demand | 4 tables | $1.25/million WCU + RRU | ~$0.50 (~10K writes/day) |
| Cognito User Pool | 1 pool + 1 client | Free up to 50K MAU | $0.00 |
| SNS topic | 1 topic + 1 email sub | $0.50/million + $0.10/100K emails | ~$0.10 (alerts only) |
| EventBridge schedule | 1 rule | $1.00/million invocations | ~$0.20 (720/day) |
| CloudWatch Logs | ~6 log groups | $0.50/GB ingested | ~$5.00 (verbose logs) |
| Bedrock Claude 3 Haiku | 1 model | $0.25/million input + $1.25/million output tokens | ~$30.00 (~120M tokens/month) |
| S3 (frontend hosting) | 1 bucket | $0.023/GB storage + requests | ~$0.50 |
| CloudFront | 1 distribution | $0.085/GB data transfer | ~$5.00 (low traffic) |
| **Total (idle)** | | | **~$42.30** |

The two largest cost drivers:

1. **Amazon Bedrock** accounts for ~70%. Ways to reduce it: cache identical prompt results in DynamoDB for 24h, switch to amazon.nova-lite-v1:0 (cheaper, no Anthropic approval needed), or batch insight generation per project/day instead of per scan.
2. **CloudWatch Logs** accounts for ~12%. Ways to reduce it: set retention from "Never expire" down to 7 days via retention_in_days: 7 in the SAM template, or only log at INFO level on hot paths.

---

## 6. Safety Checklist Before Deleting

Before running `sam delete`, check the following items to avoid leaving orphan resources that keep incurring cost:

* **Back up production data (if any):** Export the DynamoDB tables to Amazon S3 using `aws dynamodb export-table-to-point-in-time`. By default the workshop doesn't use production data, but it's still worth verifying before deleting.
* **Disable the EventBridge Rule (if not deleting the stack right away):** If you only want to pause the periodic scan, use `aws events disable-rule --name ai-advisor-schedule`.
* **Check for active API activity:** Monitor CloudWatch Logs over the past hour to make sure no scan is currently in progress, to avoid leaving incomplete data in DynamoDB when the stack is deleted.
* **Back up the Cognito user list:** Every user in the User Pool will be deleted along with the stack. If you might need to restore them later, export the list with `aws cognito-idp list-users --user-pool-id <UserPoolId> > users.json`.
* **Disable the API Gateway Usage Plan:** Do this if you want to stop tracking throttling limits and API usage statistics.
* **Delete S3 Deployment Artifacts:** Clean up the bucket created by AWS SAM to store deployment artifacts (e.g. `aws-sam-cli-managed-default-samclisourcebucket-...`).
* **Revoke the Customer IAM Role:** If you configured an IAM Role on customer AWS accounts for AI AWS Advisor to `AssumeRole`, revoke or delete these roles once they're no longer needed.

Once you've completed the steps above and confirmed `sam delete` ran successfully, every resource deployed by AI AWS Advisor will be cleaned up, and AWS costs will return to baseline.

## Section Summary

Cleanup is centered around `sam delete` and completes in under 60 seconds. The total idle cost of ~$42.30/month is dominated by Bedrock inference; log retention and prompt-result caching are the two biggest levers for further reducing it. Walking through the 7-point checklist ensures no orphan resources survive teardown.