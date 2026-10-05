[CmdletBinding()]
param(
    [ValidateSet('x64', 'arm64')]
    [string]$Arch = 'x64',
    [switch]$SkipInstall,
    [switch]$SkipChecks
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
$PackageJsonPath = Join-Path $Root 'package.json'
$PngPath = Join-Path $Root 'assets\icon-1024.png'
$IcoPath = Join-Path $Root 'assets\icon.ico'

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

function New-WindowsIcon {
    if (Test-Path $IcoPath) {
        return
    }
    if (-not (Test-Path $PngPath)) {
        throw "Source icon not found: $PngPath"
    }

    Add-Type -AssemblyName System.Drawing
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class MuseDeskNativeIcon {
    [DllImport("user32.dll")]
    public static extern bool DestroyIcon(IntPtr handle);
}
'@

    $source = [System.Drawing.Image]::FromFile($PngPath)
    $bitmap = New-Object System.Drawing.Bitmap 256, 256
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $hIcon = [IntPtr]::Zero
    $icon = $null
    $stream = $null
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($source, 0, 0, 256, 256)
        $hIcon = $bitmap.GetHicon()
        $icon = [System.Drawing.Icon]::FromHandle($hIcon)
        $stream = [System.IO.File]::Open($IcoPath, [System.IO.FileMode]::Create)
        $icon.Save($stream)
    }
    finally {
        if ($stream) { $stream.Dispose() }
        if ($icon) { $icon.Dispose() }
        if ($hIcon -ne [IntPtr]::Zero) { [MuseDeskNativeIcon]::DestroyIcon($hIcon) | Out-Null }
        $graphics.Dispose()
        $bitmap.Dispose()
        $source.Dispose()
    }
}

if ($env:OS -ne 'Windows_NT') {
    throw 'The Windows package must be built on Windows.'
}

Push-Location $Root
try {
    if (-not (Test-Path $PackageJsonPath)) {
        throw "package.json not found under $Root"
    }

    New-WindowsIcon

    if (-not $SkipInstall) {
        Invoke-Checked npm ci
    }

    if (-not $SkipChecks) {
        Invoke-Checked npm run typecheck
        Invoke-Checked npm run lint
        Invoke-Checked npm test
    }

    $Forge = Join-Path $Root 'node_modules\.bin\electron-forge.cmd'
    $Shim = Join-Path $Root 'scripts\forge-extract-shim.js'
    if (-not (Test-Path $Forge)) {
        throw 'Electron Forge is not installed. Run npm ci first.'
    }

    $PreviousNodeOptions = $env:NODE_OPTIONS
    $ShimForNode = ([System.IO.Path]::GetFullPath($Shim)).Replace('\\', '/')
    $RequireOption = "--require=$ShimForNode"
    try {
        $env:NODE_OPTIONS = if ($PreviousNodeOptions) { "$PreviousNodeOptions $RequireOption" } else { $RequireOption }
        Invoke-Checked $Forge package '--platform=win32' "--arch=$Arch"
    }
    finally {
        $env:NODE_OPTIONS = $PreviousNodeOptions
    }

    $Package = Get-Content $PackageJsonPath -Raw | ConvertFrom-Json
    $PackageDir = Join-Path $Root "out.noindex\MuseDesk-win32-$Arch"
    $ExePath = Join-Path $PackageDir 'MuseDesk.exe'
    if (-not (Test-Path $ExePath)) {
        throw "Expected packaged executable was not created: $ExePath"
    }

    $magic = [System.IO.File]::ReadAllBytes($ExePath)
    if ($magic.Length -lt 2 -or $magic[0] -ne 0x4D -or $magic[1] -ne 0x5A) {
        throw 'Packaged MuseDesk.exe does not have a valid Windows PE signature.'
    }

    $DistDir = Join-Path $Root 'dist'
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
    $ZipName = "MuseDesk-$($Package.version)-windows-$Arch.zip"
    $ZipPath = Join-Path $DistDir $ZipName
    $HashPath = "$ZipPath.sha256"
    Remove-Item $ZipPath, $HashPath -Force -ErrorAction SilentlyContinue

    Compress-Archive -Path (Join-Path $PackageDir '*') -DestinationPath $ZipPath -CompressionLevel Optimal
    $Hash = (Get-FileHash -Algorithm SHA256 $ZipPath).Hash.ToLowerInvariant()
    Set-Content -Path $HashPath -Value "$Hash  $ZipName" -Encoding ascii

    Write-Host "Built $ZipPath"
    Write-Host "SHA256 $Hash"
}
finally {
    Pop-Location
}
