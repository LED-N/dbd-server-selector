# Ensure the script is running as administrator
$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$backupPath = "$hostsPath.bak"

# List of GameLift server regions to manage
$serverList = @(
    "us-east-2", "us-east-1", "us-west-1", "us-west-2",
    "ap-south-1", "ap-northeast-2", "ap-southeast-1", "ap-southeast-2",
    "ap-northeast-1", "ap-east-1", "ca-central-1",
    "eu-central-1", "eu-west-1", "eu-west-2", "sa-east-1"
)

# Readable display names for each region
$regionNames = @{
    "us-east-2"      = "US East (Ohio)"
    "us-east-1"      = "US East (Virginia)"
    "us-west-1"      = "US West (California)"
    "us-west-2"      = "US West (Oregon)"
    "ap-south-1"     = "Asia South (Mumbai)"
    "ap-northeast-2" = "Asia Northeast (Seoul)"
    "ap-southeast-1" = "Asia Southeast (Singapore)"
    "ap-southeast-2" = "Asia Pacific (Sydney)"
    "ap-northeast-1" = "Asia Northeast (Tokyo)"
    "ap-east-1"      = "Asia East (Hong Kong)"
    "ca-central-1"   = "Canada (Central)"
    "eu-central-1"   = "Europe (Frankfurt)"
    "eu-west-1"      = "Europe (Ireland)"
    "eu-west-2"      = "Europe (London)"
    "sa-east-1"      = "South America (São Paulo)"
}

function Get-RegionName($code) {
    if ($regionNames.ContainsKey($code)) { return $regionNames[$code] }
    return $code
}

# Load the hosts file
if (-not (Test-Path $hostsPath)) {
    Write-Host "❌ hosts file not found at $hostsPath"
    exit
}
$lines = Get-Content $hostsPath

# If the file doesn't contain any GameLift lines, append them
$gameliftPresent = $lines | Where-Object { $_ -match "gamelift-ping\." }
if (-not $gameliftPresent) {
    Write-Host "`n➕ No GameLift entries found. Adding default lines..."
    foreach ($code in $serverList) {
        $lines += "0.0.0.0 gamelift-ping.$code.api.aws"
    }
}

# Build region list for selection
$regionList = $serverList | ForEach-Object {
    [PSCustomObject]@{ Code = $_; Name = Get-RegionName $_ }
}

# Display the interactive menu
Write-Host "`n=== Dead by Daylight Server Selector ==="
for ($i = 0; $i -lt $regionList.Count; $i++) {
    Write-Host "$($i + 1). $($regionList[$i].Name) [$($regionList[$i].Code)]"
}
Write-Host "0. Reset (remove all GameLift entries)"

# Read user input
$selectionValide = $false
while (-not $selectionValide) {
    $choix = Read-Host "Enter server number(s) to allow (e.g. 12,13) or 0 to reset"
    if ([string]::IsNullOrWhiteSpace($choix)) { continue }

    if ($choix -eq "0") {
        $reset = $true
        $selectionValide = $true
        break
    }

    $tokens = $choix -split '[,\s]+' | Where-Object { $_ -match '^\d+$' }
    $choixNumeros = $tokens | ForEach-Object { [int]$_ } | Where-Object { $_ -ge 1 -and $_ -le $regionList.Count }

    if ($choixNumeros.Count -gt 0) {
        $reset = $false
        $selectionValide = $true
    } else {
        Write-Host "❌ Invalid selection. Try again."
    }
}

# Prepare summary for confirmation
if ($reset) {
    $actionDesc = "reset the hosts file (remove all GameLift entries)"
} else {
    $selectedCodes = $choixNumeros | ForEach-Object { $regionList[$_ - 1].Code }
    $selectedNames = $selectedCodes | ForEach-Object { Get-RegionName $_ }

    if ($selectedNames.Count -gt 1) {
        $last = $selectedNames[-1]
        $others = $selectedNames[0..($selectedNames.Count - 2)]
        $liste = ($others -join ", ") + " and " + $last
    } else {
        $liste = $selectedNames[0]
    }
    $actionDesc = "force matchmaking on $liste"
}

# Confirm the user's intention
$confirm = Read-Host "`nYou're about to $actionDesc. Continue? (Y/N)"
if ($confirm -notmatch '^(Y|y)$') {
    Write-Host "❌ Cancelled."
    exit
}

# Backup the original hosts file
Copy-Item -Path $hostsPath -Destination $backupPath -Force
Write-Host "💾 Backup created: $backupPath"

try {
    if ($reset) {
        # Remove all GameLift lines
        $lines = $lines | Where-Object { $_ -notmatch 'gamelift-ping\.' }
    } else {
        # Remove all previous GameLift lines
        $lines = $lines | Where-Object { $_ -notmatch 'gamelift-ping\.' }

        # Add new entries (block all except selected ones)
        foreach ($code in $serverList) {
            if ($selectedCodes -contains $code) {
                $lines += "# 0.0.0.0 gamelift-ping.$code.api.aws"
            } else {
                $lines += "0.0.0.0 gamelift-ping.$code.api.aws"
            }
        }
    }

    # Add short delay before write (prevents race conditions)
    Start-Sleep -Milliseconds 800

    # Write the file safely
    $lines | Out-File -FilePath $hostsPath -Encoding Default -Force

    # Ensure file wasn't wiped
    $check = Get-Content $hostsPath -ErrorAction Stop
    if ($check.Count -eq 0) { throw "hosts file is empty after write" }

    Write-Host "`n✅ hosts file updated successfully."
} catch {
    Write-Host "`n❌ Failed to update hosts file: $($_.Exception.Message)"
    Write-Host "🔁 Restoring backup..."
    Copy-Item -Path $backupPath -Destination $hostsPath -Force
    Write-Host "✅ Backup restored."
    exit
}

# Launch the game (unless reset)
if (-not $reset) {
    Write-Host "`n🚀 Launching Dead by Daylight..."
    Start-Process "steam://rungameid/381210"
}
