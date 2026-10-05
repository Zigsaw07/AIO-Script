```powershell
#Requires -Version 5.1

# ============================================================
# Windows 10 / Windows 11 Application Installer
# WinGet Bootstrapper
# PowerShell 5.1 Compatible
#
# Fix:
# - Waits for WinGet registration after installation
# - Detects WinGet through App Installer package
# - Refreshes PATH
# - Does NOT use msstore source
# - Continues directly to application installation
# ============================================================

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$Apps = @(
    "Google.Chrome",
    "RARLab.WinRAR",
    "7zip.7zip",
    "VideoLAN.VLC",
    "DucFabulous.UltraViewer"
)

# ============================================================
# FUNCTIONS
# ============================================================

function Refresh-Path {

    $MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $UserPath    = [Environment]::GetEnvironmentVariable("Path", "User")

    $env:Path = ""

    if ($MachinePath) {
        $env:Path = $MachinePath
    }

    if ($UserPath) {

        if ($env:Path) {
            $env:Path += ";"
        }

        $env:Path += $UserPath
    }

    $WindowsApps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"

    if (Test-Path $WindowsApps) {

        if ($env:Path -notlike "*$WindowsApps*") {
            $env:Path += ";$WindowsApps"
        }
    }
}


# ============================================================
# FIND WINGET
# ============================================================

function Get-WinGetPath {

    Refresh-Path

    # --------------------------------------------------------
    # 1. Check normal PATH
    # --------------------------------------------------------

    $Command = Get-Command "winget.exe" -ErrorAction SilentlyContinue

    if ($Command) {
        return $Command.Source
    }


    # --------------------------------------------------------
    # 2. Check WindowsApps alias
    # --------------------------------------------------------

    $WindowsApps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"

    $Winget = Join-Path $WindowsApps "winget.exe"

    if (Test-Path $Winget) {
        return $Winget
    }


    # --------------------------------------------------------
    # 3. Check Microsoft App Installer package
    # --------------------------------------------------------

    try {

        $AppInstaller = Get-AppxPackage `
            -Name "Microsoft.DesktopAppInstaller" `
            -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if ($AppInstaller) {

            $PackageWinget = Join-Path `
                $AppInstaller.InstallLocation `
                "winget.exe"

            if (Test-Path $PackageWinget) {

                return $PackageWinget
            }
        }
    }
    catch {
    }


    # --------------------------------------------------------
    # 4. Search WindowsApps
    # --------------------------------------------------------

    $PackagePath = "$env:ProgramFiles\WindowsApps"

    if (Test-Path $PackagePath) {

        try {

            $Found = Get-ChildItem `
                -Path $PackagePath `
                -Filter "winget.exe" `
                -Recurse `
                -ErrorAction SilentlyContinue |
                Select-Object -First 1

            if ($Found) {
                return $Found.FullName
            }
        }
        catch {
        }
    }


    return $null
}


# ============================================================
# WAIT FOR WINGET
# ============================================================

function Wait-ForWinGet {

    param (
        [int]$TimeoutSeconds = 60
    )

    Write-Host ""
    Write-Host "Waiting for WinGet registration..." -ForegroundColor Cyan

    $StartTime = Get-Date

    while (((Get-Date) - $StartTime).TotalSeconds -lt $TimeoutSeconds) {

        $Path = Get-WinGetPath

        if ($Path) {

            Write-Host ""
            Write-Host "WinGet detected!" -ForegroundColor Green
            Write-Host "Location: $Path" -ForegroundColor Gray

            return $Path
        }

        Write-Host "." -NoNewline -ForegroundColor DarkGray

        Start-Sleep -Seconds 2
    }

    Write-Host ""

    return $null
}


# ============================================================
# INSTALL WINGET
# ============================================================

function Install-WinGet {

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " WinGet Bootstrapper" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""


    # --------------------------------------------------------
    # Check existing WinGet
    # --------------------------------------------------------

    $ExistingWinGet = Get-WinGetPath

    if ($ExistingWinGet) {

        Write-Host "WinGet already installed." -ForegroundColor Green
        Write-Host "Location: $ExistingWinGet" -ForegroundColor Gray

        return $ExistingWinGet
    }


    Write-Host "WinGet not detected." -ForegroundColor Yellow
    Write-Host "Proceeding with installation..." -ForegroundColor Cyan
    Write-Host ""


    # --------------------------------------------------------
    # Administrator Check
    # --------------------------------------------------------

    $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $CurrentPrincipal = New-Object `
        Security.Principal.WindowsPrincipal($CurrentIdentity)

    $IsAdmin = $CurrentPrincipal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )


    if ($IsAdmin) {

        $InstallScope = "AllUsers"

        Write-Host "Administrator privileges detected." -ForegroundColor Green
        Write-Host "Installation scope: AllUsers" -ForegroundColor Green
    }
    else {

        $InstallScope = "CurrentUser"

        Write-Host "WARNING: Not running as Administrator." -ForegroundColor Yellow
        Write-Host "Installation scope: CurrentUser" -ForegroundColor Yellow
    }


    Write-Host ""


    # --------------------------------------------------------
    # Install dependencies
    # --------------------------------------------------------

    try {

        # ----------------------------------------------------
        # NuGet
        # ----------------------------------------------------

        Write-Host "Ensuring NuGet Package Provider..." -ForegroundColor Cyan

        Install-PackageProvider `
            -Name NuGet `
            -Force `
            -Confirm:$false `
            -ErrorAction Stop |
            Out-Null

        Write-Host "NuGet ready." -ForegroundColor Green


        # ----------------------------------------------------
        # Microsoft.WinGet.Client
        # ----------------------------------------------------

        Write-Host ""
        Write-Host "Installing Microsoft.WinGet.Client..." -ForegroundColor Cyan

        Install-Module `
            -Name Microsoft.WinGet.Client `
            -Repository PSGallery `
            -Force `
            -Confirm:$false `
            -AllowClobber `
            -Scope $InstallScope `
            -ErrorAction Stop |
            Out-Null

        Write-Host "Microsoft.WinGet.Client installed." -ForegroundColor Green


        # ----------------------------------------------------
        # Bootstrap WinGet
        # ----------------------------------------------------

        if ($IsAdmin) {

            Write-Host ""
            Write-Host "Bootstrapping / repairing WinGet..." -ForegroundColor Cyan

            Repair-WinGetPackageManager -AllUsers

            Write-Host ""
            Write-Host "WinGet bootstrap command completed." -ForegroundColor Green
        }
        else {

            Write-Host ""
            Write-Host "Administrator privileges are required for AllUsers repair." -ForegroundColor Yellow
            Write-Host "WinGet registration may require an elevated PowerShell session." -ForegroundColor Yellow
        }

    }
    catch {

        Write-Host ""
        Write-Host "WinGet bootstrap error:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }


    # --------------------------------------------------------
    # IMPORTANT:
    # Give App Installer time to register WinGet
    # --------------------------------------------------------

    $WingetPath = Wait-ForWinGet -TimeoutSeconds 60

    if ($WingetPath) {

        return $WingetPath
    }


    # --------------------------------------------------------
    # One more PATH refresh
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Performing final WinGet detection..." -ForegroundColor Cyan

    Refresh-Path

    Start-Sleep -Seconds 3

    $WingetPath = Get-WinGetPath

    if ($WingetPath) {

        return $WingetPath
    }


    return $null
}


# ============================================================
# START
# ============================================================

Clear-Host

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Windows Application Installer" -ForegroundColor Cyan
Write-Host " Windows 10 / Windows 11" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""


# ============================================================
# OPERATING SYSTEM INFORMATION
# ============================================================

try {

    $OS = Get-CimInstance Win32_OperatingSystem

    Write-Host "Operating System: $($OS.Caption)"
    Write-Host "Version:          $($OS.Version)"
}
catch {

    Write-Host "Unable to read operating system information." -ForegroundColor Yellow
}

Write-Host ""


# ============================================================
# CHECK / INSTALL WINGET
# ============================================================

Write-Host "Checking for WinGet..." -ForegroundColor Cyan
Write-Host ""

$WingetPath = Get-WinGetPath

if (-not $WingetPath) {

    $WingetPath = Install-WinGet
}


# ============================================================
# FINAL WINGET CHECK
# ============================================================

if (-not $WingetPath) {

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host " ERROR: WinGet unavailable" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""

    Write-Host "WinGet installation was attempted, but winget.exe" -ForegroundColor Yellow
    Write-Host "could not be detected in this PowerShell session." -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  - Windows LTSC / Store-less installation"
    Write-Host "  - App Installer components are missing"
    Write-Host "  - WinGet registration failed"
    Write-Host "  - Administrator privileges are required"
    Write-Host ""

    Read-Host "Press Enter to exit"

    exit 1
}


# ============================================================
# ADD WINGET DIRECTORY TO PATH
# ============================================================

$WingetDirectory = Split-Path $WingetPath -Parent

if ($env:Path -notlike "*$WingetDirectory*") {

    $env:Path += ";$WingetDirectory"
}


Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " WinGet is available" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

Write-Host "Path: $WingetPath" -ForegroundColor Gray


# ============================================================
# WINGET VERSION
# ============================================================

try {

    $WingetVersion = & $WingetPath --version 2>&1

    Write-Host "WinGet version: $WingetVersion" -ForegroundColor Green
}
catch {

    Write-Host "Unable to determine WinGet version." -ForegroundColor Yellow
}


# ============================================================
# INSTALL APPLICATIONS
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Installing Applications" -ForegroundColor Cyan
Write-Host " Source: winget" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""


$Failed = @()


foreach ($App in $Apps) {

    Write-Host "============================================" -ForegroundColor DarkGray
    Write-Host "Installing: $App" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor DarkGray


    try {

        & $WingetPath install `
            --id $App `
            --exact `
            --source winget `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements


        $ExitCode = $LASTEXITCODE


        if ($ExitCode -eq 0) {

            Write-Host ""
            Write-Host "SUCCESS: $App" -ForegroundColor Green
        }
        else {

            Write-Host ""
            Write-Host "FAILED: $App" -ForegroundColor Red
            Write-Host "Exit code: $ExitCode" -ForegroundColor Red

            $Failed += $App
        }

    }
    catch {

        Write-Host ""
        Write-Host "FAILED: $App" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow

        $Failed += $App
    }


    Write-Host ""
}


# ============================================================
# INSTALLATION SUMMARY
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Installation Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""


if ($Failed.Count -eq 0) {

    Write-Host "All applications installed successfully." -ForegroundColor Green
}
else {

    Write-Host "The following applications failed:" -ForegroundColor Yellow
    Write-Host ""

    foreach ($App in $Failed) {

        Write-Host "  - $App" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Run the script again to retry the failed applications." -ForegroundColor Yellow
}


Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " SETUP COMPLETED" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

Read-Host "Press Enter to exit"
```
