[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$solutionRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $solutionRoot 'Sort-DownloadsSafely.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("codex-organizer-test-" + [guid]::NewGuid().ToString('N'))
$script:passed = 0
$script:failed = 0

function Assert-Check {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { Write-Host "PASS $Name" -ForegroundColor Green; $script:passed++ }
    else { Write-Host "FAIL $Name" -ForegroundColor Red; $script:failed++ }
}

try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    Set-Content -LiteralPath (Join-Path $testRoot 'photo.JPG') -Value 'image'
    Set-Content -LiteralPath (Join-Path $testRoot 'clip.mp4') -Value 'video'
    Set-Content -LiteralPath (Join-Path $testRoot 'notes.txt') -Value 'text'
    Set-Content -LiteralPath (Join-Path $testRoot 'bundle.zip') -Value 'zip'
    Set-Content -LiteralPath (Join-Path $testRoot 'setup.msi') -Value 'installer'
    Set-Content -LiteralPath (Join-Path $testRoot 'unknown.bin') -Value 'other'
    New-Item -ItemType Directory -Path (Join-Path $testRoot 'nested') | Out-Null
    Set-Content -LiteralPath (Join-Path $testRoot 'nested\keep.mp3') -Value 'nested'
    New-Item -ItemType Directory -Path (Join-Path $testRoot '图片') | Out-Null
    Set-Content -LiteralPath (Join-Path $testRoot '图片\photo.JPG') -Value 'existing'

    $before = @(Get-ChildItem -LiteralPath $testRoot -Recurse -File).Count
    $preview = & $scriptPath -Path $testRoot 2>&1 | Out-String
    Assert-Check ($preview -match '未修改任何内容') 'preview reports no changes'
    Assert-Check (@(Get-ChildItem -LiteralPath $testRoot -File).Count -eq 6) 'preview leaves root files untouched'
    Assert-Check (@(Get-ChildItem -LiteralPath $testRoot -Recurse -File).Count -eq $before) 'preview preserves total file count'

    $apply = & $scriptPath -Path $testRoot -Apply 2>&1 | Out-String
    Assert-Check ($apply -match '移动 6 个文件') 'apply moves all root files'
    Assert-Check (Test-Path -LiteralPath (Join-Path $testRoot '图片\photo (1).JPG')) 'collision gets a unique name'
    Assert-Check (Test-Path -LiteralPath (Join-Path $testRoot '视频\clip.mp4')) 'video is categorized'
    Assert-Check (Test-Path -LiteralPath (Join-Path $testRoot '文档\notes.txt')) 'document is categorized'
    Assert-Check (Test-Path -LiteralPath (Join-Path $testRoot '压缩包\bundle.zip')) 'archive is categorized'
    Assert-Check (Test-Path -LiteralPath (Join-Path $testRoot '安装包\setup.msi')) 'installer is categorized'
    Assert-Check (Test-Path -LiteralPath (Join-Path $testRoot '其他\unknown.bin')) 'unknown extension goes to other'
    Assert-Check (Test-Path -LiteralPath (Join-Path $testRoot 'nested\keep.mp3')) 'nested file is not touched'
    Assert-Check (@(Get-ChildItem -LiteralPath $testRoot -File).Count -eq 0) 'root has no loose files after apply'

    $manifests = @(Get-ChildItem -LiteralPath (Join-Path $testRoot '.codex-file-organizer-manifests') -Filter '*.json' -File)
    Assert-Check ($manifests.Count -eq 1) 'one undo manifest is created'
    $manifestText = [IO.File]::ReadAllText($manifests[0].FullName, [Text.Encoding]::UTF8)
    Assert-Check ($manifestText -notmatch '(?i)token|cookie|password|secret') 'manifest contains no secret-like fields'

    $repeat = & $scriptPath -Path $testRoot -Apply 2>&1 | Out-String
    Assert-Check ($repeat -match '没有需要整理的文件') 'repeat run is idempotent'
    Assert-Check (@(Get-ChildItem -LiteralPath (Join-Path $testRoot '.codex-file-organizer-manifests') -Filter '*.json' -File).Count -eq 1) 'repeat run creates no empty manifest'

    $undo = & $scriptPath -UndoManifest $manifests[0].FullName 2>&1 | Out-String
    Assert-Check ($undo -match '恢复 6 个') 'undo restores all moved files'
    Assert-Check (@(Get-ChildItem -LiteralPath $testRoot -File).Count -eq 6) 'undo restores root file count'
    Assert-Check ((Get-Content -LiteralPath (Join-Path $testRoot 'photo.JPG') -Raw).Trim() -eq 'image') 'undo restores colliding file to original name'
    Assert-Check ((Get-Content -LiteralPath (Join-Path $testRoot '图片\photo.JPG') -Raw).Trim() -eq 'existing') 'pre-existing destination file remains unchanged'

    $failedAsExpected = $false
    try { & $scriptPath -Path (Join-Path $testRoot 'missing') -ErrorAction Stop | Out-Null }
    catch { $failedAsExpected = $true }
    Assert-Check $failedAsExpected 'missing directory fails safely'

    $failureRoot = Join-Path $testRoot 'failure-case'
    New-Item -ItemType Directory -Path $failureRoot | Out-Null
    Set-Content -LiteralPath (Join-Path $failureRoot 'a.txt') -Value 'first'
    Set-Content -LiteralPath (Join-Path $failureRoot 'z.txt') -Value 'locked'
    $lockedStream = [IO.File]::Open((Join-Path $failureRoot 'z.txt'), 'Open', 'Read', 'None')
    $partialFailed = $false
    try { & $scriptPath -Path $failureRoot -Apply -ErrorAction Stop | Out-Null }
    catch { $partialFailed = $true }
    finally { $lockedStream.Dispose() }
    Assert-Check $partialFailed 'locked file makes apply fail safely'
    $failureManifests = @(Get-ChildItem -LiteralPath (Join-Path $failureRoot '.codex-file-organizer-manifests') -Filter '*.json' -File)
    Assert-Check ($failureManifests.Count -eq 1) 'manifest exists before a partial move failure'
    & $scriptPath -UndoManifest $failureManifests[0].FullName | Out-Null
    Assert-Check (Test-Path -LiteralPath (Join-Path $failureRoot 'a.txt')) 'partial failure can restore an earlier move'
    Assert-Check (Test-Path -LiteralPath (Join-Path $failureRoot 'z.txt')) 'partial failure leaves locked source intact'
}
finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}

Assert-Check (-not (Test-Path -LiteralPath $testRoot)) 'temporary test directory is removed'
Write-Host "Summary: passed=$script:passed failed=$script:failed"
if ($script:failed -gt 0) { exit 1 }
exit 0
