# Generates 5.3 high_level_architecture.png and dynamodb_multitable_design.png
# Replaces outdated Single-Table / 3-Lambda diagrams with the actual Multi-Table / 6-Lambda architecture.

[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null

function New-Diagram([int]$w, [int]$h, [string]$bg) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $g.Clear([System.Drawing.Color]::FromName($bg))
    return @{ Bmp = $bmp; G = $g }
}

function Draw-Box([System.Drawing.Graphics]$g, [int]$x, [int]$y, [int]$w, [int]$h, [string]$title, [string[]]$lines, [System.Drawing.Color]$border, [System.Drawing.Color]$fill, [System.Drawing.Color]$titleColor) {
    $brush = New-Object System.Drawing.SolidBrush $fill
    $g.FillRectangle($brush, $x, $y, $w, $h)
    $brush.Dispose()
    $pen = New-Object System.Drawing.Pen $border, 2
    $g.DrawRectangle($pen, $x, $y, $w, $h)
    $pen.Dispose()
    $titleFont = New-Object System.Drawing.Font "Segoe UI", 11, [System.Drawing.FontStyle]::Bold
    $bodyFont = New-Object System.Drawing.Font "Segoe UI", 9
    $titleBrush = New-Object System.Drawing.SolidBrush $titleColor
    $bodyBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(45, 52, 70))
    $g.DrawString($title, $titleFont, $titleBrush, ($x + 8), ($y + 6))
    $yy = $y + 28
    foreach ($ln in $lines) {
        $g.DrawString($ln, $bodyFont, $bodyBrush, ($x + 8), $yy)
        $yy += 16
    }
    $titleFont.Dispose(); $bodyFont.Dispose(); $titleBrush.Dispose(); $bodyBrush.Dispose()
}

function Draw-Arr([System.Drawing.Graphics]$g, [int]$x1, [int]$y1, [int]$x2, [int]$y2, [string]$label, [System.Drawing.Color]$color) {
    $pen = New-Object System.Drawing.Pen $color, 2
    $pen.CustomEndCap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap 5, 5
    $g.DrawLine($pen, $x1, $y1, $x2, $y2)
    $pen.Dispose()
    if ($label) {
        $font = New-Object System.Drawing.Font "Segoe UI", 8, [System.Drawing.FontStyle]::Italic
        $brush = New-Object System.Drawing.SolidBrush $color
        $g.DrawString($label, $font, $brush, ((($x1 + $x2) / 2) - 40), ((($y1 + $y2) / 2) - 14))
        $font.Dispose(); $brush.Dispose()
    }
}

function Draw-Title([System.Drawing.Graphics]$g, [string]$title, [string]$subtitle, [int]$w) {
    $titleFont = New-Object System.Drawing.Font "Segoe UI", 16, [System.Drawing.FontStyle]::Bold
    $subFont = New-Object System.Drawing.Font "Segoe UI", 10
    $titleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(30, 41, 59))
    $subBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(100, 116, 139))
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($title, $titleFont, $titleBrush, (New-Object System.Drawing.RectangleF 0, 10, $w, 28), $sf)
    $g.DrawString($subtitle, $subFont, $subBrush, (New-Object System.Drawing.RectangleF 0, 40, $w, 18), $sf)
    $titleFont.Dispose(); $subFont.Dispose(); $titleBrush.Dispose(); $subBrush.Dispose(); $sf.Dispose()
}

# ============================================================
# Diagram 1: high_level_architecture.png
# ============================================================
$w = 1400; $h = 820
$d = New-Diagram $w $h "WhiteSmoke"
$g = $d.G
Draw-Title $g "AI AWS Advisor - High-Level Architecture" "Serverless Multi-Tenant SaaS - 3 Security Boundaries - 6 Lambda - 4 DynamoDB Tables + 1 GSI" $w

# Column 1: Client Frontend
Draw-Box $g 40 90 280 230 "1. Client Frontend (React 19 SPA)" @(
    "Vite + Tailwind CSS + Radix UI"
    "Hosted on CloudFront + S3"
    "Auth: Amazon Cognito (JWT)"
    "State: TanStack React Query"
    "Charts: Recharts"
    "Pages: Dashboard, Projects, Cost,"
    "        Performance, Security, Copilot"
) ([System.Drawing.Color]::FromArgb(59, 130, 246)) ([System.Drawing.Color]::FromArgb(219, 234, 254)) ([System.Drawing.Color]::FromArgb(30, 64, 175))

# Column 2: SaaS Provider Backend
Draw-Box $g 380 90 480 580 "2. SaaS Provider Backend (Serverless)" @(
    "5 API Lambda Handlers (Cognito JWT-auth):"
    "  - projects.py    (CRUD projects)"
    "  - resources.py  (GET resources)"
    "  - insights.py   (GET insights)"
    "  - chat.py       (POST AI copilot)"
    "  - alerts.py     (GET alerts)"
    ""
    "1 Collector Lambda:"
    "  - collector/main.py (hourly scan)"
    ""
    "AI Layer: Amazon Bedrock"
    "  - Model: Claude 3 Haiku"
    "  - Region: us-east-1"
    ""
    "Amazon EventBridge Scheduler"
    "  - rate(1 hour)"
    ""
    "Amazon SNS Topic (ai-advisor-alerts)"
    "  - Email subscription for CRITICAL"
) ([System.Drawing.Color]::FromArgb(16, 185, 129)) ([System.Drawing.Color]::FromArgb(209, 250, 229)) ([System.Drawing.Color]::FromArgb(6, 95, 70))

# Column 2 - Data Layer
Draw-Box $g 380 690 480 110 "Data Layer - DynamoDB Multi-Table" @(
    "ai-advisor-projects  | ai-advisor-resources (GSI: resource_type-index)"
    "ai-advisor-insights  | ai-advisor-alerts"
    "All 4 tables share `project_id` PK for tenant isolation."
) ([System.Drawing.Color]::FromArgb(245, 158, 11)) ([System.Drawing.Color]::FromArgb(254, 243, 199)) ([System.Drawing.Color]::FromArgb(146, 64, 14))

# Column 3: Customer Target
Draw-Box $g 920 90 440 580 "3. Customer Target AWS Account" @(
    "Customer IAM Role (AIAdvisorAuditRole)"
    "  - Trust policy: SaaS Provider Acct ID"
    "  - ReadOnlyAccess (23 actions)"
    "  - ExternalId (optional)"
    ""
    "Resources scanned:"
    "  - EC2 (instances, volumes, SGs)"
    "  - S3 (buckets, public access, ACL)"
    "  - IAM (users, roles, policies)"
    "  - Lambda (functions, configs)"
    "  - CloudWatch (metrics, alarms)"
    ""
    "How the Collector reaches here:"
    "  1. AssumeRole(AuditRole, Duration=3600s)"
    "  2. boto3.Session with temp credentials"
    "  3. Read-only API calls"
    "  4. Auto-expire after 1 hour"
) ([System.Drawing.Color]::FromArgb(139, 92, 246)) ([System.Drawing.Color]::FromArgb(237, 233, 254)) ([System.Drawing.Color]::FromArgb(76, 29, 149))

# Boundary labels
$brFont = New-Object System.Drawing.Font "Segoe UI", 9, [System.Drawing.FontStyle]::Bold
$brBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(100, 116, 139))
$g.DrawString("Boundary 1: Client", $brFont, $brBrush, 40, 330)
$g.DrawString("Boundary 2: Provider Backend", $brFont, $brBrush, 380, 805)
$g.DrawString("Boundary 3: Customer Account", $brFont, $brBrush, 920, 680)
$brFont.Dispose(); $brBrush.Dispose()

# Arrows
Draw-Arr $g 320 180 380 180 "JWT auth" ([System.Drawing.Color]::FromArgb(59, 130, 246))
Draw-Arr $g 860 230 920 230 "AssumeRole" ([System.Drawing.Color]::FromArgb(139, 92, 246))
Draw-Arr $g 920 290 860 290 "Resources" ([System.Drawing.Color]::FromArgb(139, 92, 246))

# Save
$out1 = "D:\nhatpm\fcj-workshop\static\images\5.3-Architecture-design\high_level_architecture.png"
$bmp = $d.Bmp
$bmp.Save($out1, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "Saved: $out1"

# ============================================================
# Diagram 2: dynamodb_multitable_design.png
# ============================================================
$w = 1400; $h = 720
$d = New-Diagram $w $h "WhiteSmoke"
$g = $d.G
Draw-Title $g "DynamoDB Multi-Table Design (4 Tables + 1 GSI)" "All tables share `project_id` Partition Key for strict tenant isolation - production layout" $w

# Tenant isolation note
$noteFont = New-Object System.Drawing.Font "Segoe UI", 9, [System.Drawing.FontStyle]::Italic
$noteBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(146, 64, 14))
$g.DrawString("Tenant isolation: every row in every table is keyed by `project_id` so a single Query Scan never crosses projects.", $noteFont, $noteBrush, 40, 60)
$noteFont.Dispose(); $noteBrush.Dispose()

# Table 1: projects
Draw-Box $g 40 110 300 200 "1. ai-advisor-projects" @(
    "Partition Key: project_id (S)"
    "Sort Key: sk (S)"
    "Billing: PAY_PER_REQUEST"
    ""
    "Holds:"
    "  - project_id"
    "  - project_name"
    "  - role_arn (customer IAM)"
    "  - region"
    "  - owner (sub from Cognito)"
    "  - disconnected (boolean)"
) ([System.Drawing.Color]::FromArgb(59, 130, 246)) ([System.Drawing.Color]::FromArgb(219, 234, 254)) ([System.Drawing.Color]::FromArgb(30, 64, 175))

# Table 2: resources
Draw-Box $g 360 110 360 280 "2. ai-advisor-resources" @(
    "Partition Key: project_id (S)"
    "Sort Key: resource_id (S)"
    ""
    "GSI: resource_type-index"
    "  PK: resource_type (S)"
    "  SK: collected_at (S)"
    "  Projection: ALL"
    ""
    "Holds raw scanned resources:"
    "  - EC2 instance"
    "  - S3 bucket"
    "  - IAM user/role"
    "  - Lambda function"
    "  - CloudWatch metric"
    ""
    "The GSI enables cross-project"
    "queries by resource type."
) ([System.Drawing.Color]::FromArgb(16, 185, 129)) ([System.Drawing.Color]::FromArgb(209, 250, 229)) ([System.Drawing.Color]::FromArgb(6, 95, 70))

# Table 3: insights
Draw-Box $g 740 110 300 230 "3. ai-advisor-insights" @(
    "Partition Key: project_id (S)"
    "Sort Key: insight_id (S)"
    ""
    "Holds AI-generated findings:"
    "  - severity (CRITICAL/HIGH/MED/LOW)"
    "  - category (SECURITY/COST/PERF)"
    "  - title, description"
    "  - recommendation"
    "  - created_at"
    ""
    "Written by ai_analyzer after"
    "Bedrock returns structured JSON."
) ([System.Drawing.Color]::FromArgb(245, 158, 11)) ([System.Drawing.Color]::FromArgb(254, 243, 199)) ([System.Drawing.Color]::FromArgb(146, 64, 14))

# Table 4: alerts
Draw-Box $g 1060 110 300 200 "4. ai-advisor-alerts" @(
    "Partition Key: project_id (S)"
    "Sort Key: alert_id (S)"
    ""
    "Holds:"
    "  - severity = CRITICAL subset"
    "  - insight_id (FK link)"
    "  - email_sent (boolean)"
    "  - sent_at"
    ""
    "Written when the Alert"
    "Handler publishes SNS email."
) ([System.Drawing.Color]::FromArgb(239, 68, 68)) ([System.Drawing.Color]::FromArgb(254, 226, 226)) ([System.Drawing.Color]::FromArgb(153, 27, 27))

# Relationship arrows
Draw-Arr $g 340 200 360 200 "1:N" ([System.Drawing.Color]::FromArgb(100, 116, 139))
Draw-Arr $g 720 200 740 200 "1:N" ([System.Drawing.Color]::FromArgb(100, 116, 139))
Draw-Arr $g 1040 200 1060 200 "1:N" ([System.Drawing.Color]::FromArgb(100, 116, 139))

# Bottom row: cross-project query example
Draw-Box $g 40 430 1320 230 "Cross-Project Query via resource_type-index GSI" @(
    "Example: dashboard asks 'show me every S3 bucket across all projects.'"
    "  - Base table: would require full Scan of ai-advisor-resources (expensive)."
    "  - With GSI: a single Query on resource_type-index with"
    "              KeyConditionExpression = `resource_type = :t` (efficient)."
    ""
    "Trade-off: each resource write is duplicated (base table + GSI) - acceptable"
    "           at PAY_PER_REQUEST with low resource volume per project."
    ""
    "Other access patterns:"
    "  - 'all resources of project X'    -> Query on base table PK=project_id"
    "  - 'all insights of project X'     -> Query on ai-advisor-insights PK=project_id"
    "  - 'all alerts of project X'       -> Query on ai-advisor-alerts PK=project_id"
    "  - 'all critical insights globally' -> Scan with FilterExpression (rare path)"
) ([System.Drawing.Color]::FromArgb(99, 102, 241)) ([System.Drawing.Color]::FromArgb(224, 231, 255)) ([System.Drawing.Color]::FromArgb(55, 48, 163))

# Save
$out2 = "D:\nhatpm\fcj-workshop\static\images\5.3-Architecture-design\dynamodb_singletable_design.png"
$bmp = $d.Bmp
$bmp.Save($out2, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "Saved: $out2"

Write-Host "Done. Generated 2 PNG diagrams."
