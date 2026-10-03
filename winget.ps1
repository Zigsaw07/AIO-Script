#Requires -Version 5.1

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "Checking for WinGet..." -ForegroundColor Cyan

# Check whether WinGet is already installed
$winget = Get-Command winget.exe -ErrorAction SilentlyContinue

if (-not $winget) {
    Write-Host "WinGet not found. Installing WinGet PowerShell module..." -ForegroundColor Yellow

    try {
        # Install NuGet provider
        Install-PackageProvider -Name NuGet -Force | Out-Null

        # Install Microsoft WinGet client module
        Install-Module `
            -Name Microsoft.WinGet.Client `
            -Force `
            -Repository PSGallery `
            -AllowClobber | Out-Null

        Write-Host "Using Repair-WinGetPackageManager to bootstrap WinGet..." -ForegroundColor Yellow

        Repair-WinGetPackageManager -AllUsers

        Write-Host "WinGet bootstrap completed." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to install/repair WinGet: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    # Refresh PATH / locate WinGet again
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue

    if (-not $winget) {
        Write-Host "WinGet is still unavailable. Restart PowerShell and run this script again." -ForegroundColor Red
        exit 1
    }
}

Write-Host "WinGet found: $($winget.Source)" -ForegroundColor Green

# Applications to install
$apps = @(
    "Google.Chrome",
    "VideoLAN.VLC",
    "DucFabulous.UltraViewer",
    "RARLab.WinRAR",
    "7zip.7zip"
)

foreach ($app in $apps) {
    Write-Host "`nInstalling $app ..." -ForegroundColor Cyan

    try {
        & winget install --id=$app -e --silent `
            --accept-source-agreements `
            --accept-package-agreements

        if ($LASTEXITCODE -eq 0) {
            Write-Host "$app installed successfully." -ForegroundColor Green
        }
        else {
            Write-Host "$app returned exit code $LASTEXITCODE." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Failed to install $app : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nInstallation process completed." -ForegroundColor Green
