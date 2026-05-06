# Free Space

A small interactive Windows cleanup tool written in PowerShell and shipped as a signed `FreeSpace.exe`. It analyzes the size of common system / user folders, cleans the ones you choose, and exposes a few built-in Windows cleanup hooks (Disk Cleanup, Recycle Bin, DISM Component Store).

The menu is bilingual: it starts in **English** by default, and you can switch to **Tieng Viet** at any time from the menu.

## Features

- Folder size analysis (sortable, total at the bottom)
- Selective folder cleanup (pick one, several, or all)
- Targets common space hogs:
  - `NVIDIA DXCache`
  - `Windows.old`
  - `User Temp` (`%TEMP%`)
  - `Windows Temp` (`%WinDir%\Temp`)
  - `SoftwareDistribution\Download` (Windows Update cache)
  - `Windows Prefetch`
  - `Downloads`
- One-click access to:
  - `cleanmgr.exe` (Disk Cleanup)
  - Empty Recycle Bin
  - `DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase`
- Stops `wuauserv` / `bits` before clearing the Windows Update download cache and starts them again afterwards
- Uses `takeown` / `icacls` to remove protected `Windows.old` content
- English / Vietnamese language switch from the menu

## Requirements

- Windows 10 / 11
- PowerShell 5.1 or newer (built into Windows)
- **Administrator privileges** are required for full functionality (`Windows.old`, `Windows Temp`, `SoftwareDistribution\Download`, `Windows Prefetch`, DISM). The script still runs as a normal user, but admin-only items will be skipped or fail to delete locked files.

## Usage

### Run the signed EXE

Download `FreeSpace.exe` from the [Releases](../../releases) page and double-click it (Windows will prompt for elevation because the manifest requests admin).

### Run the PowerShell script directly

```powershell
powershell -ExecutionPolicy Bypass -File .\Cleanup-Menu.ps1
```

Optional parameters:

```powershell
# Start in Vietnamese
powershell -ExecutionPolicy Bypass -File .\Cleanup-Menu.ps1 -Language vi

# Custom window title
powershell -ExecutionPolicy Bypass -File .\Cleanup-Menu.ps1 -Title 'My Cleanup'
```

### Menu

```
1. Analyze folder sizes
2. Cleanup folder (select individual or all)
3. Open Disk Cleanup (cleanmgr)
4. Empty Recycle Bin
5. Component Store Cleanup (DISM)
6. Switch language (English / Tieng Viet)
7. Exit
```

For option 2, type a comma-separated list of folder numbers (e.g. `1,3,5`) or `A` to select all. The script asks for confirmation before deleting anything.

## Building from source

The build pipeline turns `Cleanup-Menu.ps1` into a signed `FreeSpace.exe` using [`ps2exe`](https://github.com/MScholtes/PS2EXE).

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build.ps1
```

What it does:

1. Compiles the `.ps1` into an `.exe` with the icon, version metadata, and an embedded admin manifest (`-RequireAdmin`).
2. Signs the `.exe` with the self-signed cert whose thumbprint is in `cert\.cert-thumbprint.txt` (skipped if the file is missing or the cert is not in `Cert:\CurrentUser\My`).
3. Verifies the resulting Authenticode signature.

Edit the `$Meta` hashtable at the top of `tools\build.ps1` to change the displayed product name, author, version, etc. The `-Version` parameter overrides the value in `$Meta` (used by CI).

To create or recreate the local signing certificate, see `tools\recreate-cert.ps1`.

## Releases

Pushing a tag matching `v*` (e.g. `v1.2.3`) triggers `.github/workflows/release.yml`, which builds `FreeSpace.exe` on `windows-latest`, attaches it as a build artifact, and creates a GitHub Release with auto-generated notes.

## Project layout

```
Cleanup-Menu.ps1            # main interactive script (bilingual)
FreeSpace.exe               # built artifact (gitignored)
favicon.ico                 # icon embedded into the EXE
tools\build.ps1             # ps2exe build + sign pipeline
tools\recreate-cert.ps1     # helper to (re)create the self-signed cert
cert\nongdandev.cer         # public cert
cert\.cert-thumbprint.txt   # local thumbprint (gitignored)
.github\workflows\release.yml # CI: tag-driven build + release
```

## Safety notes

- The script always asks for confirmation before deleting anything.
- `Downloads` is included in the folder list because it is a frequent space hog, but be careful — review what is in it before cleaning.
- DISM `/ResetBase` permanently removes superseded Windows Update components and prevents uninstalling the updates that produced them. This is intentional and irreversible.
- Cleaning `SoftwareDistribution\Download` briefly stops `Windows Update` and `BITS`; they are restarted automatically afterwards.

## License

No license file is included yet. Treat the code as "all rights reserved" until one is added.
