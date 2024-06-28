# Function to download and run executable with admin rights
function DownloadAndRun-Executable {
    param (
        [string] $url
    )

    try {
        # Create a temporary file path
        $tempFilePath = [System.IO.Path]::GetTempFileName()

        # Download the executable from the provided URL
        Invoke-WebRequest -Uri $url -OutFile $tempFilePath -ErrorAction Stop

        # Unblock the downloaded file to prevent security warnings
        Unblock-File -Path $tempFilePath -ErrorAction Stop

        # Check if execution policy needs to be changed
        $currentExecutionPolicy = Get-ExecutionPolicy -Scope Process
        if ($currentExecutionPolicy -ne 'Bypass') {
            Set-ExecutionPolicy -Scope Process Bypass -Force
        }

        # Run the executable with administrator rights
        Start-Process -FilePath $tempFilePath -Verb RunAs -Wait

        # Clean up: Delete the temporary file after execution
        Remove-Item -Path $tempFilePath -Force
    }
    catch {
        Write-Error "Failed to download or run executable from $url. Error: $_"
    }
}

# Function to execute remote script
function Execute-RemoteScript {
    param (
        [string] $url
    )

    try {
        # Fetch and execute the remote script
        irm $url | iex
    }
    catch {
        Write-Error "Failed to execute remote script from $url. Error: $_"
    }
}

# URLs of the executables to download and run
$urls = @(
    'https://github.com/Zigsaw07/office2024/raw/main/MSO-365.exe',
    'https://github.com/Zigsaw07/office2024/raw/main/Ninite.exe',
    'https://github.com/Zigsaw07/office2024/raw/main/RAR.exe'
)

# URL of the remote script to execute
$remoteScriptUrl = 'https://get.activated.win'

# Loop through each URL and execute the download and run function
foreach ($url in $urls) {
    DownloadAndRun-Executable -url $url
}

# Execute the remote script
Execute-RemoteScript -url $remoteScriptUrl
