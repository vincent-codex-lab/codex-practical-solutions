[CmdletBinding(DefaultParameterSetName = 'Organize')]
param(
    [Parameter(ParameterSetName = 'Organize')]
    [string]$Path = (Join-Path $HOME 'Downloads'),

    [Parameter(ParameterSetName = 'Organize')]
    [switch]$Apply,

    [Parameter(Mandatory, ParameterSetName = 'Undo')]
    [string]$UndoManifest
)

$ErrorActionPreference = 'Stop'

$categoryExtensions = [ordered]@{
    '图片'   = @('.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp', '.svg')
    '视频'   = @('.mp4', '.mov', '.mkv', '.avi', '.webm', '.m4v')
    '音频'   = @('.mp3', '.wav', '.m4a', '.flac', '.aac', '.ogg')
    '文档'   = @('.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.md', '.csv')
    '压缩包' = @('.zip', '.7z', '.rar', '.tar', '.gz')
    '安装包' = @('.exe', '.msi', '.msix', '.appx')
}

function Get-Category {
    param([string]$Extension)
    $normalized = $Extension.ToLowerInvariant()
    foreach ($entry in $categoryExtensions.GetEnumerator()) {
        if ($entry.Value -contains $normalized) { return $entry.Key }
    }
    return '其他'
}

function Get-AvailableDestination {
    param([string]$Directory, [string]$FileName)
    $candidate = Join-Path $Directory $FileName
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }

    $base = [IO.Path]::GetFileNameWithoutExtension($FileName)
    $extension = [IO.Path]::GetExtension($FileName)
    for ($index = 1; $index -le 9999; $index++) {
        $candidate = Join-Path $Directory ("{0} ({1}){2}" -f $base, $index, $extension)
        if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    throw "无法为文件生成不冲突的名称：$FileName"
}

function Invoke-Undo {
    param([string]$ManifestPath)
    $resolvedManifest = (Resolve-Path -LiteralPath $ManifestPath).Path
    $manifest = [IO.File]::ReadAllText($resolvedManifest, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 1 -or -not $manifest.moves) {
        throw '撤销清单格式无效或没有可撤销记录。'
    }

    $restored = 0
    $skipped = 0
    $recordedMoves = @($manifest.moves)
    for ($moveIndex = $recordedMoves.Count - 1; $moveIndex -ge 0; $moveIndex--) {
        $move = $recordedMoves[$moveIndex]
        if (-not (Test-Path -LiteralPath $move.destination -PathType Leaf)) {
            Write-Warning "目标文件不存在，跳过：$($move.destination)"
            $skipped++
            continue
        }
        if (Test-Path -LiteralPath $move.source) {
            Write-Warning "原位置已有同名内容，为防止覆盖而跳过：$($move.source)"
            $skipped++
            continue
        }
        Move-Item -LiteralPath $move.destination -Destination $move.source
        $restored++
    }
    Write-Output "撤销完成：恢复 $restored 个，跳过 $skipped 个。"
    return
}

if ($PSCmdlet.ParameterSetName -eq 'Undo') {
    Invoke-Undo -ManifestPath $UndoManifest
    exit 0
}

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "目录不存在：$Path"
}

$root = (Resolve-Path -LiteralPath $Path).Path
$files = @(Get-ChildItem -LiteralPath $root -File -Force | Where-Object {
    -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
})

$plan = foreach ($file in $files) {
    $category = Get-Category -Extension $file.Extension
    [pscustomobject]@{
        File     = $file
        Category = $category
    }
}

if (-not $Apply) {
    if ($plan.Count -eq 0) {
        Write-Output '预览完成：根目录没有需要整理的文件。'
        exit 0
    }
    $plan | Select-Object @{Name='文件';Expression={$_.File.Name}}, @{Name='将移动到';Expression={$_.Category}} | Format-Table -AutoSize
    Write-Output "预览完成：共 $($plan.Count) 个文件。未修改任何内容；确认后加 -Apply 执行。"
    exit 0
}

if ($plan.Count -eq 0) {
    Write-Output '执行完成：根目录没有需要整理的文件，未做修改。'
    exit 0
}

$moves = [Collections.Generic.List[object]]::new()
foreach ($item in $plan) {
    $categoryDirectory = Join-Path $root $item.Category
    if (-not (Test-Path -LiteralPath $categoryDirectory)) {
        New-Item -ItemType Directory -Path $categoryDirectory | Out-Null
    }
    $destination = Get-AvailableDestination -Directory $categoryDirectory -FileName $item.File.Name
    $moves.Add([ordered]@{
        source      = $item.File.FullName
        destination = $destination
    })
}

$manifestDirectory = Join-Path $root '.codex-file-organizer-manifests'
New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
$manifestPath = Join-Path $manifestDirectory ((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffffffZ') + '.json')
$manifest = [ordered]@{
    schemaVersion = 1
    createdUtc    = (Get-Date).ToUniversalTime().ToString('o')
    root          = $root
    moves         = $moves
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Output "已创建撤销清单：$manifestPath"

try {
    foreach ($move in $moves) {
        Move-Item -LiteralPath $move.source -Destination $move.destination
    }
}
catch {
    throw "整理中途停止。部分文件可能已经移动；请解除文件占用后使用撤销清单恢复：$manifestPath。原始错误：$($_.Exception.Message)"
}

Write-Output "整理完成：移动 $($moves.Count) 个文件。"
Write-Output "撤销清单：$manifestPath"
Write-Output "撤销命令：powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -UndoManifest `"$manifestPath`""
