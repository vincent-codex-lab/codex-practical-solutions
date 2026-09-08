[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$solutionRoot = Split-Path -Parent $PSScriptRoot
$tool = Join-Path $solutionRoot 'Audit-ZipPrivacy.ps1'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('codex-zip-audit-' + [guid]::NewGuid().ToString('N'))
$script:passed = 0
$script:failed = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { Write-Host "PASS $Name" -ForegroundColor Green; $script:passed++ }
    else { Write-Host "FAIL $Name" -ForegroundColor Red; $script:failed++ }
}

function New-TestZip {
    param([string]$Name, [hashtable]$Files)
    $source = Join-Path $tempRoot ($Name + '-source')
    $zip = Join-Path $tempRoot ($Name + '.zip')
    New-Item -ItemType Directory -Path $source -Force | Out-Null
    foreach ($relative in $Files.Keys) {
        $path = Join-Path $source $relative
        $parent = Split-Path -Parent $path
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        [IO.File]::WriteAllText($path, [string]$Files[$relative], (New-Object Text.UTF8Encoding($false)))
    }
    Compress-Archive -Path (Join-Path $source '*') -DestinationPath $zip -Force
    return $zip
}

function Invoke-Audit {
    param([string]$Zip, [string[]]$ExtraArgs = @())
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -ZipPath $Zip @ExtraArgs 2>&1 | Out-String
    [pscustomobject]@{ Code=$LASTEXITCODE; Text=$output.Trim(); Json=($output | ConvertFrom-Json) }
}

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $cleanZip = New-TestZip 'clean' @{ 'README.md'='A harmless example.'; 'data/sample.json'='{ "name": "demo" }' }
    $clean = Invoke-Audit $cleanZip
    Assert-True ($clean.Code -eq 0) 'clean ZIP returns success'
    Assert-True ($clean.Json.status -eq 'Safe') 'clean ZIP is marked Safe'
    Assert-True ($clean.Json.findings_count -eq 0) 'clean ZIP has no findings'

    $fakeKey = 'sk-' + ('A' * 28)
    $fakeMail = 'person' + '@' + 'example.invalid'
    $fakeUser = 'Sample' + 'User'
    $drive = 'C:'
    $usersFolder = 'Users'
    $sensitiveText = "api_key=$fakeKey`nemail=$fakeMail`npath=$drive\$usersFolder\$fakeUser\project\file.txt"
    $sensitiveZip = New-TestZip 'sensitive' @{ 'config.txt'=$sensitiveText }
    $sensitive = Invoke-Audit $sensitiveZip
    $rules = @($sensitive.Json.findings | ForEach-Object rule)
    Assert-True ($sensitive.Code -eq 10) 'sensitive ZIP requires review'
    Assert-True ($rules -contains 'OpenAIKey') 'API key pattern is detected'
    Assert-True ($rules -contains 'EmailAddress') 'email pattern is detected'
    Assert-True ($rules -contains 'WindowsUserPath') 'personal path pattern is detected'
    Assert-True (-not $sensitive.Text.Contains($fakeKey)) 'report does not expose matched key'
    Assert-True (-not $sensitive.Text.Contains($fakeMail)) 'report does not expose matched email'
    Assert-True (-not $sensitive.Text.Contains($fakeUser)) 'report does not expose matched user name'

    $nameZip = New-TestZip 'filename' @{ '.env'='MODE=demo' }
    $nameResult = Invoke-Audit $nameZip
    Assert-True (@($nameResult.Json.findings | ForEach-Object rule) -contains 'SensitiveFileName') 'sensitive filename is detected'

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $traversalZip = Join-Path $tempRoot 'traversal.zip'
    $archive = [IO.Compression.ZipFile]::Open($traversalZip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $entry = $archive.CreateEntry('../secret.txt')
        $writer = New-Object IO.StreamWriter($entry.Open())
        try { $writer.Write('example') } finally { $writer.Dispose() }
    }
    finally { $archive.Dispose() }
    $traversal = Invoke-Audit $traversalZip
    Assert-True (@($traversal.Json.findings | ForEach-Object rule) -contains 'ArchiveTraversal') 'unsafe archive path is detected'

    $repeat = Invoke-Audit $cleanZip
    Assert-True ($repeat.Text -eq $clean.Text) 'repeated scan is deterministic'

    $reportPath = Join-Path $tempRoot 'reports\result.json'
    $withReport = Invoke-Audit $cleanZip @('-ReportPath', $reportPath)
    Assert-True (Test-Path -LiteralPath $reportPath) 'optional report file is created'
    Assert-True ((Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json).status -eq 'Safe') 'saved report is valid JSON'

    $invalid = Join-Path $tempRoot 'invalid.zip'
    [IO.File]::WriteAllText($invalid, 'not a zip archive')
    $invalidResult = Invoke-Audit $invalid
    Assert-True ($invalidResult.Code -eq 2) 'invalid ZIP fails safely'
    Assert-True ($invalidResult.Json.status -eq 'Error') 'invalid ZIP returns structured error'

    $largeZip = New-TestZip 'large' @{ 'large.txt'=('x' * 4096) }
    $large = Invoke-Audit $largeZip @('-MaxEntryBytes', '1024')
    Assert-True (@($large.Json.findings | ForEach-Object rule) -contains 'ContentNotScanned') 'oversized text is reported instead of silently skipped'

    Write-Host "Summary: passed=$script:passed failed=$script:failed"
    if ($script:failed -gt 0) { exit 1 }
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
