```powershell
#Requires -Version 5.1

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "        AIO WINDOWS SETUP" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 1. INSTALL / BOOTSTRAP WINGET
# ============================================================

$WingetScriptUrl = "https://github.com/Zigsaw07/AIO-Script/raw/refs/heads/main/winget.ps1"

Write-Host "[1/2] Installing / checking WinGet..." -ForegroundColor Yellow
Write-Host "URL: $WingetScriptUrl" -ForegroundColor DarkGray

try {
    $WingetScript = Invoke-RestMethod -Uri $WingetScriptUrl -ErrorAction Stop

    if ([string]::IsNullOrWhiteSpace($WingetScript)) {
        throw "Downloaded WinGet script is empty."
    }

    Write-Host "WinGet script downloaded successfully." -ForegroundColor Green
    Write-Host "Executing WinGet bootstrapper..." -ForegroundColor Cyan

    Invoke-Expression $WingetScript

    Write-Host "WinGet bootstrapper finished." -ForegroundColor Green
}
catch {
    Write-Host "Failed to download or execute WinGet script." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}

# ============================================================
# 2. DOWNLOAD AND RUN RAR.EXE
# ============================================================

function DownloadAndRun-Executable {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $TempFilePath = $null

    try {
        $TempFilePath = Join-Path `
            ([System.IO.Path]::GetTempPath()) `
            ([System.IO.Path]::GetRandomFileName() + ".exe")

        Write-Host ""
        Write-Host "Downloading:" -ForegroundColor Cyan
        Write-Host $Url -ForegroundColor DarkGray
        Write-Host "Destination: $TempFilePath" -ForegroundColor DarkGray

        Invoke-WebRequest `
            -Uri $Url `
            -OutFile $TempFilePath `
            -UseBasicParsing `
            -ErrorAction Stop

        Write-Host "Download complete." -ForegroundColor Green

        try {
            Unblock-File -Path $TempFilePath -ErrorAction SilentlyContinue
        }
        catch {
            # Ignore if Unblock-File is unavailable/not required
        }

        Write-Host "Starting executable with Administrator privileges..." -ForegroundColor Cyan

        $Process = Start-Process `
            -FilePath $TempFilePath `
            -Verb RunAs `
            -Wait `
            -PassThru

        Write-Host ""
        Write-Host "Process finished." -ForegroundColor Green
        Write-Host "Exit Code: $($Process.ExitCode)" -ForegroundColor Cyan
    }
    catch {
        Write-Host ""
        Write-Host "Failed to download or run executable." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
    finally {
        if ($TempFilePath -and (Test-Path $TempFilePath)) {
            Remove-Item $TempFilePath -Force -ErrorAction SilentlyContinue
            Write-Host "Temporary file removed." -ForegroundColor DarkGray
        }
    }
}

$RarUrl = "https://github.com/Zigsaw07/office2024/raw/main/RAR.exe"

Write-Host ""
Write-Host "[2/2] Running RAR installer..." -ForegroundColor Yellow

DownloadAndRun-Executable -Url $RarUrl

# ============================================================
# COMPLETE
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "          AIO SETUP COMPLETED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
```
