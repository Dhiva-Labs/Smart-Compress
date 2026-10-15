<#
.SYNOPSIS
Packages the Windows release build as a zip.

.DESCRIPTION
Run after `flutter build windows --release` in the repo root:

    pwsh tool/package_windows.ps1 [-OutDir dist] [-Arch x64|arm64]

-Arch defaults to the machine's architecture ($env:PROCESSOR_ARCHITECTURE),
which is also the only one `flutter build windows` targets, so the build is
read from build\windows\x64\... on x64 and build\windows\arm64\... on ARM64.

Writes smart-compress-windows-<arch>.zip to -OutDir (default dist\):
the release folder, unpackaged.
#>
param(
    [string]$OutDir = 'dist',
    [ValidateSet('x64', 'arm64')]
    [string]$Arch
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not $Arch) {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { $Arch = 'x64' }
        'ARM64' { $Arch = 'arm64' }
        default { throw "unsupported PROCESSOR_ARCHITECTURE '$env:PROCESSOR_ARCHITECTURE' (AMD64 or ARM64)" }
    }
}

$release = "build\windows\$Arch\runner\Release"
if (-not (Test-Path "$release\smart_compress.exe")) {
    throw "$release\smart_compress.exe not found - run 'flutter build windows --release' first"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$out = (Resolve-Path $OutDir).Path

# One smart-compress-windows-<arch>\ folder holding the release build.
$name = "smart-compress-windows-$Arch"
$stage = Join-Path ([IO.Path]::GetTempPath()) "smart-compress-zip-$([guid]::NewGuid())"
try {
    New-Item -ItemType Directory -Path $stage | Out-Null
    Copy-Item -Recurse -Path $release -Destination (Join-Path $stage $name)
    $zip = Join-Path $out "$name.zip"
    if (Test-Path $zip) { Remove-Item $zip }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    # includeBaseDirectory = $true keeps the smart-compress-... folder inside the zip;
    # pwsh 7 writes "/" separators (Windows PowerShell 5 would write "\").
    [IO.Compression.ZipFile]::CreateFromDirectory(
        (Join-Path $stage $name), $zip, [IO.Compression.CompressionLevel]::Optimal, $true)
    Write-Host "built $zip"
} finally {
    Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
}
