# Vérifier et obtenir les privilèges administrateur
$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# Path du fichier hosts
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"

# Lire le fichier hosts
if (-not (Test-Path $hostsPath)) {
    Write-Host "Erreur : fichier hosts introuvable à l'emplacement $hostsPath"
    exit
}
$lines = Get-Content -Path $hostsPath

# Dictionnaire des noms de région pour affichage
$regionNames = @{
    "us-east-2"    = "US East (Ohio)"
    "us-east-1"    = "US East (N. Virginia)"
    "us-west-1"    = "US West (California)"
    "us-west-2"    = "US West (Oregon)"
    "ap-south-1"   = "Asia South (Mumbai)"
    "ap-northeast-2" = "Asia Northeast (Seoul)"
    "ap-southeast-1" = "Asia Southeast (Singapore)"
    "ap-southeast-2" = "Asia Pacific (Sydney)"
    "ap-northeast-1" = "Asia Northeast (Tokyo)"
    "ap-east-1"    = "Asia East (Hong Kong)"
    "ca-central-1" = "Canada (Central)"
    "eu-central-1" = "Europe (Frankfurt)"
    "eu-west-1"    = "Europe (Ireland)"
    "eu-west-2"    = "Europe (London)"
    "sa-east-1"    = "South America (São Paulo)"
}

# Fonction utilitaire pour obtenir un nom lisible
function Get-RegionName($code) {
    if ($regionNames.ContainsKey($code)) { return $regionNames[$code] }
    return $code
}

# Extraire la liste des serveurs (codes de région) présents dans hosts
$regionList = @()
foreach ($line in $lines) {
    if ($line -match 'gamelift-ping') {
        if ($line -match '0\.0\.0\.0\s+([^ ]+)') {
            $hostname = $matches[1]
            if ($hostname -match 'gamelift-ping\.([^.]+)\.api\.aws') {
                $code = $matches[1]
                $displayName = Get-RegionName $code
                $regionList += [PSCustomObject]@{ Code = $code; Name = $displayName }
            }
        }
    }
}

# Afficher le menu
Write-Host "`n=== Dead by Daylight Server Selector ==="
$index = 1
foreach ($region in $regionList) {
    Write-Host ("$index. $($region.Name) [$($region.Code)]")
    $index++
}
Write-Host "0. Reset (Unblock all servers)"

# Demander le choix
$selectionValide = $false
$choix = ""
while (-not $selectionValide) {
    $choix = Read-Host "Enter server number(s) to allow (ex: 1,3) or 0 to reset"
    if ([string]::IsNullOrWhiteSpace($choix)) {
        Write-Host "Invalid input."
        continue
    }
    if ($choix -match '^[0]$') {
        $selectionValide = $true
        $choixNumeros = @()
        $reset = $true
        break
    }
    $tokens = $choix -split '[,\s]+' | Where-Object { $_ -match '^\d+$' }
    if (-not $tokens) {
        Write-Host "Invalid input."
        continue
    }
    $choixNumeros = $tokens | ForEach-Object { [int]$_ }
    $choixNumeros = $choixNumeros | Where-Object { $_ -ge 1 -and $_ -le $regionList.Count }
    if (-not $choixNumeros) {
        Write-Host "No valid selection."
        continue
    }
    $choixNumeros = $choixNumeros | Sort-Object -Unique
    $reset = $false
    $selectionValide = $true
}

# Confirmation
if ($reset) {
    $actionDesc = "reset the hosts file (unblock all servers)"
} else {
    $selectedCodes = $choixNumeros | ForEach-Object { $regionList[$_-1].Code }
    $selectedNames = $selectedCodes | ForEach-Object { Get-RegionName $_ }

    if ($selectedNames.Count -gt 1) {
        $last = $selectedNames[-1]
        $others = $selectedNames[0..($selectedNames.Count - 2)]
        $listeServeurs = ($others -join ", ") + " and " + $last
    } else {
        $listeServeurs = $selectedNames[0]
    }
    $actionDesc = "force matchmaking on $listeServeurs"
}

$confirmation = Read-Host "You're about to $actionDesc. Continue? (Y/N)"
if ($confirmation -notmatch '^(?:Y|y)$') {
    Write-Host "Cancelled."
    exit
}

# Modifier le fichier hosts
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'gamelift-ping') {
        if ($lines[$i] -match 'gamelift-ping\.([^.]+)\.api\.aws') {
            $codeLigne = $matches[1]
            if ($reset -or ($selectedCodes -contains $codeLigne)) {
                # Autoriser => commenter
                $lines[$i] = $lines[$i] -replace '^[\s#]*', ''
                $lines[$i] = "# $($lines[$i])"
            } else {
                # Bloquer => décommenter
                $lines[$i] = $lines[$i] -replace '^[\s#]*', ''
            }
        }
    }
}

# Enregistrer
Set-Content -Path $hostsPath -Value $lines -Encoding Default

Write-Host "`n✅ hosts file updated successfully."

if (-not $reset) {
    Write-Host "🚀 Launching Dead by Daylight..."
    Start-Process "steam://rungameid/381210"
}
