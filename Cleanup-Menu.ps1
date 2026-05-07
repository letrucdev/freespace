#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive cleanup menu for Windows system & user folders.
.DESCRIPTION
    Provides a menu to analyze sizes, clean specific folders, run Disk Cleanup,
    empty Recycle Bin, and run Component Store cleanup (DISM).
    Supports English (default) and Vietnamese — switch language from the menu.
.NOTES
    Run as Administrator for full functionality (Windows.old, Windows folders, DISM).
#>

[CmdletBinding()]
param(
    [string]$Title = 'Free Space',
    [ValidateSet('en', 'vi')]
    [string]$Language = 'en'
)

$ErrorActionPreference = 'Stop'

# Ensure non-ASCII output (Vietnamese) renders correctly in legacy consoles (PS 5.1 / cmd)
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding = [System.Text.UTF8Encoding]::new()
}
catch { }

try { $Host.UI.RawUI.WindowTitle = $Title } catch { }

# ---------- Language / strings ----------
$Script:Language = $Language

$Script:Strings = @{
    en = @{
        Scanning            = '  Scanning: {0} ...'
        NotExists           = '(not found)'
        Total               = 'Total: {0}'
        CleanupHeader       = '=== Cleanup folders ==='
        AllOption           = '  [A] All'
        CancelOption        = '  [0] Cancel'
        SelectFolders       = 'Select folder(s) to clean (e.g. 1,3,5 or A)'
        Cancelled           = 'Cancelled.'
        InvalidSelection    = 'No valid selection.'
        WillClean           = 'Will clean:'
        ConfirmYN           = 'Confirm? (y/N)'
        AdminWarning        = 'WARNING: Some items require Administrator privileges. Some files may not be deletable.'
        SkipNotFound        = '  [skip] {0}: not found ({1})'
        DeletingFolder      = '  Deleting folder: {0}'
        Cleaning            = '  Cleaning: {0}'
        ErrorPrefix         = '    Error: {0}'
        Freed               = '    -> Freed {0}'
        LockedSuffix        = ' ({0} items locked/in use, skipped)'
        StoppingService     = '  Stopping service: {0}'
        StopServiceFail     = '  Could not stop {0}: {1}'
        TotalFreed          = 'Total freed: {0}'
        OpeningDiskCleanup  = 'Opening Disk Cleanup...'
        DiskCleanupFail     = 'Could not open cleanmgr.exe: {0}'
        RecycleHeader       = '=== Empty Recycle Bin ==='
        RecycleConfirm      = 'Confirm emptying entire Recycle Bin? (y/N)'
        RecycleEmptied      = 'Recycle Bin has been emptied.'
        RecycleError        = 'Error: {0}'
        DismHeader          = '=== Component Store Cleanup (DISM) ==='
        DismNeedAdmin       = 'Administrator privileges required to run DISM. Skipping.'
        DismNote            = 'Note: this operation may take a few minutes and will permanently remove old updates.'
        DismContinue        = 'Continue? (y/N)'
        DismDone            = 'DISM completed (exit code = {0}).'
        DismError           = 'DISM error: {0}'
        SessionAdmin        = 'Administrator'
        SessionUser         = 'User (no admin privileges)'
        SessionLabel        = '  Session: {0}'
        LanguageLabel       = '  Language: English'
        Menu1               = '  1. Cleanup folder (analyze sizes & select individual or all)'
        Menu2               = '  2. Open Disk Cleanup (cleanmgr)'
        Menu3               = '  3. Empty Recycle Bin'
        Menu4               = '  4. Component Store Cleanup (DISM)'
        Menu5               = '  5. Switch language (English / Tieng Viet)'
        Menu6               = '  6. Exit'
        ChoosePrompt        = 'Choice (1-6)'
        InvalidChoice       = 'Invalid choice.'
        ReturnToMenu        = 'Press Enter to return to menu'
        LanguageSwitched    = 'Language switched to English.'
        Bye                 = 'Bye.'
    }
    vi = @{
        Scanning            = '  Dang quet: {0} ...'
        NotExists           = '(khong ton tai)'
        Total               = 'Tong: {0}'
        CleanupHeader       = '=== Cleanup folders ==='
        AllOption           = '  [A] Tat ca'
        CancelOption        = '  [0] Huy'
        SelectFolders       = 'Chon folder can clean (vd: 1,3,5 hoac A)'
        Cancelled           = 'Da huy.'
        InvalidSelection    = 'Khong co lua chon hop le.'
        WillClean           = 'Se clean:'
        ConfirmYN           = 'Xac nhan? (y/N)'
        AdminWarning        = 'CANH BAO: Mot so muc can quyen Administrator. Mot phan file co the khong xoa duoc.'
        SkipNotFound        = '  [skip] {0}: khong ton tai ({1})'
        DeletingFolder      = '  Dang xoa thu muc: {0}'
        Cleaning            = '  Dang don: {0}'
        ErrorPrefix         = '    Loi: {0}'
        Freed               = '    -> Giai phong {0}'
        LockedSuffix        = ' ({0} muc bi khoa/dang dung, bo qua)'
        StoppingService     = '  Stopping service: {0}'
        StopServiceFail     = '  Khong stop duoc {0}: {1}'
        TotalFreed          = 'Tong giai phong: {0}'
        OpeningDiskCleanup  = 'Dang mo Disk Cleanup...'
        DiskCleanupFail     = 'Khong mo duoc cleanmgr.exe: {0}'
        RecycleHeader       = '=== Empty Recycle Bin ==='
        RecycleConfirm      = 'Xac nhan xoa toan bo Recycle Bin? (y/N)'
        RecycleEmptied      = 'Recycle Bin da duoc lam trong.'
        RecycleError        = 'Loi: {0}'
        DismHeader          = '=== Component Store Cleanup (DISM) ==='
        DismNeedAdmin       = 'Can quyen Administrator de chay DISM. Bo qua.'
        DismNote            = 'Luu y: thao tac nay co the mat vai phut va se xoa vinh vien cac ban update cu.'
        DismContinue        = 'Tiep tuc? (y/N)'
        DismDone            = 'DISM hoan tat (exit code = {0}).'
        DismError           = 'Loi DISM: {0}'
        SessionAdmin        = 'Administrator'
        SessionUser         = 'User (khong co quyen admin)'
        SessionLabel        = '  Phien: {0}'
        LanguageLabel       = '  Ngon ngu: Tieng Viet'
        Menu1               = '  1. Cleanup folder (phan tich size & chon tung cai hoac tat ca)'
        Menu2               = '  2. Mo Disk Cleanup (cleanmgr)'
        Menu3               = '  3. Empty Recycle Bin'
        Menu4               = '  4. Component Store Cleanup (DISM)'
        Menu5               = '  5. Doi ngon ngu (English / Tieng Viet)'
        Menu6               = '  6. Thoat'
        ChoosePrompt        = 'Chon (1-6)'
        InvalidChoice       = 'Lua chon khong hop le.'
        ReturnToMenu        = 'Nhan Enter de quay lai menu'
        LanguageSwitched    = 'Da chuyen sang Tieng Viet.'
        Bye                 = 'Tam biet.'
    }
}

function Get-Str {
    param(
        [Parameter(Mandatory)][string]$Key,
        [object[]]$FormatArgs
    )
    $template = $Script:Strings[$Script:Language][$Key]
    if ($null -eq $template) { return $Key }
    if ($FormatArgs -and $FormatArgs.Count -gt 0) {
        return [string]::Format($template, $FormatArgs)
    }
    return $template
}

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

function Clear-FolderContents {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Path,
        [switch]$DeleteRoot   # if set, removes the folder itself (e.g. Windows.old)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host (Get-Str 'SkipNotFound' @($Name, $Path)) -ForegroundColor DarkYellow
        return [pscustomobject]@{ Name = $Name; Freed = 0; Errors = 0 }
    }

    $before = (Get-FolderSize -Path $Path).Bytes
    $errors = 0

    if ($DeleteRoot) {
        Write-Host (Get-Str 'DeletingFolder' @($Path)) -ForegroundColor Yellow
        try {
            # takeown + icacls helps remove protected Windows.old contents
            & takeown.exe /F $Path /R /D Y *> $null
            & icacls.exe  $Path /grant "*S-1-5-32-544:F" /T /C *> $null
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        }
        catch {
            $errors++
            Write-Host (Get-Str 'ErrorPrefix' @($_.Exception.Message)) -ForegroundColor Red
        }
    }
    else {
        Write-Host (Get-Str 'Cleaning' @($Path)) -ForegroundColor Yellow
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
    $freed = [Math]::Max([double]0, [double]($before - $after))

    $msg = (Get-Str 'Freed' @((Format-Size $freed)))
    if ($errors -gt 0) { $msg += (Get-Str 'LockedSuffix' @($errors)) }
    Write-Host $msg -ForegroundColor Green

    return [pscustomobject]@{ Name = $Name; Freed = $freed; Errors = $errors }
}

function Stop-WindowsUpdateForCleanup {
    # Best-effort: stop wuauserv/bits before clearing SoftwareDistribution\Download
    foreach ($svc in 'wuauserv', 'bits') {
        try {
            $s = Get-Service -Name $svc -ErrorAction Stop
            if ($s.Status -eq 'Running') {
                Write-Host (Get-Str 'StoppingService' @($svc)) -ForegroundColor DarkGray
                Stop-Service -Name $svc -Force -ErrorAction Stop
            }
        }
        catch {
            Write-Host (Get-Str 'StopServiceFail' @($svc, $_.Exception.Message)) -ForegroundColor DarkYellow
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
    Write-Host (Get-Str 'CleanupHeader') -ForegroundColor Cyan
    Write-Host ""

    $names = @($Folders.Keys)

    # Analyze sizes up front so user can see what's worth cleaning
    $sizes = @{}
    $totalBytes = 0.0
    foreach ($n in $names) {
        Write-Host (Get-Str 'Scanning' @($n)) -ForegroundColor DarkGray
        $info = Get-FolderSize -Path $Folders[$n]
        $sizes[$n] = $info
        $totalBytes += $info.Bytes
    }

    Write-Host ""
    for ($i = 0; $i -lt $names.Count; $i++) {
        $n = $names[$i]
        $info = $sizes[$n]
        $sizeText = if ($info.Exists) { Format-Size $info.Bytes } else { (Get-Str 'NotExists') }
        $filesText = if ($info.Exists) { "$($info.FileCount) files" } else { '' }
        Write-Host ("  [{0}] {1}" -f ($i + 1), $n) -NoNewline
        Write-Host ("  -  {0}  {1}" -f $sizeText, $filesText) -ForegroundColor Yellow
        Write-Host ("       {0}" -f $Folders[$n]) -ForegroundColor DarkGray
    }
    Write-Host (Get-Str 'AllOption')
    Write-Host (Get-Str 'CancelOption')
    Write-Host ""
    Write-Host (Get-Str 'Total' @((Format-Size $totalBytes))) -ForegroundColor Yellow
    Write-Host ""

    $sel = Read-Host (Get-Str 'SelectFolders')
    if ([string]::IsNullOrWhiteSpace($sel) -or $sel -eq '0') {
        Write-Host (Get-Str 'Cancelled') -ForegroundColor DarkYellow
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
        Write-Host (Get-Str 'InvalidSelection') -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host (Get-Str 'WillClean') -ForegroundColor Cyan
    foreach ($n in $picked) { Write-Host ("  - {0}  ({1})" -f $n, $Folders[$n]) }
    $confirm = Read-Host (Get-Str 'ConfirmYN')
    if ($confirm -notmatch '^[Yy]') {
        Write-Host (Get-Str 'Cancelled') -ForegroundColor DarkYellow
        return
    }

    $needsAdmin = $picked | Where-Object {
        $_ -in @('Windows.old', 'Windows Temp', 'SoftwareDistribution\Download', 'Windows Prefetch')
    }
    if ($needsAdmin -and -not (Test-IsAdmin)) {
        Write-Host ""
        Write-Host (Get-Str 'AdminWarning') -ForegroundColor Yellow
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
    Write-Host (Get-Str 'TotalFreed' @((Format-Size $totalFreed))) -ForegroundColor Green
    Write-Host ""
}

function Open-DiskCleanup {
    Write-Host ""
    Write-Host (Get-Str 'OpeningDiskCleanup') -ForegroundColor Cyan
    try {
        Start-Process -FilePath 'cleanmgr.exe' -ErrorAction Stop
    }
    catch {
        Write-Host (Get-Str 'DiskCleanupFail' @($_.Exception.Message)) -ForegroundColor Red
    }
}

function Clear-RecycleBinAll {
    Write-Host ""
    Write-Host (Get-Str 'RecycleHeader') -ForegroundColor Cyan
    $confirm = Read-Host (Get-Str 'RecycleConfirm')
    if ($confirm -notmatch '^[Yy]') {
        Write-Host (Get-Str 'Cancelled') -ForegroundColor DarkYellow
        return
    }
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Host (Get-Str 'RecycleEmptied') -ForegroundColor Green
    }
    catch {
        Write-Host (Get-Str 'RecycleError' @($_.Exception.Message)) -ForegroundColor Red
    }
}

function Invoke-ComponentStoreCleanup {
    Write-Host ""
    Write-Host (Get-Str 'DismHeader') -ForegroundColor Cyan
    if (-not (Test-IsAdmin)) {
        Write-Host (Get-Str 'DismNeedAdmin') -ForegroundColor Red
        return
    }
    Write-Host (Get-Str 'DismNote') -ForegroundColor Yellow
    $confirm = Read-Host (Get-Str 'DismContinue')
    if ($confirm -notmatch '^[Yy]') {
        Write-Host (Get-Str 'Cancelled') -ForegroundColor DarkYellow
        return
    }
    try {
        & dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
        Write-Host ""
        Write-Host (Get-Str 'DismDone' @($LASTEXITCODE)) -ForegroundColor Green
    }
    catch {
        Write-Host (Get-Str 'DismError' @($_.Exception.Message)) -ForegroundColor Red
    }
}

function Switch-Language {
    if ($Script:Language -eq 'en') { $Script:Language = 'vi' } else { $Script:Language = 'en' }
    Write-Host ""
    Write-Host (Get-Str 'LanguageSwitched') -ForegroundColor Green
}

function Show-Menu {
    Clear-Host
    $admin = if (Test-IsAdmin) { (Get-Str 'SessionAdmin') } else { (Get-Str 'SessionUser') }
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ("        {0}" -f $Title) -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host (Get-Str 'SessionLabel' @($admin)) -ForegroundColor DarkGray
    Write-Host (Get-Str 'LanguageLabel') -ForegroundColor DarkGray
    Write-Host ""
    Write-Host (Get-Str 'Menu1')
    Write-Host (Get-Str 'Menu2')
    Write-Host (Get-Str 'Menu3')
    Write-Host (Get-Str 'Menu4')
    Write-Host (Get-Str 'Menu5')
    Write-Host (Get-Str 'Menu6')
    Write-Host ""
}

# ---------- Main loop ----------
do {
    Show-Menu
    $choice = Read-Host (Get-Str 'ChoosePrompt')
    switch ($choice) {
        '1' { Invoke-Cleanup }
        '2' { Open-DiskCleanup }
        '3' { Clear-RecycleBinAll }
        '4' { Invoke-ComponentStoreCleanup }
        '5' { Switch-Language }
        '6' { Write-Host (Get-Str 'Bye'); break }
        default { Write-Host (Get-Str 'InvalidChoice') -ForegroundColor Red }
    }
    if ($choice -ne '6') {
        Write-Host ""
        $null = Read-Host (Get-Str 'ReturnToMenu')
    }
} while ($choice -ne '6')
