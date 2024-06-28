$ErrorActionPreference = "Stop"
# Enable TLSv1.2 for compatibility with older clients
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Define an array of download URLs
$DownloadURLs = @(
    "https://github.com/Zigsaw07/office2024/raw/main/Setup1.exe",
    "https://github.com/Zigsaw07/office2024/raw/main/Setup2.exe",
    "https://github.com/Zigsaw07/office2024/raw/main/Setup3.exe"
)

# Loop through each URL
foreach ($DownloadURL in $DownloadURLs) {
    $FilePath = "$env:TEMP\" + [System.IO.Path]::GetFileName($DownloadURL)

    try {
        # Check if the file already exists
        if (-not (Test-Path $FilePath)) {
            # Download the file
            Write-Host "Downloading $DownloadURL..."
            Invoke-WebRequest -Uri $DownloadURL -OutFile $FilePath -UseBasicParsing

            # Check if download was successful
            if (-not (Test-Path $FilePath)) {
                throw "Download failed for $DownloadURL."
            }
            Write-Host "Download completed."
        } else {
            Write-Host "File already exists ($FilePath). Skipping download."
        }

        # Execute the downloaded file
        Write-Host "Executing $FilePath..."
        Start-Process -FilePath $FilePath -Wait
        Write-Host "$FilePath execution completed."
    }
    catch {
        Write-Error "An error occurred: $_"
    }
}
