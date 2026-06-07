<#
.SYNOPSIS
    Setup GitHub develop branch protection with pre-commit-tests as required check.

.DESCRIPTION
    Uses GitHub REST API to configure develop branch protection:
      1. Enable branch protection
      2. Require 1+ PR review
      3. Set "Tests / pre-commit-tests" as required status check (core goal)
      4. Block merge if tests fail

    Required check name format: "<workflow_name> / <job_id>"
    Current job: pre-commit-tests (id = name, kept stable)
    Full path: "Tests / pre-commit-tests"

    Prerequisites:
      1. GitHub CLI (gh) >= 2.0 installed
      2. Authenticated via 'gh auth login' with admin permission
      3. Current dir is a Git repo with remote configured

.PARAMETER Owner
    GitHub owner (user or org). Auto-detected from gh if empty.

.PARAMETER Repo
    GitHub repo name. Auto-detected from gh if empty.

.PARAMETER Branch
    Branch to protect. Default 'develop'.

.EXAMPLE
    .\setup_branch_protection.ps1

.EXAMPLE
    .\setup_branch_protection.ps1 -Owner myorg -Repo myrepo -Branch develop

.NOTES
    Author:  VBE Team
    Date:    2026-06-06
    Version: 1.0
    See:     https://docs.github.com/en/rest/branches/branch-protection
#>

[CmdletBinding()]
param(
    [string]$Owner = '',
    [string]$Repo = '',
    [string]$Branch = 'develop',
    [switch]$AutoConfirm = $false
)

$ErrorActionPreference = 'Stop'
$TAG_INFO  = 'INFO'
$TAG_OK    = 'OK'
$TAG_WARN  = 'WARN'
$TAG_ERROR = 'ERROR'

function Write-Info {
    param([string]$Msg)
    Write-Host ('[' + $TAG_INFO + '] ' + $Msg) -ForegroundColor Cyan
}
function Write-Ok {
    param([string]$Msg)
    Write-Host ('[' + $TAG_OK + '] ' + $Msg) -ForegroundColor Green
}
function Write-Warn {
    param([string]$Msg)
    Write-Host ('[' + $TAG_WARN + '] ' + $Msg) -ForegroundColor Yellow
}
function Write-Err {
    param([string]$Msg)
    Write-Host ('[' + $TAG_ERROR + '] ' + $Msg) -ForegroundColor Red
}

function Get-Line {
    param([int]$N)
    return '=' * $N
}

Write-Host (Get-Line 78) -ForegroundColor Cyan
Write-Host '  GitHub Branch Protection Setup' -ForegroundColor Cyan
Write-Host (Get-Line 78) -ForegroundColor Cyan
Write-Host ''

# 1. Check gh CLI
$ghPath = Get-Command gh -ErrorAction SilentlyContinue
if (-not $ghPath) {
    Write-Err 'gh CLI not found, install via: winget install --id GitHub.cli'
    exit 2
}
Write-Info ('[1/5] GitHub CLI: ' + $ghPath.Version)

# 2. Check auth
gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Err 'gh CLI not authenticated, run: gh auth login'
    exit 3
}
Write-Info '[2/5] GitHub auth: logged in'

# 3. Detect owner/repo
if ([string]::IsNullOrEmpty($Owner) -or [string]::IsNullOrEmpty($Repo)) {
    $repoJson = gh repo view --json nameWithOwner 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err 'Cannot auto-detect repo, specify -Owner / -Repo'
        exit 4
    }
    $nwo = ($repoJson | ConvertFrom-Json).nameWithOwner
    $slash = $nwo.IndexOf('/')
    $Owner = $nwo.Substring(0, $slash)
    $Repo = $nwo.Substring($slash + 1)
}
Write-Info ('[3/5] Target repo: ' + $Owner + '/' + $Repo)

# 4. Check branch exists
$apiBranch = 'repos/' + $Owner + '/' + $Repo + '/branches/' + $Branch
gh api $apiBranch | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Warn ('Branch ' + $Branch + ' may not exist or is inaccessible')
    if ($AutoConfirm) {
        Write-Warn '-AutoConfirm specified, continuing'
    } else {
        $ans = Read-Host '  Continue? (y/N)'
        if ($ans -ne 'y') { exit 5 }
    }
}
Write-Info ('[4/5] Target branch: ' + $Branch)

# 5. Check admin permission
$apiRepo = 'repos/' + $Owner + '/' + $Repo
$permsJson = gh api $apiRepo --jq '.permissions' 2>&1
$perms = $permsJson | ConvertFrom-Json
if (-not $perms.admin) {
    Write-Err 'Current user lacks admin permission on this repo'
    exit 6
}
Write-Info '[5/5] Permission: admin (verified)'

Write-Host ''
Write-Host (Get-Line 78) -ForegroundColor Cyan
Write-Host '  Configuration Preview' -ForegroundColor Cyan
Write-Host (Get-Line 78) -ForegroundColor Cyan
Write-Host ''
Write-Host ('  Branch:              ' + $Branch)
Write-Host '  Required Check:      Tests / pre-commit-tests'
Write-Host '  Block failing tests: enabled'
Write-Host '  Required reviews:    1'
Write-Host '  Linear history:      required'
Write-Host '  Allow force push:    no'
Write-Host '  Allow deletion:      no'
Write-Host ''

# Build JSON via here-string (avoids nested hashtable parsing issues)
$jsonTemplate = @'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Tests / pre-commit-tests"]
  },
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "require_last_push_approval": false
  },
  "required_signatures": false,
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "enforce_admins": false,
  "enabled": true
}
'@

# User confirm
if ($AutoConfirm) {
    $confirm = 'y'
    Write-Info '-AutoConfirm specified, applying configuration'
} else {
    $confirm = Read-Host '  Apply configuration? (y/N)'
}
if ($confirm -ne 'y') {
    Write-Info 'Cancelled'
    exit 0
}

Write-Host ''
Write-Host (Get-Line 78) -ForegroundColor Cyan
Write-Host '  Applying' -ForegroundColor Cyan
Write-Host (Get-Line 78) -ForegroundColor Cyan
Write-Host ''

$apiEndpoint = 'repos/' + $Owner + '/' + $Repo + '/branches/' + $Branch + '/protection'
$tempFile = [System.IO.Path]::GetTempFileName()
try {
    # Write UTF-8 without BOM (GitHub API requires strict JSON)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tempFile, $jsonTemplate, $utf8NoBom)

    $response = gh api --method PUT $apiEndpoint --input $tempFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err ('Failed: ' + $response)
        exit 7
    }

    $result = $response | ConvertFrom-Json
    Write-Ok 'Branch protection rules applied'
    Write-Host ''
    Write-Host ('  URL:                  ' + $result.url)
    Write-Host ('  Strict:               ' + $result.required_status_checks.strict)
    $contexts = $result.required_status_checks.contexts -join ', '
    Write-Host ('  Contexts:             ' + $contexts)
    Write-Host ('  Enforce Admins:       ' + $result.enforce_admins)
    Write-Host ''

    Write-Host (Get-Line 78) -ForegroundColor Cyan
    Write-Host '  Current Protection Rules' -ForegroundColor Cyan
    Write-Host (Get-Line 78) -ForegroundColor Cyan
    Write-Host ''
    gh api $apiEndpoint | ConvertFrom-Json | Format-List

    Write-Host ''
    Write-Host (Get-Line 78) -ForegroundColor Green
    Write-Ok 'Configuration complete'
    Write-Host (Get-Line 78) -ForegroundColor Green
    Write-Host ''
    Write-Host '  Effect:' -ForegroundColor Cyan
    Write-Host '    1. PRs trigger Tests / pre-commit-tests automatically'
    Write-Host '    2. Test failure blocks PR merge'
    Write-Host '    3. 1+ reviewer approval required'
    Write-Host '    4. Linear history enforced (rebase / squash merge)'
    Write-Host '    5. Force push and branch deletion blocked'
    Write-Host ''
    Write-Host '  Verify:' -ForegroundColor Cyan
    Write-Host ('    gh api repos/' + $Owner + '/' + $Repo + '/branches/' + $Branch + '/protection')
    Write-Host ''
}
finally {
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force
    }
}
