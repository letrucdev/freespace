#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive cleanup menu for Windows system & user folders.
.DESCRIPTION
    Provides a menu to analyze sizes, clean specific folders, run Disk Cleanup,
    empty Recycle Bin, and run Component Store cleanup (DISM).
.NOTES
    Run as Administrator for full functionality (Windows.old, Windows folders, DISM).
#>

[CmdletBinding()]
param(
    [string]$Title = 'Free Space'
)

$ErrorActionPreference = 'Stop'

# Ensure Vietnamese output renders correctly in legacy consoles (PS 5.1 / cmd)
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding = [System.Text.UTF8Encoding]::new()
}
catch { }

try { $Host.UI.RawUI.WindowTitle = $Title } catch { }

# ---------- Folder definitions ----------
$Folders = [ordered]@{
    'NVIDIA DXCache'                = Join-Path $env:LOCALAPPDATA 'NVIDIA\DXCache'
    'Windows.old'                   = Join-Path $env:SystemDrive  'Windows.old'
    'User Temp (AppData)'           = $env:TEMP
    'Windows Temp'                  = Join-Path $env:WinDir 'Temp'
    'SoftwareDistribution\Download' = Join-Path $env:WinDir 'SoftwareDistribution\Download'
    'Windows Prefetch'              = Join-Path $env:WinDir 'Prefetch'
    'Downloads'                     = Join-Path $env:USERPROFILE 'Downloads'
}

# ---------- Helpers ----------
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Format-Size {
    param([double]$Bytes)
    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
    return ('{0} B' -f [int]$Bytes)
}

function Get-FolderSize {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Bytes = 0; FileCount = 0; Exists = $false }
    }
    try {
        $items = Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue
        $sum = ($items | Measure-Object -Property Length -Sum).Sum
        if ($null -eq $sum) { $sum = 0 }
        return [pscustomobject]@{
            Bytes     = [double]$sum
            FileCount = ($items | Measure-Object).Count
            Exists    = $true
        }
    }
    catch {
        return [pscustomobject]@{ Bytes = 0; FileCount = 0; Exists = $true; Error = $_.Exception.Message }
    }
}

function Show-FolderSizes {
    Write-Host ""
    Write-Host "=== Phân tích size folder ===" -ForegroundColor Cyan
    Write-Host ""

    $rows = @()
    $totalBytes = 0.0
    foreach ($name in $Folders.Keys) {
        $path = $Folders[$name]
        Write-Host ("  Đang quét: {0} ..." -f $name) -ForegroundColor DarkGray
        $info = Get-FolderSize -Path $path
        $totalBytes += $info.Bytes
        $rows += [pscustomobject]@{
            Folder    = $name
            Path      = $path
            Size      = if ($info.Exists) { Format-Size $info.Bytes } else { '(không tồn tại)' }
            Files     = if ($info.Exists) { $info.FileCount } else { '-' }
            SizeBytes = $info.Bytes
        }
    }

    Write-Host ""
    $rows | Sort-Object -Property SizeBytes -Descending |
    Format-Table -AutoSize -Property Folder, Size, Files, Path

    Write-Host ("Tổng: {0}" -f (Format-Size $totalBytes)) -ForegroundColor Yellow
    Write-Host ""
}

function Clear-FolderContents {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Path,
        [switch]$DeleteRoot   # if set, removes the folder itself (e.g. Windows.old)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host ("  [skip] {0}: không tồn tại ({1})" -f $Name, $Path) -ForegroundColor DarkYellow
        return [pscustomobject]@{ Name = $Name; Freed = 0; Errors = 0 }
    }

    $before = (Get-FolderSize -Path $Path).Bytes
    $errors = 0

    if ($DeleteRoot) {
        Write-Host ("  Đang xoá thư mục: {0}" -f $Path) -ForegroundColor Yellow
        try {
            # takeown + icacls helps remove protected Windows.old contents
            & takeown.exe /F $Path /R /D Y *> $null
            & icacls.exe  $Path /grant "*S-1-5-32-544:F" /T /C *> $null
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        }
        catch {
            $errors++
            Write-Host ("    Lỗi: {0}" -f $_.Exception.Message) -ForegroundColor Red
        }
    }
    else {
        Write-Host ("  Đang dọn: {0}" -f $Path) -ForegroundColor Yellow
        Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
            }
            catch {
                $errors++
            }
        }
    }

    $after = if (Test-Path -LiteralPath $Path) { (Get-FolderSize -Path $Path).Bytes } else { 0 }
    $freed = [Math]::Max(0, $before - $after)

    $msg = "    -> Giải phóng {0}" -f (Format-Size $freed)
    if ($errors -gt 0) { $msg += " ($errors mục bị khoá/đang dùng, bỏ qua)" }
    Write-Host $msg -ForegroundColor Green

    return [pscustomobject]@{ Name = $Name; Freed = $freed; Errors = $errors }
}

function Stop-WindowsUpdateForCleanup {
    # Best-effort: stop wuauserv/bits before clearing SoftwareDistribution\Download
    foreach ($svc in 'wuauserv', 'bits') {
        try {
            $s = Get-Service -Name $svc -ErrorAction Stop
            if ($s.Status -eq 'Running') {
                Write-Host ("  Stopping service: {0}" -f $svc) -ForegroundColor DarkGray
                Stop-Service -Name $svc -Force -ErrorAction Stop
            }
        }
        catch {
            Write-Host ("  Không stop được {0}: {1}" -f $svc, $_.Exception.Message) -ForegroundColor DarkYellow
        }
    }
}

function Start-WindowsUpdateAfterCleanup {
    foreach ($svc in 'bits', 'wuauserv') {
        try { Start-Service -Name $svc -ErrorAction Stop } catch { }
    }
}

function Invoke-Cleanup {
    Write-Host ""
    Write-Host "=== Cleanup folders ===" -ForegroundColor Cyan
    Write-Host ""

    $names = @($Folders.Keys)
    for ($i = 0; $i -lt $names.Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i + 1), $names[$i])
        Write-Host ("       {0}" -f $Folders[$names[$i]]) -ForegroundColor DarkGray
    }
    Write-Host ("  [A] Tất cả")
    Write-Host ("  [0] Huỷ")
    Write-Host ""

    $sel = Read-Host "Chọn folder cần clean (vd: 1,3,5 hoặc A)"
    if ([string]::IsNullOrWhiteSpace($sel) -or $sel -eq '0') {
        Write-Host "Đã huỷ." -ForegroundColor DarkYellow
        return
    }

    if ($sel -match '^\s*[Aa]\s*$') {
        $picked = $names
    }
    else {
        $picked = @()
        foreach ($tok in ($sel -split '[,\s]+')) {
            if ($tok -match '^\d+$') {
                $idx = [int]$tok - 1
                if ($idx -ge 0 -and $idx -lt $names.Count) {
                    $picked += $names[$idx]
                }
            }
        }
        $picked = $picked | Select-Object -Unique
    }

    if (-not $picked -or $picked.Count -eq 0) {
        Write-Host "Không có lựa chọn hợp lệ." -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "Sẽ clean:" -ForegroundColor Cyan
    foreach ($n in $picked) { Write-Host ("  - {0}  ({1})" -f $n, $Folders[$n]) }
    $confirm = Read-Host "Xác nhận? (y/N)"
    if ($confirm -notmatch '^[Yy]') {
        Write-Host "Đã huỷ." -ForegroundColor DarkYellow
        return
    }

    $needsAdmin = $picked | Where-Object {
        $_ -in @('Windows.old', 'Windows Temp', 'SoftwareDistribution\Download', 'Windows Prefetch')
    }
    if ($needsAdmin -and -not (Test-IsAdmin)) {
        Write-Host ""
        Write-Host "CẢNH BÁO: Một số mục cần quyền Administrator. Một phần file có thể không xoá được." -ForegroundColor Yellow
        Write-Host ""
    }

    $stoppedWU = $false
    if ($picked -contains 'SoftwareDistribution\Download' -and (Test-IsAdmin)) {
        Stop-WindowsUpdateForCleanup
        $stoppedWU = $true
    }

    $results = @()
    foreach ($n in $picked) {
        $deleteRoot = ($n -eq 'Windows.old')
        $results += Clear-FolderContents -Name $n -Path $Folders[$n] -DeleteRoot:$deleteRoot
    }

    if ($stoppedWU) { Start-WindowsUpdateAfterCleanup }

    $totalFreed = ($results | Measure-Object -Property Freed -Sum).Sum
    Write-Host ""
    Write-Host ("Tổng giải phóng: {0}" -f (Format-Size $totalFreed)) -ForegroundColor Green
    Write-Host ""
}

function Open-DiskCleanup {
    Write-Host ""
    Write-Host "Đang mở Disk Cleanup..." -ForegroundColor Cyan
    try {
        Start-Process -FilePath 'cleanmgr.exe' -ErrorAction Stop
    }
    catch {
        Write-Host ("Không mở được cleanmgr.exe: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }
}

function Clear-RecycleBinAll {
    Write-Host ""
    Write-Host "=== Empty Recycle Bin ===" -ForegroundColor Cyan
    $confirm = Read-Host "Xác nhận xoá toàn bộ Recycle Bin? (y/N)"
    if ($confirm -notmatch '^[Yy]') {
        Write-Host "Đã huỷ." -ForegroundColor DarkYellow
        return
    }
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Host "Recycle Bin đã được làm trống." -ForegroundColor Green
    }
    catch {
        Write-Host ("Lỗi: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }
}

function Invoke-ComponentStoreCleanup {
    Write-Host ""
    Write-Host "=== Component Store Cleanup (DISM) ===" -ForegroundColor Cyan
    if (-not (Test-IsAdmin)) {
        Write-Host "Cần quyền Administrator để chạy DISM. Bỏ qua." -ForegroundColor Red
        return
    }
    Write-Host "Lưu ý: thao tác này có thể mất vài phút và sẽ xoá vĩnh viễn các bản update cũ." -ForegroundColor Yellow
    $confirm = Read-Host "Tiếp tục? (y/N)"
    if ($confirm -notmatch '^[Yy]') {
        Write-Host "Đã huỷ." -ForegroundColor DarkYellow
        return
    }
    try {
        & dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
        Write-Host ""
        Write-Host ("DISM hoàn tất (exit code = {0})." -f $LASTEXITCODE) -ForegroundColor Green
    }
    catch {
        Write-Host ("Lỗi DISM: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }
}

function Show-Menu {
    Clear-Host
    $admin = if (Test-IsAdmin) { "Administrator" } else { "User (không có quyền admin)" }
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ("        {0}" -f $Title) -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ("  Phiên: {0}" -f $admin) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  1. Phân tích size các folder"
    Write-Host "  2. Cleanup folder (chọn từng cái hoặc tất cả)"
    Write-Host "  3. Mở Disk Cleanup (cleanmgr)"
    Write-Host "  4. Empty Recycle Bin"
    Write-Host "  5. Component Store Cleanup (DISM)"
    Write-Host "  6. Thoát"
    Write-Host ""
}

# ---------- Main loop ----------
do {
    Show-Menu
    $choice = Read-Host "Chọn (1-6)"
    switch ($choice) {
        '1' { Show-FolderSizes }
        '2' { Invoke-Cleanup }
        '3' { Open-DiskCleanup }
        '4' { Clear-RecycleBinAll }
        '5' { Invoke-ComponentStoreCleanup }
        '6' { Write-Host "Bye."; break }
        default { Write-Host "Lựa chọn không hợp lệ." -ForegroundColor Red }
    }
    if ($choice -ne '6') {
        Write-Host ""
        $null = Read-Host "Nhấn Enter để quay lại menu"
    }
} while ($choice -ne '6')
