<#
.SYNOPSIS
    Setup GitHub branch protection with pre-commit-tests as required check.
.NOTES
    Version: 1.0 (E2E)
#>
[CmdletBinding()]
param(
    [string]$Owner = '',
    [string]$Repo = '',
    [string]$Branch = 'develop'
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrEmpty($Owner) -or [string]::IsNullOrEmpty($Repo)) {
    $nwo = gh repo view --json nameWithOwner -q .nameWithOwner 2>$null
    if (-not $nwo) { Write-Error 'Cannot detect repo'; exit 4 }
    $slash = $nwo.IndexOf('/')
    $Owner = $nwo.Substring(0, $slash)
    $Repo = $nwo.Substring($slash + 1)
}
$payload = @{
    required_status_checks = @{
        strict = $true
        contexts = @('Tests / pre-commit-tests')
    }
    required_pull_request_reviews = @{
        dismiss_stale_reviews = $true
        required_approving_review_count = 1
    }
    restrictions = $null
    required_linear_history = $true
    allow_force_pushes = $false
    allow_deletions = $false
    enforce_admins = $false
} | ConvertTo-Json -Depth 10
$api = 'repos/' + $Owner + '/' + $Repo + '/branches/' + $Branch + '/protection'
$tmp = [System.IO.Path]::GetTempFileName()
try {
    [System.IO.File]::WriteAllText($tmp, $payload)
    gh api --method PUT $api --input $tmp
    Write-Host 'OK: branch protection applied'
} finally {
    Remove-Item $tmp -Force
}
