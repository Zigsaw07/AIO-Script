
#Requires -Version 5.1

# ============================================================
# Windows 10 / Windows 11 Application Installer
# WinGet Bootstrapper
# PowerShell 5.1 Compatible
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
# Functions
# ============================================================

function Refresh-Path {

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [Environment]::GetEnvironmentVariable("Path", "User")

    $env:Path = ""

    if ($machinePath) {
        $env:Path = $machinePath
    }

    if ($userPath) {

        if ($env:Path) {
            $env:Path += ";"
        }

        $env:Path += $userPath
    }

    $WindowsApps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"

    if (Test-Path $WindowsApps) {

        if ($env:Path -notlike "*$WindowsApps*") {
            $env:Path += ";$WindowsApps"
        }
    }
}

function Get-WinGetPath {

    Refresh-Path

    # --------------------------------------------------------
    # Check PATH
    # --------------------------------------------------------

    $Command = Get-Command "winget.exe" -ErrorAction SilentlyContinue

    if ($Command) {
        return $Command.Source
    }

    # --------------------------------------------------------
    # Check WindowsApps
    # --------------------------------------------------------

    $WindowsApps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"

    $Winget = Join-Path $WindowsApps "winget.exe"

    if (Test-Path $Winget) {
        return $Winget
    }

    # --------------------------------------------------------
    # Search WindowsApps package directory
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

    $CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)

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

    try {

        # ----------------------------------------------------
        # NuGet
        # ----------------------------------------------------

        Write-Host "Ensuring NuGet Package Provider..." -ForegroundColor Cyan

        Install-PackageProvider `
            -Name NuGet `
            -Force `
            -Confirm:$false `
            -ErrorAction Stop | Out-Null

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
            -ErrorAction Stop | Out-Null

        Write-Host "Microsoft.WinGet.Client installed." -ForegroundColor Green

        # ----------------------------------------------------
        # Bootstrap WinGet
        # ----------------------------------------------------

        if ($IsAdmin) {

            Write-Host ""
            Write-Host "Bootstrapping / repairing WinGet..." -ForegroundColor Cyan

            Repair-WinGetPackageManager -AllUsers

            Write-Host "WinGet bootstrap completed." -ForegroundColor Green
        }
        else {

            Write-Host ""
            Write-Host "Skipping AllUsers repair because Administrator privileges are required." -ForegroundColor Yellow
        }

    }
    catch {

        Write-Host ""
        Write-Host "WinGet bootstrap error:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }

    # --------------------------------------------------------
    # Refresh environment
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Refreshing environment..." -ForegroundColor Cyan

    Refresh-Path

    Start-Sleep -Seconds 5

    # --------------------------------------------------------
    # Locate WinGet
    # --------------------------------------------------------

    $WingetPath = Get-WinGetPath

    if ($WingetPath) {

        Write-Host ""
        Write-Host "WinGet detected successfully." -ForegroundColor Green
        Write-Host "Location: $WingetPath" -ForegroundColor Gray

        return $WingetPath
    }

    Write-Host ""
    Write-Host "WinGet could not be located after installation." -ForegroundColor Yellow

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
# Operating System Information
# ============================================================

$OS = Get-CimInstance Win32_OperatingSystem

Write-Host "Operating System: $($OS.Caption)"
Write-Host "Version:          $($OS.Version)"
Write-Host ""

# ============================================================
# Check / Install WinGet
# ============================================================

Write-Host "Checking for WinGet..." -ForegroundColor Cyan
Write-Host ""

$WingetPath = Get-WinGetPath

if (-not $WingetPath) {

    $WingetPath = Install-WinGet
}

# ------------------------------------------------------------
# Final WinGet check
# ------------------------------------------------------------

if (-not $WingetPath) {

    Refresh-Path

    Start-Sleep -Seconds 3

    $WingetPath = Get-WinGetPath
}

if (-not $WingetPath) {

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host " ERROR: WinGet unavailable" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""

    Write-Host "WinGet bootstrap completed, but winget.exe could not be located." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  - Windows LTSC / Store-less installation"
    Write-Host "  - App Installer components are missing"
    Write-Host "  - WinGet registration is incomplete"
    Write-Host "  - Administrator privileges are required"
    Write-Host ""

    Read-Host "Press Enter to exit"

    exit 1
}

# ============================================================
# Add WinGet Directory to PATH
# ============================================================

$WingetDirectory = Split-Path $WingetPath -Parent

if ($env:Path -notlike "*$WingetDirectory*") {

    $env:Path += ";$WingetDirectory"
}

Write-Host ""
Write-Host "WinGet is available." -ForegroundColor Green
Write-Host "Path: $WingetPath" -ForegroundColor Gray

# ============================================================
# WinGet Version
# ============================================================

Write-Host ""

try {

    $WingetVersion = & $WingetPath --version

    Write-Host "WinGet version: $WingetVersion" -ForegroundColor Green
}
catch {

    Write-Host "Unable to determine WinGet version." -ForegroundColor Yellow
}

# ============================================================
# Install Applications
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

    & $WingetPath install `
        --id $App `
        --exact `
        --source winget `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements

    $ExitCode = $LASTEXITCODE

    if ($ExitCode -eq 0) {

        Write-Host "SUCCESS: $App" -ForegroundColor Green
    }
    else {

        Write-Host "FAILED: $App" -ForegroundColor Red
        Write-Host "Exit code: $ExitCode" -ForegroundColor Red

        $Failed += $App
    }

    Write-Host ""
}

# ============================================================
# Installation Summary
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
Read-Host "Press Enter to exit"
