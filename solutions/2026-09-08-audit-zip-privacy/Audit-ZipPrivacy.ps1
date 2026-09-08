[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,

    [string]$ReportPath,

    [ValidateRange(1024, 10485760)]
    [int64]$MaxEntryBytes = 2097152,

    [ValidateRange(1048576, 1073741824)]
    [int64]$MaxTotalBytes = 104857600
)

$ErrorActionPreference = 'Stop'

function Protect-EntryName {
    param([string]$Name)

    $safe = $Name -replace '(?i)(Users[/\\])[^/\\]+', '$1<USER>'
    $safe = $safe -replace '(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', '<EMAIL>'
    if ($safe.Length -gt 240) { $safe = $safe.Substring(0, 237) + '...' }
    return $safe
}

function New-Result {
    param(
        [string]$Status,
        [int]$ExitCode,
        [string]$Archive,
        [object[]]$Findings,
        [int]$EntriesScanned,
        [int]$EntriesSkipped,
        [string]$ErrorMessage = ''
    )

    [ordered]@{
        status          = $Status
        exit_code       = $ExitCode
        archive         = Protect-EntryName $Archive
        entries_scanned = $EntriesScanned
        entries_skipped = $EntriesSkipped
        findings_count  = $Findings.Count
        findings        = $Findings
        error           = $ErrorMessage
    }
}

function Add-Finding {
    param(
        [System.Collections.Generic.List[object]]$List,
        [string]$Severity,
        [string]$Rule,
        [string]$Entry,
        [string]$Message
    )

    $List.Add([pscustomobject][ordered]@{
        severity = $Severity
        rule     = $Rule
        entry    = Protect-EntryName $Entry
        message  = $Message
    })
}

$findings = New-Object 'System.Collections.Generic.List[object]'
$scanned = 0
$skipped = 0
$archiveName = Split-Path -Leaf $ZipPath

try {
    if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
        throw 'ZIP file does not exist.'
    }
    if ([IO.Path]::GetExtension($ZipPath) -ne '.zip') {
        throw 'Only .zip files are supported.'
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ZipPath).Path)
    try {
        $totalBytes = [int64](($archive.Entries | Measure-Object -Property Length -Sum).Sum)
        if ($totalBytes -gt $MaxTotalBytes) {
            Add-Finding $findings 'Review' 'ArchiveTooLarge' '<archive>' 'Uncompressed archive size exceeds the scanning limit.'
        }

        $textExtensions = @('.txt', '.md', '.json', '.xml', '.yml', '.yaml', '.ini', '.cfg', '.conf', '.env', '.ps1', '.cmd', '.bat', '.py', '.js', '.ts', '.toml', '.properties', '.csv')
        $sensitiveNames = @('.env', '.npmrc', '.pypirc', '.git-credentials', 'credentials.json', 'cookies.json', 'auth.json', 'id_rsa', 'id_ed25519')
        $contentRules = @(
            [pscustomobject]@{ Severity='High'; Rule='OpenAIKey'; Pattern='sk-[A-Za-z0-9_-]{20,}'; Message='Possible API key.' },
            [pscustomobject]@{ Severity='High'; Rule='GitHubToken'; Pattern='github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}'; Message='Possible GitHub access token.' },
            [pscustomobject]@{ Severity='High'; Rule='PrivateKey'; Pattern='-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'; Message='Possible private key.' },
            [pscustomobject]@{ Severity='High'; Rule='AwsAccessKey'; Pattern='AKIA[0-9A-Z]{16}'; Message='Possible AWS access key.' },
            [pscustomobject]@{ Severity='Review'; Rule='CredentialAssignment'; Pattern='(?im)\b(?:password|passwd|token|secret|api[_-]?key)\s*[:=]\s*[^\s#]{8,}'; Message='Possible credential assignment; manual review required.' },
            [pscustomobject]@{ Severity='Review'; Rule='EmailAddress'; Pattern='(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'; Message='Email address detected.' },
            [pscustomobject]@{ Severity='Review'; Rule='WindowsUserPath'; Pattern='(?i)[A-Z]:\\Users\\[^\\\r\n]+\\'; Message='Windows user directory detected.' },
            [pscustomobject]@{ Severity='Review'; Rule='UnixHomePath'; Pattern=('/' + 'home/' + '[^/\s]+/'); Message='Unix home directory detected.' }
        )

        foreach ($entry in $archive.Entries) {
            if ([string]::IsNullOrEmpty($entry.Name)) { continue }
            $entryName = $entry.FullName -replace '\\', '/'
            $leafName = [IO.Path]::GetFileName($entryName).ToLowerInvariant()

            if ($entryName -match '(^|/)\.\.(/|$)' -or $entryName.StartsWith('/') -or $entryName -match '^[A-Za-z]:') {
                Add-Finding $findings 'High' 'ArchiveTraversal' $entryName 'Archive entry contains an unsafe path.'
            }
            if ($sensitiveNames -contains $leafName -or $leafName.EndsWith('.pem') -or $leafName.EndsWith('.key')) {
                Add-Finding $findings 'Review' 'SensitiveFileName' $entryName 'Filename may contain credentials or a private key.'
            }

            $extension = [IO.Path]::GetExtension($leafName).ToLowerInvariant()
            if (($textExtensions -notcontains $extension) -and ($sensitiveNames -notcontains $leafName)) { continue }
            if ($totalBytes -gt $MaxTotalBytes -or $entry.Length -gt $MaxEntryBytes) {
                $skipped++
                Add-Finding $findings 'Review' 'ContentNotScanned' $entryName 'Text file exceeds the safe scanning limit; only its name was checked.'
                continue
            }

            $stream = $entry.Open()
            $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8, $true)
            try { $content = $reader.ReadToEnd() }
            finally { $reader.Dispose(); $stream.Dispose() }
            $scanned++

            foreach ($rule in $contentRules) {
                if ([regex]::IsMatch($content, $rule.Pattern)) {
                    Add-Finding $findings $rule.Severity $rule.Rule $entryName $rule.Message
                }
            }
        }
    }
    finally {
        $archive.Dispose()
    }

    $exitCode = if ($findings.Count -eq 0) { 0 } else { 10 }
    $status = if ($exitCode -eq 0) { 'Safe' } else { 'Review' }
    $result = New-Result $status $exitCode $archiveName $findings.ToArray() $scanned $skipped
}
catch {
    $exitCode = 2
    $result = New-Result 'Error' $exitCode $archiveName @() $scanned $skipped $_.Exception.Message
}

$json = $result | ConvertTo-Json -Depth 6
if ($ReportPath) {
    $parent = Split-Path -Parent $ReportPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [IO.File]::WriteAllText($ReportPath, $json, (New-Object Text.UTF8Encoding($false)))
}
$json
exit $exitCode
