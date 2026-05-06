#Requires -Version 5.1
<#
.SYNOPSIS
    Build & sign Cleanup-Menu.exe from Cleanup-Menu.ps1 using ps2exe.

.DESCRIPTION
    Edit the $Meta hashtable below to change metadata (author, version, copyright, ...).
    Re-run this script after editing the .ps1 source or the metadata to rebuild.

    Steps performed:
      1. Build EXE with ps2exe (icon + metadata + admin manifest)
      2. Sign EXE with the self-signed cert (thumbprint from .cert-thumbprint.txt)
      3. Verify signature

.NOTES
    powershell -ExecutionPolicy Bypass -File .\tools\build.ps1
#>

[CmdletBinding()]
param(
    [string]$Source,
    [string]$Output,
    [string]$IconFile,
    [string]$ThumbprintFile,
    [string]$Version
)

$ErrorActionPreference = 'Stop'

# Robust script-root resolution (works for: .\build.ps1 invocation, F8 selection in editor, dot-sourcing)
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot -and $MyInvocation.MyCommand.Path) {
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $ScriptRoot) { $ScriptRoot = (Get-Location).Path }

# Repo root = parent of tools/ — source files (Cleanup-Menu.ps1, favicon.ico, cert/) live there
$RepoRoot = Split-Path -Parent $ScriptRoot

if (-not $Source)         { $Source         = Join-Path $RepoRoot 'Cleanup-Menu.ps1' }
if (-not $Output)         { $Output         = Join-Path $RepoRoot 'FreeSpace.exe' }
if (-not $IconFile)       { $IconFile       = Join-Path $RepoRoot 'favicon.ico' }
if (-not $ThumbprintFile) { $ThumbprintFile = Join-Path $RepoRoot 'cert\.cert-thumbprint.txt' }

# =================================================================
# === EDIT METADATA HERE ==========================================
# =================================================================
# These map to fields shown in: File > Properties > Details (in Explorer)
$Meta = @{
    Title       = 'Free Space'        # -> "File description"
    Description = 'Free Space is windows cleanup tool (sizes, cleanup, DISM, recycle bin)'  # -> "Comments"
    Company     = 'nongdandev'                   # -> "Author / Company name"  <-- ĐỔI TÊN AUTHOR Ở ĐÂY
    Product     = 'Free Space'                # -> "Product name"
    Copyright   = "(c) $(Get-Date -Format yyyy) nongdandev"  # -> "Copyright"
    Trademark   = ''                            # -> "Legal trademarks"
    Version     = '1.0.0.0'                     # -> "File version" / "Product version"  (must be N.N.N.N)
}
# =================================================================

# CI/override: -Version param wins over the hashtable above (must be N.N.N.N)
if ($Version) {
    $parts = $Version -split '\.'
    while ($parts.Count -lt 4) { $parts += '0' }
    $Meta.Version = ($parts[0..3] -join '.')
}

# Sanity checks
if (-not (Test-Path -LiteralPath $Source)) { throw "Source not found: $Source" }
if (-not (Test-Path -LiteralPath $IconFile)) { throw "Icon not found: $IconFile" }

Import-Module ps2exe -Force

Write-Host "==> Building EXE..." -ForegroundColor Cyan
Invoke-PS2EXE `
    -InputFile   $Source `
    -OutputFile  $Output `
    -IconFile    $IconFile `
    -Title       $Meta.Title `
    -Description $Meta.Description `
    -Company     $Meta.Company `
    -Product     $Meta.Product `
    -Copyright   $Meta.Copyright `
    -Trademark   $Meta.Trademark `
    -Version     $Meta.Version `
    -RequireAdmin

if (-not (Test-Path -LiteralPath $Output)) { throw "ps2exe did not produce: $Output" }

# --- Sign ---
if (Test-Path -LiteralPath $ThumbprintFile) {
    $thumb = (Get-Content -LiteralPath $ThumbprintFile -Raw).Trim()
    $cert = Get-Item "Cert:\CurrentUser\My\$thumb" -ErrorAction SilentlyContinue
    if (-not $cert) {
        Write-Host "Cert $thumb không tìm thấy trong CurrentUser\My — bỏ qua bước ký." -ForegroundColor Yellow
    }
    else {
        Write-Host "==> Signing with $($cert.Subject) ($thumb)..." -ForegroundColor Cyan
        # Try with timestamp; fall back to no-timestamp if offline
        $sig = $null
        try {
            $sig = Set-AuthenticodeSignature -FilePath $Output -Certificate $cert `
                -HashAlgorithm SHA256 `
                -TimestampServer 'http://timestamp.digicert.com' `
                -ErrorAction Stop
        }
        catch {
            Write-Host "  Timestamp server unreachable — signing without timestamp." -ForegroundColor Yellow
            $sig = Set-AuthenticodeSignature -FilePath $Output -Certificate $cert `
                -HashAlgorithm SHA256
        }
        Write-Host ("  Status: {0}" -f $sig.Status) -ForegroundColor Green
    }
}
else {
    Write-Host "Không thấy $ThumbprintFile — bỏ qua bước ký." -ForegroundColor Yellow
}

# --- Verify ---
$f = Get-Item -LiteralPath $Output
$vi = $f.VersionInfo
$ag = Get-AuthenticodeSignature -FilePath $Output

Write-Host ""
Write-Host "==> Result" -ForegroundColor Cyan
"  File           : $($f.FullName) ($([math]::Round($f.Length/1KB,1)) KB)"
"  FileVersion    : $($vi.FileVersion)"
"  ProductName    : $($vi.ProductName)"
"  CompanyName    : $($vi.CompanyName)"
"  Description    : $($vi.FileDescription)"
"  Copyright      : $($vi.LegalCopyright)"
"  Signature      : $($ag.Status) — $($ag.SignerCertificate.Subject)"
