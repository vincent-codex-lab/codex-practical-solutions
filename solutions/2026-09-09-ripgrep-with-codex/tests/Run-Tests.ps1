[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script:passed = 0
$script:failed = 0
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('codex-rg-test-' + [guid]::NewGuid().ToString('N'))
$rgCommand = Get-Command rg -ErrorAction Stop
$rg = $rgCommand.Source

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { Write-Host "PASS $Name" -ForegroundColor Green; $script:passed++ }
    else { Write-Host "FAIL $Name" -ForegroundColor Red; $script:failed++ }
}

function Invoke-Rg {
    param([string[]]$Arguments)
    $lines = @(& $rg @Arguments 2>&1 | ForEach-Object { $_.ToString() })
    [pscustomobject]@{ Code = $LASTEXITCODE; Lines = $lines; Text = ($lines -join "`n") }
}

function Write-Utf8 {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding($false)))
}

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    Write-Utf8 (Join-Path $tempRoot '.gitignore') "ignored/`n"
    Write-Utf8 (Join-Path $tempRoot 'src/app.ps1') "Write-Host 'AlphaMarker'`n# TODO: sample task`n"
    Write-Utf8 (Join-Path $tempRoot 'src/helper.py') "message = 'beta-marker'`n"
    Write-Utf8 (Join-Path $tempRoot 'file with spaces.txt') "space-marker`n"
    Write-Utf8 (Join-Path $tempRoot '.hidden/secret.txt') "secret-marker`n"
    Write-Utf8 (Join-Path $tempRoot 'ignored/cache.txt') "ignored-marker`n"
    [IO.File]::WriteAllBytes((Join-Path $tempRoot 'src/sample.bin'), [byte[]](65,0,66,98,105,110,97,114,121,45,109,97,114,107,101,114))
    & git -C $tempRoot init --quiet 2>$null

    $fixtureFiles = Get-ChildItem -LiteralPath $tempRoot -Recurse -File -Force | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
    $before = @{}
    foreach ($file in $fixtureFiles) { $before[$file.FullName] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }

    Push-Location $tempRoot
    try {
        $version = Invoke-Rg @('--version')
        Assert-True ($version.Code -eq 0 -and $version.Text -match '^ripgrep \d+') 'version command succeeds'

        $literal = Invoke-Rg @('-n', '-F', 'AlphaMarker', '.')
        Assert-True ($literal.Code -eq 0 -and $literal.Text -match 'app\.ps1') 'literal search finds expected file'

        $regex = Invoke-Rg @('-n', 'TODO|beta-marker', '.')
        Assert-True ($regex.Code -eq 0 -and $regex.Text -match 'app\.ps1' -and $regex.Text -match 'helper\.py') 'regex search finds both files'

        $case = Invoke-Rg @('-n', '-i', 'alphamarker', '.')
        Assert-True ($case.Code -eq 0 -and $case.Text -match 'AlphaMarker') 'case insensitive search works'

        $files = Invoke-Rg @('--files', '.')
        Assert-True ($files.Code -eq 0 -and $files.Text -notmatch 'ignored[\\/]cache\.txt') 'gitignore is respected'

        $hiddenDefault = Invoke-Rg @('-n', 'secret-marker', '.')
        Assert-True ($hiddenDefault.Code -eq 1 -and -not $hiddenDefault.Text) 'hidden files are skipped by default'

        $hiddenExplicit = Invoke-Rg @('-n', '--hidden', '--glob', '!.git/**', 'secret-marker', '.')
        Assert-True ($hiddenExplicit.Code -eq 0 -and $hiddenExplicit.Text -match 'secret\.txt') 'hidden files can be explicitly included'

        $binary = Invoke-Rg @('-n', 'binary-marker', '.')
        Assert-True ($binary.Code -eq 1 -and -not $binary.Text) 'binary file is skipped as normal text'

        $json = Invoke-Rg @('--json', 'beta-marker', '.')
        $jsonValid = $true
        try { $events = @($json.Lines | ForEach-Object { $_ | ConvertFrom-Json }) } catch { $jsonValid = $false; $events = @() }
        Assert-True ($json.Code -eq 0 -and $jsonValid -and @($events | Where-Object type -eq 'match').Count -eq 1) 'JSON output is valid and includes a match'

        $spaces = Invoke-Rg @('-n', 'space-marker', '.')
        Assert-True ($spaces.Code -eq 0 -and $spaces.Text -match 'file with spaces\.txt') 'file names with spaces are handled'

        $none = Invoke-Rg @('-n', 'definitely-not-present', '.')
        Assert-True ($none.Code -eq 1 -and -not $none.Text) 'no match returns exit code one'

        $repeat = Invoke-Rg @('-n', '-F', 'AlphaMarker', '.')
        Assert-True ($repeat.Code -eq $literal.Code -and $repeat.Text -eq $literal.Text) 'repeated search is deterministic'
    }
    finally { Pop-Location }

    $unchanged = $true
    foreach ($path in $before.Keys) {
        if (-not (Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $before[$path]) { $unchanged = $false }
    }
    Assert-True $unchanged 'search leaves fixture files unchanged'

    Write-Host "Summary: passed=$script:passed failed=$script:failed"
    if ($script:failed -gt 0) { exit 1 }
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
