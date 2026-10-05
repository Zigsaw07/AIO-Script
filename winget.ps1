
#Requires -Version 5.1

# ============================================================
# Windows 10 / Windows 11 Application Installer V2
# WinGet Bootstrapper
# PowerShell 5.1 Compatible
#
# Features:
# - Automatic WinGet bootstrap
# - Waits for WinGet registration
# - No recursive WindowsApps scanning
# - Tests WinGet before application installation
# - Uses winget source only
# - Automatic application retry
# - Detects already installed applications
# - No msstore source update
# ============================================================

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"


# ============================================================
# APPLICATION LIST
# ============================================================

$Apps = @(
    "Google.Chrome",
    "RARLab.WinRAR",
    "7zip.7zip",
    "VideoLAN.VLC",
    "DucFabulous.UltraViewer"
)


# ============================================================
# REFRESH PATH
# ============================================================

function Refresh-Path {

    try {

        $MachinePath = [Environment]::GetEnvironmentVariable(
            "Path",
            "Machine"
        )

        $UserPath = [Environment]::GetEnvironmentVariable(
            "Path",
            "User"
        )

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


        # WindowsApps alias

        $WindowsApps = Join-Path `
            $env:LOCALAPPDATA `
            "Microsoft\WindowsApps"


        if (Test-Path $WindowsApps) {

            if ($env:Path -notlike "*$WindowsApps*") {

                if ($env:Path) {
                    $env:Path += ";"
                }

                $env:Path += $WindowsApps
            }
        }

    }
    catch {
    }
}


# ============================================================
# FIND WINGET
# ============================================================

function Get-WinGetPath {

    Refresh-Path


    # --------------------------------------------------------
    # 1. PATH
    # --------------------------------------------------------

    try {

        $Command = Get-Command `
            "winget.exe" `
            -ErrorAction SilentlyContinue


        if ($Command) {

            if (Test-Path $Command.Source) {

                return $Command.Source
            }
        }

    }
    catch {
    }


    # --------------------------------------------------------
    # 2. WindowsApps alias
    # --------------------------------------------------------

    try {

        $WindowsApps = Join-Path `
            $env:LOCALAPPDATA `
            "Microsoft\WindowsApps"


        $WingetAlias = Join-Path `
            $WindowsApps `
            "winget.exe"


        if (Test-Path $WingetAlias) {

            return $WingetAlias
        }

    }
    catch {
    }


    # --------------------------------------------------------
    # 3. Microsoft Desktop App Installer package
    # --------------------------------------------------------

    try {

        $AppInstaller = Get-AppxPackage `
            -Name "Microsoft.DesktopAppInstaller" `
            -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending |
            Select-Object -First 1


        if ($AppInstaller) {

            $InstallLocation = $AppInstaller.InstallLocation


            if ($InstallLocation) {

                $PackageWinget = Join-Path `
                    $InstallLocation `
                    "winget.exe"


                if (Test-Path $PackageWinget) {

                    return $PackageWinget
                }
            }
        }

    }
    catch {
    }


    return $null
}


# ============================================================
# TEST WINGET
# ============================================================

function Test-WinGet {

    param (
        [string]$WingetPath
    )


    if (-not $WingetPath) {
        return $false
    }


    if (-not (Test-Path $WingetPath)) {
        return $false
    }


    try {

        $Output = & $WingetPath --version 2>&1

        $ExitCode = $LASTEXITCODE


        if ($ExitCode -eq 0) {

            if ($Output) {

                Write-Host ""
                Write-Host "WinGet version: $Output" -ForegroundColor Green
            }

            return $true
        }

    }
    catch {
    }


    return $false
}


# ============================================================
# WAIT FOR WINGET
# ============================================================

function Wait-ForWinGet {

    param (
        [int]$TimeoutSeconds = 90
    )


    Write-Host ""
    Write-Host "Waiting for WinGet registration..." -ForegroundColor Cyan


    $StartTime = Get-Date


    while (
        ((Get-Date) - $StartTime).TotalSeconds -lt $TimeoutSeconds
    ) {


        $Path = Get-WinGetPath


        if ($Path) {

            Write-Host ""
            Write-Host "WinGet executable detected." -ForegroundColor Green
            Write-Host "Location: $Path" -ForegroundColor Gray


            # Test that it actually works

            if (Test-WinGet -WingetPath $Path) {

                return $Path
            }
        }


        Write-Host "." -NoNewline -ForegroundColor DarkGray

        Start-Sleep -Seconds 2
    }


    Write-Host ""

    return $null
}


# ============================================================
# ADMIN CHECK
# ============================================================

function Test-Administrator {

    try {

        $Identity = `
            [Security.Principal.WindowsIdentity]::GetCurrent()


        $Principal = New-Object `
            Security.Principal.WindowsPrincipal($Identity)


        return $Principal.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )

    }
    catch {

        return $false
    }
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

    $ExistingPath = Get-WinGetPath


    if ($ExistingPath) {

        Write-Host "WinGet executable found." -ForegroundColor Green
        Write-Host "Location: $ExistingPath" -ForegroundColor Gray


        if (Test-WinGet -WingetPath $ExistingPath) {

            return $ExistingPath
        }


        Write-Host ""
        Write-Host "WinGet was found but is not responding correctly." -ForegroundColor Yellow
    }


    # --------------------------------------------------------
    # Administrator check
    # --------------------------------------------------------

    $IsAdmin = Test-Administrator


    if ($IsAdmin) {

        Write-Host "Administrator privileges detected." -ForegroundColor Green
        $InstallScope = "AllUsers"

    }
    else {

        Write-Host ""
        Write-Host "WARNING: PowerShell is not running as Administrator." -ForegroundColor Yellow
        Write-Host "WinGet bootstrap may require elevation." -ForegroundColor Yellow

        $InstallScope = "CurrentUser"
    }


    Write-Host ""
    Write-Host "Installing WinGet components..." -ForegroundColor Cyan
    Write-Host ""


    # --------------------------------------------------------
    # Install NuGet
    # --------------------------------------------------------

    try {

        Write-Host "Checking NuGet Package Provider..." -ForegroundColor Cyan


        Install-PackageProvider `
            -Name NuGet `
            -Force `
            -Confirm:$false `
            -ErrorAction Stop |
            Out-Null


        Write-Host "NuGet ready." -ForegroundColor Green

    }
    catch {

        Write-Host "NuGet installation failed:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }


    # --------------------------------------------------------
    # Install Microsoft.WinGet.Client
    # --------------------------------------------------------

    try {

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


        Write-Host "Microsoft.WinGet.Client ready." -ForegroundColor Green

    }
    catch {

        Write-Host ""
        Write-Host "Microsoft.WinGet.Client installation failed:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }


    # --------------------------------------------------------
    # Repair / bootstrap
    # --------------------------------------------------------

    if ($IsAdmin) {

        try {

            Write-Host ""
            Write-Host "Bootstrapping WinGet..." -ForegroundColor Cyan


            Repair-WinGetPackageManager -AllUsers


            Write-Host ""
            Write-Host "WinGet bootstrap completed." -ForegroundColor Green

        }
        catch {

            Write-Host ""
            Write-Host "WinGet repair returned an error:" -ForegroundColor Yellow
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }

    }
    else {

        Write-Host ""
        Write-Host "Skipping AllUsers WinGet repair." -ForegroundColor Yellow
        Write-Host "Please run this installer as Administrator for best results." -ForegroundColor Yellow
    }


    # --------------------------------------------------------
    # Wait for registration
    # --------------------------------------------------------

    $WingetPath = Wait-ForWinGet -TimeoutSeconds 90


    if ($WingetPath) {

        return $WingetPath
    }


    # --------------------------------------------------------
    # Final detection
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Performing final WinGet detection..." -ForegroundColor Cyan


    Refresh-Path

    Start-Sleep -Seconds 3


    $WingetPath = Get-WinGetPath


    if ($WingetPath) {

        if (Test-WinGet -WingetPath $WingetPath) {

            return $WingetPath
        }
    }


    return $null
}


# ============================================================
# INSTALL ONE APPLICATION
# ============================================================

function Install-Application {

    param (
        [string]$WingetPath,
        [string]$AppId
    )


    Write-Host ""
    Write-Host "============================================" -ForegroundColor DarkGray
    Write-Host "Installing: $AppId" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor DarkGray


    try {

        & $WingetPath install `
            --id $AppId `
            --exact `
            --source winget `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements


        $ExitCode = $LASTEXITCODE


        if ($ExitCode -eq 0) {

            Write-Host ""
            Write-Host "SUCCESS: $AppId" -ForegroundColor Green

            return $true
        }


        # ----------------------------------------------------
        # 0x8A150014 = package already installed
        # ----------------------------------------------------

        if ($ExitCode -eq -1978335212) {

            Write-Host ""
            Write-Host "Already installed: $AppId" -ForegroundColor Green

            return $true
        }


        Write-Host ""
        Write-Host "FAILED: $AppId" -ForegroundColor Red
        Write-Host "Exit code: $ExitCode" -ForegroundColor Red

        return $false

    }
    catch {

        Write-Host ""
        Write-Host "FAILED: $AppId" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow

        return $false
    }
}


# ============================================================
# START
# ============================================================

Clear-Host


Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Windows Application Installer V2" -ForegroundColor Cyan
Write-Host " Windows 10 / Windows 11" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""


# ============================================================
# OPERATING SYSTEM
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
# ADMIN STATUS
# ============================================================

if (Test-Administrator) {

    Write-Host "Administrator: YES" -ForegroundColor Green

}
else {

    Write-Host "Administrator: NO" -ForegroundColor Yellow
    Write-Host "Recommendation: Run PowerShell as Administrator." -ForegroundColor Yellow
}


Write-Host ""


# ============================================================
# CHECK / INSTALL WINGET
# ============================================================

Write-Host "Checking for WinGet..." -ForegroundColor Cyan


$WingetPath = Get-WinGetPath


if ($WingetPath) {

    Write-Host ""
    Write-Host "WinGet executable found." -ForegroundColor Green
    Write-Host "Location: $WingetPath" -ForegroundColor Gray


    if (-not (Test-WinGet -WingetPath $WingetPath)) {

        Write-Host ""
        Write-Host "WinGet executable is not functioning." -ForegroundColor Yellow
        Write-Host "Attempting WinGet bootstrap..." -ForegroundColor Cyan


        $WingetPath = Install-WinGet
    }

}
else {

    Write-Host ""
    Write-Host "WinGet not detected." -ForegroundColor Yellow
    Write-Host "Starting WinGet bootstrap..." -ForegroundColor Cyan


    $WingetPath = Install-WinGet
}


# ============================================================
# FINAL WINGET VALIDATION
# ============================================================

if (-not $WingetPath) {

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host " ERROR: WinGet unavailable" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""


    Write-Host "WinGet could not be installed or detected." -ForegroundColor Yellow
    Write-Host ""


    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  - Windows LTSC / Store-less Windows"
    Write-Host "  - App Installer is missing"
    Write-Host "  - WinGet registration failed"
    Write-Host "  - PowerShell is not elevated"
    Write-Host "  - Windows package dependencies are missing"
    Write-Host ""


    Read-Host "Press Enter to exit"

    exit 1
}


if (-not (Test-WinGet -WingetPath $WingetPath)) {

    Write-Host ""
    Write-Host "ERROR: WinGet was located but failed validation." -ForegroundColor Red
    Write-Host ""

    Read-Host "Press Enter to exit"

    exit 1
}


# ============================================================
# ADD WINGET DIRECTORY TO PATH
# ============================================================

$WingetDirectory = Split-Path `
    $WingetPath `
    -Parent


if ($env:Path -notlike "*$WingetDirectory*") {

    $env:Path += ";$WingetDirectory"
}


Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " WinGet Ready" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""


# ============================================================
# INSTALL APPLICATIONS
# ============================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Installing Applications" -ForegroundColor Cyan
Write-Host " Source: winget" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""


$Failed = @()


foreach ($App in $Apps) {

    $Success = Install-Application `
        -WingetPath $WingetPath `
        -AppId $App


    if (-not $Success) {

        $Failed += $App
    }


    Start-Sleep -Seconds 2
}


# ============================================================
# RETRY FAILED APPLICATIONS
# ============================================================

if ($Failed.Count -gt 0) {

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host " Retrying Failed Applications" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""


    $RetryFailed = @()


    foreach ($App in $Failed) {

        Write-Host "Retrying: $App" -ForegroundColor Cyan


        $Success = Install-Application `
            -WingetPath $WingetPath `
            -AppId $App


        if (-not $Success) {

            $RetryFailed += $App
        }


        Start-Sleep -Seconds 2
    }


    $Failed = $RetryFailed
}


# ============================================================
# FINAL SUMMARY
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Installation Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""


if ($Failed.Count -eq 0) {

    Write-Host "All applications installed successfully." -ForegroundColor Green
    Write-Host ""

    foreach ($App in $Apps) {

        Write-Host "  [OK] $App" -ForegroundColor Green
    }

}
else {

    Write-Host "Some applications could not be installed:" -ForegroundColor Yellow
    Write-Host ""


    foreach ($App in $Failed) {

        Write-Host "  [FAILED] $App" -ForegroundColor Red
    }


    Write-Host ""
    Write-Host "You can run the installer again to retry them." -ForegroundColor Yellow
}


# ============================================================
# COMPLETE
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " SETUP COMPLETED" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

Read-Host "Press Enter to exit"

