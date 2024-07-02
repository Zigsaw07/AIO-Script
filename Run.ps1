# Function to handle errors
function Handle-Error {
    param (
        [string]$errorMessage
    )
    Write-Host "Error: $errorMessage"
    # Additional error handling logic can go here
    exit 1
}

# Function to extract file IDs from Google Drive folder link
function Get-GoogleDriveFileIdsFromLink {
    param (
        [string]$FolderLink
    )

    try {
        # Use web scraping to extract file IDs from the folder link
        $webRequest = Invoke-WebRequest -Uri $FolderLink -ErrorAction Stop
        $html = $webRequest.Content

        # Example regex to extract file IDs from the HTML content
        $fileIds = [regex]::Matches($html, 'https://drive.google.com/uc\?id=([a-zA-Z0-9_-]+)') | ForEach-Object { $_.Groups[1].Value }

        if ($fileIds.Count -eq 0) {
            Handle-Error -errorMessage "No file IDs found in the folder link."
        }

        return $fileIds
    }
    catch {
        Handle-Error -errorMessage "Failed to extract file IDs: $_"
    }
}

# Function to download files from Google Drive using file IDs
function Download-GoogleDriveFiles {
    param (
        [string]$FolderLink,
        [string]$DestinationFolder
    )

    try {
        # Get file IDs from the Google Drive folder link
        $fileIds = Get-GoogleDriveFileIdsFromLink -FolderLink $FolderLink

        # Create a destination folder if it doesn't exist
        if (-not (Test-Path -Path $DestinationFolder)) {
            New-Item -ItemType Directory -Path $DestinationFolder | Out-Null
        }

        # Download each file based on its ID
        foreach ($fileId in $fileIds) {
            $url = "https://drive.google.com/drive/folders/1jAftNXs2Yv7ZvcdcmO8DiwRIxNh1igQw?usp=drive_link"
            $outputPath = Join-Path -Path $DestinationFolder -ChildPath "file_$fileId.ext"  # Modify the output path as needed

            Invoke-WebRequest -Uri $url -OutFile $outputPath -ErrorAction Stop
            Write-Host "File with ID $fileId downloaded to $outputPath"
        }
    }
    catch {
        Handle-Error -errorMessage "Failed to download files: $_"
    }
}

# Function to download and execute autoplay.exe from a folder
function DownloadAndExecuteAutoplay {
    param (
        [string]$FolderLink
    )

    try {
        # Define a temporary folder path
        $tempFolder = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
        
        # Download files from Google Drive folder to temporary folder
        Download-GoogleDriveFiles -FolderLink $FolderLink -DestinationFolder $tempFolder

        # Find and execute autoplay.exe within the downloaded folder
        $autoplayPath = Get-ChildItem -Path $tempFolder -Filter "autoplay.exe" -Recurse | Select-Object -ExpandProperty FullName -First 1

        if (-not $autoplayPath) {
            Handle-Error -errorMessage "autoplay.exe not found in the downloaded folder."
        }

        # Run autoplay.exe with admin privileges
        Start-Process -FilePath $autoplayPath -Verb RunAs -Wait
    }
    catch {
        Handle-Error -errorMessage "Failed to download and execute autoplay.exe: $_"
    }
}

# Main script execution
try {
    $folderLink = "https://drive.google.com/drive/folders/your_folder_id"  # Replace with your Google Drive folder link
    DownloadAndExecuteAutoplay -FolderLink $folderLink
}
catch {
    Handle-Error -errorMessage "Main script execution failed: $_"
}
