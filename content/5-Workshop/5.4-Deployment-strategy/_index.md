---
title: "Deployment Strategy"
date: 2026-05-01
weight: 4
chapter: false
pre: " <b> 5.4. </b> "
---

# Section 5.4 - Deployment Strategy & Onboarding

This document details the deployment workflow for both the backend serverless infrastructure and the frontend React application, as well as the customer onboarding process.

---

## 1. Backend Serverless Deployment (AWS SAM CLI)

### Step 1: Build Source Code
Compile dependencies inside an Amazon Linux container to ensure binary compatibility with AWS Lambda.

```bash
cd backend
sam build --use-container
```

**Figure 1 - SAM CLI `sam build --use-container` output (Build Succeeded):**

<img src="/aws-ojt-workshop-ja/images/5.4-Deployment-strategy/sam_build.png?v=2026-08-01-r1" alt="PowerShell 7 terminal showing successful sam build --use-container execution: Building codeuri backend, Running CustomMakeBuilder for Python function, Build Succeeded, Built Artifacts .aws-sam/build, Built Template .aws-sam/build/template.yaml" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

### Step 2: Deploy CloudFormation Stack
Execute guided deployment to provision API Gateway, Lambda Functions, DynamoDB, EventBridge, and SNS.

```bash
sam deploy --guided
```

**Figure 2 - SAM CLI `sam deploy --guided` output (Successfully created/updated stack):**

<img src="/aws-ojt-workshop-ja/images/5.4-Deployment-strategy/sam_deploy.png?v=2026-08-01-r1" alt="PowerShell 7 terminal showing successful sam deploy --guided execution: 9 AWS resources listed (IAM roles, Lambda functions, DynamoDB tables, SNS topic, API Gateway, EventBridge rule), CloudFormation changeset with + Create operations, Successfully created/updated stack ai-aws-advisor-backend in us-east-1, Outputs including ApiEndpoint URL" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

Parameters specified during prompt:
- **Stack Name:** `ai-aws-advisor`
- **AWS Region:** `us-east-1` (or matching Bedrock availability region)
- **Confirm changes before deploy:** `Y`
- **Allow SAM CLI IAM role creation:** `Y`
- **Save parameters to configuration file:** `Y` (`samconfig.toml`)

### Step 3: Capture Outputs
Record the generated `ApiGatewayEndpoint` URL output by SAM CLI (e.g., `https://<api-id>.execute-api.us-east-1.amazonaws.com/prod`).

---

## 2. Frontend Deployment & Configuration

### Step 1: Environment Configuration
Create a `.env` file in `frontend/`:

```env
VITE_API_BASE_URL=https://<your-api-id>.execute-api.us-east-1.amazonaws.com/prod
```

### Step 2: Start Local Dev Server
```bash
cd frontend
npm install
npm run dev
```

### Step 3: Production Build
```bash
npm run build
```
Generates minified static assets in `dist/` ready for hosting on Amazon S3 + CloudFront, Vercel, or Netlify.

---

## 3. Customer Account Onboarding

To connect a target AWS account for auditing:

1. Customer logs into their target AWS Account Console.
2. Navigates to **IAM -> Roles -> Create Role**.
3. Selects **AWS Account** trusted entity and enters our SaaS Provider Account ID.
4. Attaches `ReadOnlyAccess` policy to the role.
5. Copies the generated **Role ARN** (`arn:aws:iam::<CustomerAccountID>:role/AIAdvisorAuditRole`).
6. Submits the Role ARN in the AI AWS Advisor dashboard when adding a new Project.

**Figure 3 - Customer IAM Role summary page (Account ID redacted):**

<img src="/aws-ojt-workshop-ja/images/5.4-Deployment-strategy/iam_audit_role_summary.png?v=2026-08-01-r1" alt="AWS IAM console showing the AIAdvisorAuditRole summary page in the customer AWS account - Role ARN arn:aws:iam::XXXXXXXXXXXX:role/AIAdvisorAuditRole with ReadOnlyAccess managed policy attached and trusted entity set to a specific AWS Account" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Figure 4 - Trust relationships tab — Trust policy JSON (Account ID redacted):**

<img src="/aws-ojt-workshop-ja/images/5.4-Deployment-strategy/iam_audit_role_trust_policy.png?v=2026-08-01-r1" alt="AWS IAM Trust relationships tab of AIAdvisorAuditRole displaying JSON trust policy with Action sts:AssumeRole and Principal AWS arn:aws:iam::XXXXXXXXXXXX:root - exactly the cross-account delegation pattern AI AWS Advisor uses" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

---

## 4. CloudFormation Outputs (Capture After Deploy)

After sam deploy --guided completes, SAM CLI prints 5 outputs that the frontend and CLI scripts depend on. Record them immediately - they are the only way to wire the SPA to the API, the AI scanner to the customer IAM role, and the SNS alert pipeline to the recipient email:

| Output Key | Description | Example |
|---|---|---|
| ApiGatewayEndpoint | The base URL the React SPA calls. | https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod |
| CollectorFunctionArn | ARN of the scheduled Collector Lambda. | arn:aws:lambda:us-east-1:111122223333:function:ai-advisor-collector |
| AlertsTopicArn | SNS Topic ARN for high-severity alerts (subscribe customer email here). | arn:aws:sns:us-east-1:111122223333:ai-advisor-alerts |
| UserPoolId | Cognito User Pool ID (use in frontend .env). | us-east-1_aBcDeFgHi |
| UserPoolClientId | Cognito User Pool Client ID (use in frontend .env). | 7a8b9c0d1e2f3g4h5i6j7k8l9m |

Fetch them at any time with this one-liner:

```bash
aws cloudformation describe-stacks 
  --stack-name ai-aws-advisor 
  --query 'Stacks[0].Outputs[].OutputValue' 
  --output text
` 

---

## 5. Frontend Production Deployment (S3 + CloudFront)

For a production-grade SPA deployment, host the static dist/ folder on Amazon S3 behind a CloudFront CDN. The build step from §2.3 produces the artifacts in `frontend/dist/` - now we ship them.

### Step 1: Create an S3 bucket for static hosting

```bash
aws s3 mb s3://ai-aws-advisor-web-prod --region us-east-1
aws s3 website s3://ai-aws-advisor-web-prod --index-document index.html --error-document index.html
` 

### Step 2: Upload the production build

```bash
cd frontend
aws s3 sync dist/ s3://ai-aws-advisor-web-prod --delete --cache-control 'public, max-age=31536000, immutable'
```

### Step 3: Create a CloudFront distribution pointing to the bucket

```bash
aws cloudfront create-distribution 
  --origin-domain-name ai-aws-advisor-web-prod.s3.amazonaws.com 
  --default-root-object index.html
` 

{{% notice warning %}}For SPA routing, configure CloudFront custom error responses: map both 403 and 404 to /index.html with HTTP 200 so client-side routes like /projects/abc do not break on hard reload.{{% /notice %}}

### Step 4: Set the SPA environment variables at build time

The React app reads `VITE_API_BASE_URL`, `VITE_USER_POOL_ID`, and `VITE_USER_POOL_CLIENT_ID` at **build time** (Vite inlines them). Set them in `frontend/.env.production` before `npm run build`:

```env
VITE_API_BASE_URL=https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod
VITE_USER_POOL_ID=us-east-1_aBcDeFgHi
VITE_USER_POOL_CLIENT_ID=7a8b9c0d1e2f3g4h5i6j7k8l9m
VITE_AWS_REGION=us-east-1
```

---

## 6. Dashboard Walkthrough: Adding a Customer Project

Once the SPA is live, an operator adds a customer account in four dashboard steps:

1. **Sign in** at the CloudFront URL with the Cognito credentials created in §5.2.6. JWT is stored in localStorage and attached to every API call by an Axios interceptor.
2. **Navigate to Projects -> Add Project**. Fill in: project name, AWS region to scan, and the customer-provided Role ARN from §3 above.
3. **Trigger a manual scan** by clicking Sync Now. The frontend POSTs to /projects/{id}/sync, which Lambda-invokes the Collector. The first scan typically completes within 30-60 seconds for a small AWS account.
4. **Open the Dashboard** to see Cost / Performance / Security tabs populated with AI-generated insights. Click any card to drill down into the raw JSON resource data.

The hourly EventBridge schedule keeps the data fresh in the background without operator intervention.

**Figure 6 - Dashboard view after a successful first scan, showing 4 KPI cards and per-project insights generated by Bedrock Claude 3 Haiku:**

<img src="/aws-ojt-workshop-ja/images/5.1-Workshop-overview/ui_dashboard_overview.png?v=2026-08-01-r4" alt="AI AWS Advisor Dashboard Overview page after a successful first customer scan - top row shows four live KPI cards computed by the Collector Lambda: System Health 78%, Resources 75, Critical Risks 4, Monthly Savings $2.5K. The tab switcher is on ProDev (active, purple), Beta Dev and Production. Each tab loads an AI Analysis panel with severity counts (High: 4, Medium: 0, Low: 0) and an AI Chat input. The data was generated by Bedrock Claude 3 Haiku from raw resources stored in the ai-advisor-resources DynamoDB table." width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

---

## Section Summary

This deployment strategy walks through 4 concrete tracks: (1) SAM backend deploy with outputs capture, (2) local frontend development, (3) customer-side IAM role onboarding, and (4) production SPA hosting on S3 + CloudFront. Every artifact is reproducible from the repository via a single `sam deploy --guided` + `npm run build` + `aws s3 sync` sequence.
