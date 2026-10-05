[CmdletBinding()]
param(
    [string]$Target = (Join-Path (Get-Location) 'musedesk-windows'),
    [ValidateSet('x64', 'arm64')]
    [string]$Arch = 'x64',
    [switch]$NoBuild,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Upstream = 'https://github.com/atameric/musedesk.git'
$PinnedCommit = '008f1396f99e1fa64cda0fe4ea2351b391fb6313'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Overlay = Join-Path $Here 'overlay'
$Target = [System.IO.Path]::GetFullPath($Target)

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
    )
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed with exit code $LASTEXITCODE"
    }
}

function Replace-Exact {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Before,
        [Parameter(Mandatory = $true)][string]$After
    )
    $text = Get-Content $Path -Raw
    if (-not $text.Contains($Before)) {
        throw "Expected source fragment was not found in $Path. The upstream file may have changed."
    }
    $text = $text.Replace($Before, $After)
    [System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git is required.'
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw 'Node.js 20 or newer is required.'
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw 'npm is required.'
}

if (-not (Test-Path $Target)) {
    $TargetParent = Split-Path -Parent $Target
    if ($TargetParent) { New-Item -ItemType Directory -Path $TargetParent -Force | Out-Null }
    Invoke-Checked git clone $Upstream $Target
    Invoke-Checked git -C $Target checkout $PinnedCommit
}
else {
    if (-not (Test-Path (Join-Path $Target '.git'))) {
        throw "Target exists but is not a Git checkout: $Target"
    }
    $head = (& git -C $Target rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read target Git revision.' }
    $dirty = (& git -C $Target status --porcelain)
    if (-not $Force -and $head -ne $PinnedCommit) {
        throw "Target is at $head, expected $PinnedCommit. Re-run with -Force only if you intend to port another revision."
    }
    if (-not $Force -and $dirty) {
        throw 'Target checkout has local changes. Commit or stash them, or re-run with -Force.'
    }
}

Get-ChildItem -LiteralPath $Overlay -File -Recurse -Force | ForEach-Object {
    $relative = $_.FullName.Substring($Overlay.Length).TrimStart([char[]]'\/')
    $destination = Join-Path $Target $relative
    $destinationDir = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
}

$HostPath = Join-Path $Target 'src\msp\host.ts'
$host = Get-Content $HostPath -Raw
$hostNeedle = "      stdio: ['pipe', 'pipe', 'pipe'],"
if (-not $host.Contains($hostNeedle)) {
    throw "Expected spawn options were not found in $HostPath. The upstream file may have changed."
}
$hostEol = if ($host.Contains("`r`n")) { "`r`n" } else { "`n" }
$hostInsert = $hostNeedle + $hostEol +
    '      windowsHide: true,' + $hostEol +
    "      shell: process.platform === 'win32' && /\.(cmd|bat)$/i.test(this.binPath),"
$host = $host.Replace($hostNeedle, $hostInsert)
[System.IO.File]::WriteAllText($HostPath, $host, [System.Text.UTF8Encoding]::new($false))

$ProjectsPath = Join-Path $Target 'src\shared\projects.ts'
Replace-Exact $ProjectsPath "folder.split('/').filter(Boolean)" "folder.split(/[\\/]+/).filter(Boolean)"
Replace-Exact $ProjectsPath "folder.replace(/\/+\`$/, '')" "folder.replace(/[\\/]+\`$/, '')"

$SidebarPath = Join-Path $Target 'src\ui\Sidebar.tsx'
Replace-Exact $SidebarPath "s.workspaceRoot.split('/').filter(Boolean).pop()" "s.workspaceRoot.split(/[\\/]+/).filter(Boolean).pop()"
Replace-Exact $SidebarPath '<button className="kbd" onClick={onPalette} title="Open command palette (⌘K)" aria-label="Open command palette">⌘K</button>' '<button className="kbd" onClick={onPalette} title="Open command palette (Ctrl+K)" aria-label="Open command palette">Ctrl K</button>'

$AppPath = Join-Path $Target 'src\ui\App.tsx'
$app = Get-Content $AppPath -Raw
$needle = "replace(/\/+\`$/, '')"
if (-not $app.Contains($needle)) {
    throw "Expected path-normalization fragment was not found in $AppPath"
}
$app = $app.Replace($needle, "replace(/[\\/]+\`$/, '')")
[System.IO.File]::WriteAllText($AppPath, $app, [System.Text.UTF8Encoding]::new($false))

$PackagingTestPath = Join-Path $Target 'test\unit\packaging.test.ts'
Replace-Exact $PackagingTestPath "it('ships a single DMG maker with a distinct installer volume title', async () => {" "it('ships a single DMG maker with a distinct installer volume title', { skip: process.platform === 'win32' }, async () => {"

$GitIgnore = Join-Path $Target '.gitignore'
$ignore = Get-Content $GitIgnore -Raw
if (-not $ignore.Contains('assets/icon.ico')) {
    Add-Content -Path $GitIgnore -Value "`n# Generated Windows application icon`nassets/icon.ico`n"
}

Invoke-Checked git -C $Target diff --check

Write-Host "Windows port applied to $Target"
Write-Host "Base revision $PinnedCommit"

if (-not $NoBuild) {
    & (Join-Path $Target 'scripts\build-windows.ps1') -Arch $Arch
    if ($LASTEXITCODE -ne 0) {
        throw "Windows build failed with exit code $LASTEXITCODE"
    }
}
else {
    Write-Host 'Build skipped. Run .\scripts\build-windows.ps1 from the patched repository on Windows.'
}
