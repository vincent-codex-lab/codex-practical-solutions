[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("codex-git-diff-test-" + [guid]::NewGuid().ToString('N'))
$script:passed = 0
$script:failed = 0

function Assert-Check {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { Write-Host "PASS $Name" -ForegroundColor Green; $script:passed++ }
    else { Write-Host "FAIL $Name" -ForegroundColor Red; $script:failed++ }
}

function Get-TreeFingerprint {
    param([string]$Path)
    $items = Get-ChildItem -LiteralPath $Path -Recurse -File | Sort-Object FullName
    return @($items | ForEach-Object {
        [pscustomobject]@{
            Relative = $_.FullName.Substring($Path.Length).TrimStart('\', '/')
            Hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    } | ConvertTo-Json -Compress)
}

$savedEnvironment = @{}
foreach ($name in @('GIT_CONFIG_NOSYSTEM', 'GIT_CONFIG_GLOBAL', 'GIT_TERMINAL_PROMPT', 'GIT_EXTERNAL_DIFF', 'HTTP_PROXY', 'HTTPS_PROXY')) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

try {
    $version = (& git --version 2>&1 | Out-String).Trim()
    Assert-Check ($LASTEXITCODE -eq 0 -and $version -match '^git version \d+\.\d+\.\d+') 'git version is available'

    $before = Join-Path $testRoot 'before'
    $after = Join-Path $testRoot 'after'
    $sameA = Join-Path $testRoot 'same-a'
    $sameB = Join-Path $testRoot 'same-b'
    New-Item -ItemType Directory -Path $before,$after,$sameA,$sameB | Out-Null

    Set-Content -LiteralPath (Join-Path $before 'unchanged.txt') -Value 'same'
    Set-Content -LiteralPath (Join-Path $after 'unchanged.txt') -Value 'same'
    Set-Content -LiteralPath (Join-Path $before 'changed.txt') -Value 'old line'
    Set-Content -LiteralPath (Join-Path $after 'changed.txt') -Value 'new line'
    Set-Content -LiteralPath (Join-Path $before 'removed.txt') -Value 'old only'
    Set-Content -LiteralPath (Join-Path $after 'added.txt') -Value 'new only'
    Set-Content -LiteralPath (Join-Path $before 'space name.txt') -Value 'old space'
    Set-Content -LiteralPath (Join-Path $after 'space name.txt') -Value 'new space'
    Set-Content -LiteralPath (Join-Path $before '中文文件.txt') -Value 'old unicode'
    Set-Content -LiteralPath (Join-Path $after '中文文件.txt') -Value 'new unicode'
    [IO.File]::WriteAllBytes((Join-Path $before 'sample.bin'), [byte[]](0,1,2,3,4))
    [IO.File]::WriteAllBytes((Join-Path $after 'sample.bin'), [byte[]](0,1,2,9,4))
    Set-Content -LiteralPath (Join-Path $sameA 'same.txt') -Value 'identical'
    Set-Content -LiteralPath (Join-Path $sameB 'same.txt') -Value 'identical'

    $beforeFingerprint = Get-TreeFingerprint -Path $before
    $afterFingerprint = Get-TreeFingerprint -Path $after

    $env:GIT_CONFIG_NOSYSTEM = '1'
    $env:GIT_CONFIG_GLOBAL = 'NUL'
    $env:GIT_TERMINAL_PROMPT = '0'
    $env:GIT_EXTERNAL_DIFF = 'this-command-must-not-run'

    Push-Location $testRoot
    try {
        $nameStatus = & git -c core.quotepath=false diff --no-index --no-ext-diff --no-renames --no-color --name-status -- before after 2>&1 | Out-String
        $differenceExit = $LASTEXITCODE
        Assert-Check ($differenceExit -eq 1) 'differences return exit code 1'
        Assert-Check ($nameStatus -match 'A\s+after/added\.txt') 'added file is reported'
        Assert-Check ($nameStatus -match 'M\s+before/changed\.txt') 'modified file is reported'
        Assert-Check ($nameStatus -match 'D\s+before/removed\.txt') 'deleted file is reported'
        Assert-Check ($nameStatus -notmatch 'unchanged\.txt') 'unchanged file is omitted'
        Assert-Check ($nameStatus -match 'space name\.txt') 'space in filename is handled'
        Assert-Check ($nameStatus -match '中文文件\.txt') 'unicode filename is handled'
        Assert-Check ($nameStatus -match 'sample\.bin') 'binary change is reported'
        Assert-Check ($nameStatus -notmatch [regex]::Escape($testRoot)) 'relative invocation hides absolute test path'

        $stat = & git -c core.quotepath=false diff --no-index --no-ext-diff --no-renames --no-color --stat -- before after 2>&1 | Out-String
        Assert-Check ($LASTEXITCODE -eq 1 -and $stat -match '6 files changed') 'stat reports changed file count'

        $identical = & git -c core.quotepath=false diff --no-index --no-ext-diff --no-renames --no-color --name-status -- same-a same-b 2>&1 | Out-String
        Assert-Check ($LASTEXITCODE -eq 0 -and [string]::IsNullOrWhiteSpace($identical)) 'identical directories return exit code 0'

        $detail = & git -c core.quotepath=false diff --no-index --no-ext-diff --no-renames --no-color -- 'before\changed.txt' 'after\changed.txt' 2>&1 | Out-String
        Assert-Check ($LASTEXITCODE -eq 1 -and $detail -match 'old line' -and $detail -match 'new line') 'explicit text detail shows line changes'

        $savedErrorPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $missing = & git -c core.quotepath=false diff --no-index --no-ext-diff --no-renames --no-color --name-status -- before missing-folder 2>&1 | Out-String
        $missingExit = $LASTEXITCODE
        $ErrorActionPreference = $savedErrorPreference
        Assert-Check ($missingExit -ne 0 -and $missing -match '(?i)error:.+missing-folder') 'missing path returns an explicit error message'

        $repeat = & git -c core.quotepath=false diff --no-index --no-ext-diff --no-renames --no-color --name-status -- before after 2>&1 | Out-String
        Assert-Check ($LASTEXITCODE -eq 1 -and $repeat -eq $nameStatus) 'repeat output is stable'

        $env:HTTP_PROXY = 'http://127.0.0.1:9'
        $env:HTTPS_PROXY = 'http://127.0.0.1:9'
        $offline = & git -c core.quotepath=false diff --no-index --no-ext-diff --no-renames --no-color --name-status -- before after 2>&1 | Out-String
        Assert-Check ($LASTEXITCODE -eq 1 -and $offline -eq $nameStatus) 'local comparison does not depend on network access'
    }
    finally { Pop-Location }

    Assert-Check ((Get-TreeFingerprint -Path $before) -eq $beforeFingerprint -and (Get-TreeFingerprint -Path $after) -eq $afterFingerprint) 'all compared file hashes stay unchanged'
    Assert-Check (-not (Test-Path -LiteralPath (Join-Path $testRoot '.git'))) 'no git repository is created'
}
finally {
    foreach ($name in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
    }
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}

Assert-Check (-not (Test-Path -LiteralPath $testRoot)) 'temporary test directory is removed'
Write-Host "Summary: passed=$script:passed failed=$script:failed"
if ($script:failed -gt 0) { exit 1 }
exit 0
