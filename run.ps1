function Get-WindowsProductKey {
    param (
        [string]$KeyPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion",
        [string]$ValueName = "DigitalProductId"
    )

    # Read the registry value
    $digitalProductId = (Get-ItemProperty -Path $KeyPath -Name $ValueName).DigitalProductId

    # Check if the registry value exists
    if ($null -eq $digitalProductId) {
        Write-Output "No product key found in the registry."
        return $null
    }

    # Decode the product key from the registry binary data
    $key = [byte[]]$digitalProductId[52..66]
    $keyChars = "BCDFGHJKMPQRTVWXY2346789"
    $productKey = ""

    for ($i = 0; $i -lt 25; $i++) {
        $current = 0
        for ($j = 0; $j -lt 14; $j++) {
            $current = $current * 256 -bxor $key[$j]
            $key[$j] = [math]::Floor($current / 24)
            $current = $current % 24
        }
        $productKey = $keyChars[$current] + $productKey
    }

    $productKey = $productKey.Insert(5, "-").Insert(11, "-").Insert(17, "-").Insert(23, "-")
    Write-Output "Windows Product Key: $productKey"
    return $productKey
}

function Activate-Windows {
    param (
        [string]$ProductKey
    )

    if (-not $ProductKey) {
        Write-Output "No valid product key provided. Activation aborted."
        return
    }

    # Set the product key
    slmgr.vbs /ipk $ProductKey

    # Attempt activation
    slmgr.vbs /ato

    # Optionally, check the activation status
    slmgr.vbs /dli
}

# Extract the product key
$productKey = Get-WindowsProductKey

# Check if product key was found and activate if available
if ($productKey) {
    Activate-Windows -ProductKey $productKey
} else {
    # Fallback command if no product key is found
    Write-Output "No product key found. Running fallback command..."
    irm get.activated.win | iex
}
