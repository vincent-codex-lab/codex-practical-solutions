[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$solutionsRoot = Join-Path $repoRoot 'solutions'
$script:failed = 0
$script:passed = 0

function Test-Check {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "PASS $Message" -ForegroundColor Green
        $script:passed++
    }
    else {
        Write-Host "FAIL $Message" -ForegroundColor Red
        $script:failed++
    }
}

Test-Check (Test-Path -LiteralPath (Join-Path $repoRoot 'README.md')) 'root README exists'
Test-Check (Test-Path -LiteralPath (Join-Path $repoRoot 'LICENSE')) 'license exists'
Test-Check (Test-Path -LiteralPath (Join-Path $repoRoot 'SECURITY.md')) 'security policy exists'

$required = @('README.md', 'PROMPT.md', 'TESTING.md', 'TEST-RESULTS.md', 'metadata.json')
$solutionDirs = Get-ChildItem -LiteralPath $solutionsRoot -Directory -ErrorAction SilentlyContinue

foreach ($dir in $solutionDirs) {
    Test-Check ($dir.Name -match '^\d{4}-\d{2}-\d{2}-[a-z0-9]+(?:-[a-z0-9]+)*$') "$($dir.Name) uses the required directory name"
    foreach ($name in $required) {
        Test-Check (Test-Path -LiteralPath (Join-Path $dir.FullName $name)) "$($dir.Name) contains $name"
    }

    $metadataPath = Join-Path $dir.FullName 'metadata.json'
    if (Test-Path -LiteralPath $metadataPath) {
        try {
            $metadata = [IO.File]::ReadAllText($metadataPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
            Test-Check ([bool]$metadata.title) "$($dir.Name) metadata has title"
            Test-Check ($metadata.date -match '^\d{4}-\d{2}-\d{2}$') "$($dir.Name) metadata has valid date"
            Test-Check ([bool]$metadata.category) "$($dir.Name) metadata has category"
            Test-Check ($metadata.tested -eq $true) "$($dir.Name) is marked tested"
        }
        catch {
            Test-Check $false "$($dir.Name) metadata is valid JSON"
        }
    }
}

$scanRoots = @((Join-Path $repoRoot 'solutions'), (Join-Path $repoRoot 'docs'))
$textFiles = foreach ($scanRoot in $scanRoots) {
    Get-ChildItem -LiteralPath $scanRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @('.md', '.txt', '.json', '.ps1', '.py', '.js', '.ts', '.yml', '.yaml') }
}

$secretPatterns = @(
    'github_pat_[A-Za-z0-9_]{20,}',
    'gh[pousr]_[A-Za-z0-9]{20,}',
    'sk-[A-Za-z0-9_-]{20,}',
    '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    '(?i)[A-Z]:\\Users\\[^\\\s]+\\',
    '/home/[^/\s]+/'
)

foreach ($file in $textFiles) {
    $content = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8)
    foreach ($pattern in $secretPatterns) {
        Test-Check (-not [regex]::IsMatch($content, $pattern)) "$($file.FullName.Substring($repoRoot.Length + 1)) passes sensitive-data pattern check"
    }
}

Write-Host "Summary: passed=$script:passed failed=$script:failed"
if ($script:failed -gt 0) { exit 1 }
exit 0
