---
title: "Deployment Strategy"
date: 2026-07-07
weight: 4
chapter: false
pre: " <b> 5.4. </b> "
---

# Section 5.4 - Deployment Strategy & Customer Integration

This document details the process for deploying the Serverless Backend infrastructure, the React Frontend application, and the steps for integrating a customer's AWS account into the system.

---

## 1. Deploying the Serverless Backend (AWS SAM CLI)

### Step 1: Build the Source Code
Build the dependencies inside an Amazon Linux container to ensure binary compatibility with AWS Lambda.

```bash
cd backend
sam build --use-container
```

**Figure 1 - SAM CLI `sam build --use-container` output (Build Succeeded):**

![SAM Build](/images/5-Workshop/5.4-Deployment-strategy/sam_build.png)

### Step 2: Deploy the CloudFormation Stack
Run the guided deployment to provision API Gateway, Lambda Functions, DynamoDB, EventBridge, and SNS.

```bash
sam deploy --guided
```

**Figure 2 - SAM CLI `sam deploy --guided` output (Successfully created/updated stack):**

![SAM Deploy](/images/5-Workshop/5.4-Deployment-strategy/sam_deploy.png)

Key parameters:
- **Stack Name:** `ai-aws-advisor`
- **AWS Region:** `us-east-1` (or any region that supports Amazon Bedrock)
- **Confirm changes before deploy:** `Y`
- **Allow SAM CLI IAM role creation:** `Y`
- **Save parameters to configuration file:** `Y` (`samconfig.toml`)

### Step 3: Record the Outputs
Note down the `ApiGatewayEndpoint` URL printed by the SAM CLI (e.g. `https://<api-id>.execute-api.us-east-1.amazonaws.com/prod`).

---

## 2. Deploying the React Frontend Application

### Step 1: Configure the Environment
Create a `.env` file in the `frontend/` directory:

```env
VITE_API_BASE_URL=https://<your-api-id>.execute-api.us-east-1.amazonaws.com/prod
```

### Step 2: Run the Development Server
```bash
cd frontend
npm install
npm run dev
```

### Step 3: Build for Production
```bash
npm run build
```
This generates static assets in the `dist/` directory, ready to be uploaded to Amazon S3 + CloudFront, Vercel, or Netlify.

---

## 3. Customer Account Integration Process

Steps the customer performs to connect the AWS account that needs to be audited:

1. The customer logs into the AWS Console of the account to be audited.
2. Navigates to **IAM -> Roles -> Create Role**.
3. Selects **AWS Account** as the Trusted Entity type and enters the SaaS Provider's Account ID.
4. Attaches the `ReadOnlyAccess` policy to the IAM Role.
5. Copies the resulting **Role ARN** (`arn:aws:iam::<CustomerAccountID>:role/AIAdvisorAuditRole`).
6. Enters this Role ARN in the AI AWS Advisor Dashboard to create a Project.

**Figure 3 - Customer-side IAM Role summary page (Account ID redacted):**

![IAM Audit Role Summary](/images/5-Workshop/5.4-Deployment-strategy/iam_audit_role_summary.png)

**Figure 4 - Trust relationships tab — JSON Trust policy (Account ID redacted):**

![IAM Trust Policy](/images/5-Workshop/5.4-Deployment-strategy/iam_audit_role_trust_policy.png)

---

## 4. CloudFormation Outputs (Record After Deploying)

Once `sam deploy --guided` finishes, the SAM CLI prints 5 outputs that the frontend and CLI scripts depend on. Record these immediately — this is the only way to wire the SPA to the API, the AI scanner to the customer's IAM role, and the SNS alert pipeline to the recipient's email:

| Output Key | Description | Example |
|---|---|---|
| ApiGatewayEndpoint | Base URL the React SPA calls. | https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod |
| CollectorFunctionArn | ARN of the scheduled Collector Lambda. | arn:aws:lambda:us-east-1:111122223333:function:ai-advisor-collector |
| AlertsTopicArn | ARN of the SNS Topic for high-severity alerts (subscribe the customer's email here). | arn:aws:sns:us-east-1:111122223333:ai-advisor-alerts |
| UserPoolId | Cognito User Pool ID (used in the frontend .env). | us-east-1_aBcDeFgHi |
| UserPoolClientId | Cognito User Pool Client ID (used in the frontend .env). | 7a8b9c0d1e2f3g4h5i6j7k8l9m |

Retrieve these again at any time with a single command:

```bash
aws cloudformation describe-stacks \
  --stack-name ai-aws-advisor \
  --query 'Stacks[0].Outputs[].OutputValue' \
  --output text
```

---

## 5. Production Frontend Deployment (S3 + CloudFront)

To deploy a production-grade SPA, host the static `dist/` folder on Amazon S3 behind a CloudFront CDN. The build step from §2.3 already produced the artifacts in `frontend/dist/` — now ship them.

### Step 1: Create an S3 bucket for static hosting

```bash
aws s3 mb s3://ai-aws-advisor-web-prod --region us-east-1
aws s3 website s3://ai-aws-advisor-web-prod --index-document index.html --error-document index.html
```

### Step 2: Upload the production build

```bash
cd frontend
aws s3 sync dist/ s3://ai-aws-advisor-web-prod --delete --cache-control 'public, max-age=31536000, immutable'
```

### Step 3: Create a CloudFront distribution pointing at the bucket

```bash
aws cloudfront create-distribution \
  --origin-domain-name ai-aws-advisor-web-prod.s3.amazonaws.com \
  --default-root-object index.html
```

{{% notice warning %}}For SPA routing, configure a CloudFront custom error response: map both 403 and 404 to /index.html with HTTP 200, so client-side routes like /projects/abc don't break on a hard reload.{{% /notice %}}

### Step 4: Set the SPA's build-time environment variables

The React app reads `VITE_API_BASE_URL`, `VITE_USER_POOL_ID`, and `VITE_USER_POOL_CLIENT_ID` **at build time** (Vite inlines them). Set these in `frontend/.env.production` before running `npm run build`:

```env
VITE_API_BASE_URL=https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod
VITE_USER_POOL_ID=us-east-1_aBcDeFgHi
VITE_USER_POOL_CLIENT_ID=7a8b9c0d1e2f3g4h5i6j7k8l9m
VITE_AWS_REGION=us-east-1
```

---

## 6. Dashboard Walkthrough: Adding a Customer Project

Once the SPA is live, an operator adds a customer account through 4 steps on the dashboard:

1. **Log in** at the CloudFront URL using the Cognito credentials created in §5.2.6. The JWT is stored in localStorage and attached to every API call via an Axios interceptor.
2. **Go to Projects -> Add Project.** Fill in: the project name, the AWS region to scan, and the Role ARN provided by the customer (see §3 above).
3. **Trigger a manual scan** by clicking Sync Now. The frontend POSTs to /projects/{id}/sync, and the Lambda invokes the Collector. The first scan typically completes in 30-60 seconds for a small AWS account.
4. **Open the Dashboard** to see the Cost / Performance / Security tabs populated with AI insights. Click any card to drill down into the raw JSON resource data.

The hourly EventBridge schedule keeps the data fresh in the background without any operator intervention.

**Figure 6 - Dashboard after a successful first scan, showing 4 KPI cards and per-project insights generated by Bedrock Claude 3 Haiku:**

![Dashboard Overview](/images/5-Workshop/5.4-Deployment-strategy/dashboard_overview.png)

---

## Section Summary

AI AWS Advisor's deployment strategy consists of four main phases: **(1)** deploying the backend with AWS SAM and recording the CloudFormation Outputs, **(2)** developing and testing the frontend application in a local environment, **(3)** integrating the customer's AWS account via the cross-account IAM Role mechanism, and **(4)** deploying the React application to production using Amazon S3 combined with CloudFront. The entire process can be reproduced from the source code in the repository via the `sam deploy --guided`, `npm run build`, and `aws s3 sync` command sequence, making deployment consistent, easy to maintain, and straightforward to integrate into DevOps pipelines.