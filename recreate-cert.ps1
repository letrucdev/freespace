#Requires -Version 5.1
<#
.SYNOPSIS
    Tạo lại self-signed code-signing cert với CN (Common Name) tuỳ chọn.

.DESCRIPTION
    CN của cert chính là "Verified publisher" hiển thị trên UAC dialog.
    Script này:
      1. (Tuỳ chọn) Xoá cert cũ trỏ bởi .cert-thumbprint.txt khỏi CurrentUser\My, Root, TrustedPublisher
      2. Tạo cert mới với CN = $Name trong CurrentUser\My
      3. Install vào CurrentUser\Root + CurrentUser\TrustedPublisher để Authenticode chain validate
      4. Export public cert ra <Name>.cer
      5. Ghi thumbprint mới vào .cert-thumbprint.txt
      Sau đó chạy build.ps1 để EXE được ký lại với cert mới.

.PARAMETER Name
    Common Name (CN) — sẽ hiển thị trên UAC dialog là "Verified publisher".
    Ví dụ: "Le Truc", "Acme Corp", "Cleanup Tools".

.PARAMETER ValidYears
    Số năm cert có hiệu lực. Mặc định 5.

.PARAMETER RemoveOld
    Xoá cert cũ (theo thumbprint trong .cert-thumbprint.txt) khỏi tất cả store CurrentUser.

.EXAMPLE
    .\recreate-cert.ps1 -Name "Le Truc"

.EXAMPLE
    .\recreate-cert.ps1 -Name "Le Truc" -RemoveOld
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Name,

    [int]$ValidYears = 5,

    [switch]$RemoveOld
)

$ErrorActionPreference = 'Stop'

# Robust script-root resolution (works for: .\recreate-cert.ps1 invocation, F8 selection in editor, dot-sourcing)
$root = $PSScriptRoot
if (-not $root -and $MyInvocation.MyCommand.Path) {
    $root = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $root) { $root = (Get-Location).Path }

$thumbFile = Join-Path $root '.cert-thumbprint.txt'

# --- Step 1: optionally remove old cert ---
if ($RemoveOld -and (Test-Path -LiteralPath $thumbFile)) {
    $oldThumb = (Get-Content -LiteralPath $thumbFile -Raw).Trim()
    if ($oldThumb) {
        Write-Host "==> Xoá cert cũ ($oldThumb) khỏi CurrentUser stores..." -ForegroundColor Cyan
        foreach ($storeName in 'My', 'Root', 'TrustedPublisher') {
            $path = "Cert:\CurrentUser\$storeName\$oldThumb"
            $c = Get-Item -Path $path -ErrorAction SilentlyContinue
            if ($c) {
                Remove-Item -Path $path -Force
                "  removed from CurrentUser\$storeName"
            }
        }
    }
}

# --- Step 2: create new cert ---
$subject = "CN=$Name"
Write-Host "==> Tạo cert mới: $subject (hiệu lực $ValidYears năm)" -ForegroundColor Cyan

$cert = New-SelfSignedCertificate `
    -Subject           $subject `
    -Type              CodeSigningCert `
    -CertStoreLocation Cert:\CurrentUser\My `
    -KeyAlgorithm      RSA `
    -KeyLength         2048 `
    -KeyUsage          DigitalSignature `
    -HashAlgorithm     SHA256 `
    -NotAfter          ((Get-Date).AddYears($ValidYears))

"  Thumbprint : $($cert.Thumbprint)"
"  NotAfter   : $($cert.NotAfter)"

# --- Step 3: install to trust stores (CurrentUser, no admin needed) ---
foreach ($storeName in 'Root', 'TrustedPublisher') {
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($storeName, 'CurrentUser')
    $store.Open('ReadWrite')
    $store.Add($cert)
    $store.Close()
    "  installed to CurrentUser\$storeName"
}

# --- Step 4: export public .cer ---
$safeName = ($Name -replace '[^\w\-]', '_').Trim('_')
if (-not $safeName) { $safeName = 'CodeSigningCert' }
$cerPath = Join-Path $root "$safeName.cer"
[System.IO.File]::WriteAllBytes($cerPath, $cert.RawData)
"  exported   : $cerPath"

# --- Step 5: persist thumbprint for build.ps1 ---
$cert.Thumbprint | Set-Content -LiteralPath $thumbFile -NoNewline

Write-Host ""
Write-Host "Xong. Bây giờ chạy build.ps1 để re-sign EXE:" -ForegroundColor Green
Write-Host "    powershell -ExecutionPolicy Bypass -File `"$root\build.ps1`"" -ForegroundColor Yellow
