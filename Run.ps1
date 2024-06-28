function DownloadAndRun-Executable {
    param (
        [string] $url
    )

    try {
        # Create a temporary file path with the .exe extension
        $tempFilePath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + ".exe")
        
        Write-Output "Downloading executable from $url to $tempFilePath"
        
        # Download the executable from the provided URL
        Invoke-WebRequest -Uri $url -OutFile $tempFilePath -ErrorAction Stop
        
        Write-Output "Download complete. Unblocking file."

        # Unblock the downloaded file to prevent security warnings
        Unblock-File -Path $tempFilePath -ErrorAction Stop

        Write-Output "Unblocked file. Running executable with admin privileges."

        # Run the executable with administrator rights
        $process = Start-Process -FilePath $tempFilePath -Verb RunAs -PassThru -Wait

        # Log the exit code
        Write-Output "Executable completed with exit code: $($process.ExitCode)"

        # Clean up: Delete the temporary file after execution
        Remove-Item -Path $tempFilePath -Force
        
        Write-Output "Temporary file deleted."
    }
    catch {
        Write-Error "Failed to download or run executable from $url. Error: $_"
    }
}

function Execute-RemoteScript {
    param (
        [string] $url
    )

    try {
        Write-Output "Executing remote script from $url"
        
        # Fetch and execute the remote script
        Invoke-WebRequest -Uri $url | Invoke-Expression
    }
    catch {
        Write-Error "Failed to execute remote script from $url. Error: $_"
    }
}

# Function to check if the script is running with admin privileges
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check for admin privileges
if (-not (Test-Admin)) {
    Write-Error "This script requires running with administrator privileges."
    exit
}

# URLs of the executables to download and run
$urls = @(
    'https://github.com/Zigsaw07/AIO-Script/raw/main/MSO-365.exe',
    'https://github.com/Zigsaw07/AIO-Script/raw/main/Ninite.exe',
    'https://github.com/Zigsaw07/AIO-Script/raw/main/RAR.exe'
)

# URL of the remote script to execute
$remoteScriptUrl = 'https://get.activated.win'

# Loop through each URL and start a job to execute the download and run function
$jobs = @()
foreach ($url in $urls) {
    $jobs += Start-Job -ScriptBlock {
        param ($url)
        DownloadAndRun-Executable -url $url
    } -ArgumentList $url
}

# Wait for all jobs to complete
$jobs | ForEach-Object { 
    Write-Output "Waiting for job ID $($_.Id) to complete..."
    Receive-Job -Job $_ -Wait 
}

# Execute the remote script
Execute-RemoteScript -url $remoteScriptUrl

# Clean up completed jobs
$jobs | ForEach-Object { Remove-Job -Job $_ }
