---
title: "Prerequisites & Setup"
date: 2026-05-01
weight: 2
chapter: false
pre: " <b> 5.2. </b> "
---

# Section 5.2 - System Requirements & Prerequisites

To deploy, operate, and contribute to **AI AWS Advisor**, ensure your local development machine and AWS accounts meet the following requirements.

---

## 1. AWS Account & Service Entitlements

- **AWS Account:** Requires Administrator Access privileges (`AdministratorAccess`).
- **Amazon Bedrock Model Access:**
  - `Claude 3 Haiku` model access must be explicitly enabled in `us-east-1` or `ap-southeast-1` via the AWS Bedrock Console (**Bedrock -> Model access -> Request access**).
  - Target Model ID / ARN: `anthropic.claude-3-haiku-20240307-v1:0`.
  - **Important for Anthropic models:** Bedrock requires you to submit a one-time **Use Case form** (Company, Website, Industry, Use case description) via the Chat/Text Playground before the first invocation. After Anthropic reviews the form (typically within 24 hours), the model becomes invokable. If you see the message *"Your account is not authorized to perform this action"*, that is exactly what this form is for.
  - **Alternative (no approval needed):** Swap the model ID in `template.yaml` to `amazon.nova-lite-v1:0` — Amazon's first-party models do not require Anthropic's manual approval step.
- **AWS CLI v2:** Installed and configured (`aws configure`) with valid credentials.

**Figure - `aws configure` interactive prompts and `aws sts get-caller-identity` verification output:**

<img src="/aws-ojt-workshop-ja/images/5.2-Prerequiste/aws_cli_configure.png?v=2026-08-01-r1" alt="PowerShell 7 terminal showing aws configure prompts for AWS Access Key ID, AWS Secret Access Key, Default region name (us-east-1), Default output format (json), followed by aws sts get-caller-identity returning a JSON payload with UserId, Account, and Arn fields confirming the IAM credentials are valid" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

**Figure 1 - Amazon Bedrock Model Access page — all Anthropic Claude 3 family models granted (Access granted status verified in `us-east-1`):**

<img src="/aws-ojt-workshop-ja/images/5.2-Prerequiste/bedrock_model_access.jpg?v=2026-08-01-r3" alt="Amazon Bedrock Model Access page showing all Anthropic Claude 3 family models (3.5 Sonnet v2, 3.5 Sonnet, 3 Opus, 3 Sonnet, 3 Haiku) with green Access granted status in us-east-1 region" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

> **Verification note:** This screenshot was captured from the workshop author's AWS account on the date this workshop was published. If your console shows *"Not available"* or *"Access denied"* for any Anthropic model, open the Bedrock Chat/Text Playground once and submit the one-time **Use Case form** (Company name, Website, Industry, Audience, Use case description). Anthropic typically approves the request within 24 hours. Alternatively, you can swap the model ID in `template.yaml` to `amazon.nova-lite-v1:0`, which does not require Anthropic's manual approval step.

---

## 2. Toolchain Verification

Before starting deployment, run the commands below in PowerShell / Terminal and confirm the output matches the recommended versions:

**Figure 2 - Toolchain verification: `aws / sam / python / node / docker` versions:**

<img src="/aws-ojt-workshop-ja/images/5.2-Prerequiste/toolchain_check.png?v=2026-08-01-r1" alt="PowerShell 7 terminal showing version checks for AWS CLI (2.17.10), SAM CLI (1.124.0), Python (3.12.6), Node.js (20.15.0), Docker (27.0.3), and aws sts get-caller-identity returning the workshop author's IAM user ARN" width="700" style="max-width:700px;width:100%;height:auto;display:block;margin:0 auto;">

```bash
# Check toolchain versions
aws --version
sam --version
python --version
node --version
docker --version
```

If any command returns *"command not found"*, install the missing tool before continuing:
- **AWS CLI:** Download from [AWS CLI v2 installer](https://awscli.amazonaws.com/AWSCLIV2.msi).
- **AWS SAM CLI:** `pip install aws-sam-cli` or download from [AWS SAM CLI releases](https://github.com/aws/aws-sam-cli/releases).
- **Docker Desktop:** Install from [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/) (requires WSL 2 backend).
- **Python:** From [python.org](https://www.python.org/downloads/) (tick **"Add to PATH"** during installation).
- **Node.js:** From [nodejs.org](https://nodejs.org/) (recommended LTS 20.x).

---

## 3. Serverless Backend Toolchain

- **AWS SAM CLI:** Used to build, package, and deploy the serverless infrastructure (`template.yaml`).
- **Python 3.12+:** Primary runtime language for Lambda API Handlers and AI Analyzers.
- **Docker Desktop:** Required by SAM CLI (`sam build --use-container`) to compile dependencies inside Amazon Linux 2023 container environments.

---

## 4. Frontend & Local Emulation Toolchain

- **Node.js (v20.0 or higher):** Runtime for React 19 / Vite 8 development. (Vite 8 requires Node 20+; older Node 18 will fail to install dependencies.)
- **npm / pnpm / yarn:** JavaScript package manager.
- **DynamoDB Local:** Supported via Docker Compose (`amazon/dynamodb-local`) for offline development without modifying cloud databases.

Refer back to **§2 Toolchain Verification** above — the same commands (`aws --version`, `sam --version`, `python --version`, `node --version`, `docker --version`) confirm all the tools listed in this section.

---

## 5. Python Backend Dependencies

The backend declares all Python packages in `backend/requirements.txt`. The most important third-party libraries are:

| Library | Purpose |
|---|---|
| `boto3` | AWS SDK for Python (DynamoDB, Bedrock, STS, EC2, S3, IAM, CloudWatch) |
| `aws-lambda-powertools` | Structured logging, custom metrics, distributed tracing |
| `pydantic` | Runtime data validation for JSON payloads |
| `botocore` | Low-level AWS SDK (bundled with `boto3`) — required for `STS`, `bedrock-runtime` clients |

{{% notice warning %}}
**Never commit `requirements-dev.txt` secrets** to public Git. The file `env.json` (used by SAM `--parameter-overrides`) contains the alert email and may carry Bedrock region overrides — treat it as configuration, not source code.
{{% /notice %}}

---

## 6. AWS Cognito User Pool Provisioning

AI AWS Advisor uses **Amazon Cognito** as the identity provider. The SAM template (`template.yaml`) automatically creates:

- A **User Pool** (`ai-advisor-user-pool`) with `email` as the username attribute and email auto-verification enabled.
- A **User Pool Client** (`ai-advisor-web-client`) with public OAuth flows (`ALLOW_USER_SRP_AUTH`, `ALLOW_USER_PASSWORD_AUTH`, `ALLOW_REFRESH_TOKEN_AUTH`).

After deployment, retrieve the two identifiers from CloudFormation outputs:

```bash
aws cloudformation describe-stacks \
  --stack-name ai-aws-advisor \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId` || OutputKey==`UserPoolClientId`].OutputValue'
```

Create at least one Cognito user so the React dashboard can sign in:

```bash
aws cognito-idp admin-create-user \
  --user-pool-id <UserPoolId> \
  --username admin@example.com \
  --user-attributes Name=email,Value=admin@example.com Name=email_verified,Value=true \
  --temporary-password "ChangeMe123!" \
  --message-action SUPPRESS
```

The user must change the temporary password on first login.

---

## 7. DynamoDB Local (Offline Development)

For local development without touching the cloud database, spin up **DynamoDB Local** in Docker:

```bash
docker run -d --name dynamodb-local \
  -p 8000:8000 \
  amazon/dynamodb-local:latest \
  -jar DynamoDBLocal.jar -inMemory -sharedDb
```

Then point the Lambda environment to it by overriding `DYNAMODB_ENDPOINT_URL`:

```bash
DYNAMODB_ENDPOINT_URL=http://localhost:8000 \
  AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy AWS_DEFAULT_REGION=us-east-1 \
  sam local start-api --env-vars env.json
```

{{% notice info %}}
**Production must set `DYNAMODB_ENDPOINT_URL=""`** (empty string). The SAM template defaults it to empty, so deployed Lambdas talk to real DynamoDB.
{{% /notice %}}

---

## Section Summary

After completing the steps above, you have:
- A confirmed AWS Administrator account with Bedrock model access (or Nova Lite alternative).
- A verified Python/Node/Docker/SAM local toolchain.
- A provisioned Cognito User Pool + Client (after first `sam deploy`).
- An optional DynamoDB Local container for offline iteration.