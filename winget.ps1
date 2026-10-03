# ============================================================
# Windows 10 / Windows 11 Application Installer
#
# Checks for WinGet.
# If WinGet is missing, attempts to install Microsoft App
# Installer, which provides WinGet.
# ============================================================

$ErrorActionPreference = "Continue"

$Apps = @(
    "Google.Chrome",
    "RARLab.WinRAR",
    "7zip.7zip",
    "DucFabulous.UltraViewer",
    "VideoLan.VLC"
)

# ------------------------------------------------------------
# Helper: Check whether WinGet exists
# ------------------------------------------------------------

function Test-WinGet {
    $Winget = Get-Command "winget.exe" -ErrorAction SilentlyContinue

    if ($Winget) {
        return $true
    }

    return $false
}

# ------------------------------------------------------------
# Header
# ------------------------------------------------------------

Clear-Host

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Windows Application Installer" -ForegroundColor Cyan
Write-Host " Windows 10 / Windows 11" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$OS = Get-CimInstance Win32_OperatingSystem

Write-Host "Operating System: $($OS.Caption)"
Write-Host "Version:          $($OS.Version)"
Write-Host ""

# ------------------------------------------------------------
# Check WinGet
# ------------------------------------------------------------

Write-Host "Checking for WinGet..." -ForegroundColor Cyan

if (Test-WinGet) {

    Write-Host "WinGet is already installed." -ForegroundColor Green

}
else {

    Write-Host "WinGet was not found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Attempting to install Microsoft App Installer..." -ForegroundColor Cyan
    Write-Host ""

    # --------------------------------------------------------
    # Method 1: Microsoft Store / Winget package registration
    # --------------------------------------------------------

    $AppInstaller = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" `
        -ErrorAction SilentlyContinue

    if ($AppInstaller) {

        Write-Host "Microsoft App Installer is installed." -ForegroundColor Yellow
        Write-Host "Attempting to register it..." -ForegroundColor Cyan

        try {

            Add-AppxPackage -Register `
                "$($AppInstaller.InstallLocation)\AppxManifest.xml" `
                -DisableDevelopmentMode `
                -ErrorAction Stop

        }
        catch {

            Write-Host "Could not register App Installer." -ForegroundColor Yellow
        }
    }

    # --------------------------------------------------------
    # Method 2: Install App Installer through Microsoft Store
    # --------------------------------------------------------

    if (-not (Test-WinGet)) {

        Write-Host ""
        Write-Host "Opening Microsoft Store App Installer page..." -ForegroundColor Cyan

        try {

            Start-Process `
                "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"

            Write-Host ""
            Write-Host "Please install/update 'App Installer' from the Microsoft Store." `
                -ForegroundColor Yellow

            Write-Host ""
            Read-Host "Press Enter after App Installer has finished installing"

        }
        catch {

            Write-Host "Could not open Microsoft Store." -ForegroundColor Red
        }
    }

    # --------------------------------------------------------
    # Check again
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Checking for WinGet again..." -ForegroundColor Cyan

    # Refresh PATH for the current PowerShell session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") +
                ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")

    Start-Sleep -Seconds 2

    if (-not (Test-WinGet)) {

        Write-Host ""
        Write-Host "ERROR: WinGet is still not available." -ForegroundColor Red
        Write-Host ""
        Write-Host "Install/update Microsoft App Installer and run this script again."
        Write-Host ""

        exit 1
    }

    Write-Host "WinGet is now available." -ForegroundColor Green
}

# ------------------------------------------------------------
# Display WinGet version
# ------------------------------------------------------------

Write-Host ""

try {

    $WingetVersion = winget --version

    Write-Host "WinGet version: $WingetVersion" -ForegroundColor Green

}
catch {

    Write-Host "Unable to determine WinGet version." -ForegroundColor Yellow
}

Write-Host ""

# ------------------------------------------------------------
# Update WinGet sources
# ------------------------------------------------------------

Write-Host "Updating WinGet sources..." -ForegroundColor Cyan

winget source update

Write-Host ""

# ------------------------------------------------------------
# Install applications
# ------------------------------------------------------------

$Failed = @()

foreach ($App in $Apps) {

    Write-Host "============================================" -ForegroundColor DarkGray
    Write-Host "Installing: $App" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor DarkGray

    winget install `
        --id $App `
        --exact `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements

    if ($LASTEXITCODE -eq 0) {

        Write-Host "SUCCESS: $App" -ForegroundColor Green

    }
    else {

        Write-Host "FAILED: $App" -ForegroundColor Red
        Write-Host "Exit code: $LASTEXITCODE" -ForegroundColor Red

        $Failed += $App
    }

    Write-Host ""
}

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Installation Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($Failed.Count -eq 0) {

    Write-Host "All applications installed successfully." -ForegroundColor Green

}
else {

    Write-Host "Some applications failed to install:" -ForegroundColor Yellow
    Write-Host ""

    foreach ($App in $Failed) {
        Write-Host "  - $App" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Run the script again to retry the failed applications." `
        -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Press Enter to exit"
