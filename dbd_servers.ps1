# Vérifier et obtenir les privilèges administrateur
$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Relance le script en mode administrateur si nécessaire
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
    "us-east-2"    = "États-Unis Est (Ohio)"
    "us-east-1"    = "États-Unis Est (Virginie du Nord)"
    "us-west-1"    = "États-Unis Ouest (Californie du Nord)"
    "us-west-2"    = "États-Unis Ouest (Oregon)"
    "ap-south-1"   = "Asie du Sud (Mumbai)"
    "ap-northeast-2" = "Asie du Nord-Est (Séoul)"
    "ap-southeast-1" = "Asie du Sud-Est (Singapour)"
    "ap-southeast-2" = "Asie-Pacifique (Sydney)"
    "ap-northeast-1" = "Asie du Nord-Est (Tokyo)"
    "ap-east-1"    = "Asie de l'Est (Hong Kong)"
    "ca-central-1" = "Canada (Centre)"
    "eu-central-1" = "Europe (Francfort)"
    "eu-west-1"    = "Europe (Irlande)"
    "eu-west-2"    = "Europe (Londres)"
    "sa-east-1"    = "Amérique du Sud (São Paulo)"
}

# Extraire la liste des serveurs (codes de région) présents dans hosts
$regionList = @()
foreach ($line in $lines) {
    if ($line -match 'gamelift-ping') {
        # Enlever un éventuel commentaire initial '#' et extraire le nom d'hôte
        if ($line -match '0\.0\.0\.0\s+([^ ]+)') {
            $hostname = $matches[1]   # ex: "gamelift-ping.eu-central-1.api.aws"
            if ($hostname -match 'gamelift-ping\.([^.]+)\.api\.aws') {
                $code = $matches[1]   # ex: "eu-central-1"
            } else {
                continue
            }
        } else {
            continue
        }
        # Récupérer le nom lisible ou à défaut le code lui-même
        $displayName = $regionNames.GetValue($code, $code)
        # Conserver l'objet (code + nom) dans la liste
        $regionList += [PSCustomObject]@{ Code = $code; Name = $displayName }
    }
}

# Afficher le menu des serveurs
Write-Host "`n=== Sélection du serveur Dead by Daylight ==="
$index = 1
foreach ($region in $regionList) {
    Write-Host ("$index. $($region.Name) [$($region.Code)]")
    $index++
}
Write-Host ("0. Réinitialiser (aucun serveur prioritaire - tout autoriser)")

# Demander le choix de l'utilisateur
$selectionValide = $false
$choix = ""
while (-not $selectionValide) {
    $choix = Read-Host "Entrez le(s) numéro(s) des serveurs à prioriser (ex: 1,3) ou 0 pour réinitialiser"
    if ([string]::IsNullOrWhiteSpace($choix)) {
        Write-Host "Veuillez saisir un choix (ou 0 pour tout autoriser)."
        continue
    }
    if ($choix -match '^[0]$') {
        $selectionValide = $true
        $choixNumeros = @()
        $reset = $true
        break
    }
    # Séparer par virgule ou espace
    $tokens = $choix -split '[,\s]+' | Where-Object { $_ -match '^\d+$' }
    if (-not $tokens) {
        Write-Host "Entrée invalide. Veuillez entrer un ou plusieurs numéros (ou 0 pour réinitialiser)."
        continue
    }
    # Convertir en nombres
    $choixNumeros = $tokens | ForEach-Object { [int]$_ }
    # Filtrer les numéros hors de portée
    $choixNumeros = $choixNumeros | Where-Object { $_ -ge 1 -and $_ -le $regionList.Count }
    if (-not $choixNumeros) {
        Write-Host "Aucun numéro valide sélectionné. Veuillez recommencer."
        continue
    }
    $choixNumeros = $choixNumeros | Sort-Object -Unique
    $reset = $false
    $selectionValide = $true
}

# Construire la description des serveurs choisis pour confirmation
if ($reset) {
    $actionDesc = "rétablir le fichier hosts par défaut (autoriser tous les serveurs)"
} else {
    $selectedCodes = $choixNumeros | ForEach-Object { $regionList[$_-1].Code }
    # Obtenir les noms correspondants
    $selectedNames = $selectedCodes | ForEach-Object { $regionNames.GetValue($_, $_) }
    if ($selectedNames.Count -gt 1) {
        # Joindre les noms avec une virgule et " et " avant le dernier
        $dernier = $selectedNames[-1]
        $autres  = $selectedNames[0..($selectedNames.Count - 2)]
        $listeServeurs = ($autres -join ", ") + " et " + $dernier
    } else {
        $listeServeurs = $selectedNames[0]
    }
    $actionDesc = "sélectionner $listeServeurs"
}

# Confirmation
$confirmation = Read-Host "Vous vous apprêtez à $actionDesc. Continuer ? (O/N)"
if ($confirmation -notmatch '^(?:O|o)$') {
    Write-Host "Modification annulée par l'utilisateur."
    exit
}

# Modifier les lignes dans le tableau $lines en fonction du choix
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'gamelift-ping') {
        if ($reset) {
            # Tout autoriser : commenter toutes les lignes correspondantes
            $lines[$i] = $lines[$i] -replace '^[\s#]*', ''
            $lines[$i] = "# $($lines[$i])"
        } else {
            # Récupérer le code de la ligne
            if ($lines[$i] -match 'gamelift-ping\.([^.]+)\.api\.aws') {
                $codeLigne = $matches[1]
            } else {
                continue
            }
            if ($selectedCodes -contains $codeLigne) {
                # Autoriser ce serveur (commenter la ligne)
                $lines[$i] = $lines[$i] -replace '^[\s#]*', ''
                $lines[$i] = "# $($lines[$i])"
            } else {
                # Bloquer ce serveur (décommenter la ligne)
                $lines[$i] = $lines[$i] -replace '^[\s#]*', ''
            }
        }
    }
}

# Enregistrer les modifications dans le fichier hosts (encodage ANSI/Default)
Set-Content -Path $hostsPath -Value $lines -Encoding Default

# Message de succès
Write-Host "Le fichier hosts a été modifié avec succès."
if (-not $reset) {
    # Lancer Dead by Daylight via Steam
    Write-Host "Lancement de Dead by Daylight..."
    Start-Process "steam://rungameid/381210"
}
