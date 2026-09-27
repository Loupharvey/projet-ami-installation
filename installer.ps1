# AMI-001 : installe chez l'ami de Loup une Clara et un Dave pour le projet commun (dépôt privé Loupharvey/projet-ami).
# Se lance en une ligne, dans PowerShell (pas besoin d'être administrateur ; Windows peut demander une permission) :
#   irm https://raw.githubusercontent.com/Loupharvey/projet-ami-installation/main/installer.ps1 | iex
# Rien du cabinet de Loup ici : ni client, ni secret, ni mémoire. Ce script est public : il ne doit jamais contenir de secret.
# Se relance sans danger : ce qui est déjà en place est gardé, le dépôt est mis à jour.
# Pour un essai sans questions (bac à sable) : $env:AMI_PRENOM = 'Test' avant de lancer ; GH_TOKEN, s'il existe, sert à GitHub.
# Source : projet-ami/outils/installer.ps1 (dépôt privé), publiée telle quelle dans le dépôt public projet-ami-installation.

& {
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$depotGitHub = 'Loupharvey/projet-ami'
$Depot = Join-Path $env:USERPROFILE 'projet-ami'
$journal = Join-Path $env:TEMP 'installation-projet-ami.log'
$aFaire = New-Object System.Collections.Generic.List[string]
try { Start-Transcript -Path $journal -Force | Out-Null } catch {}

function Etape($texte) { Write-Host ''; Write-Host "== $texte" -ForegroundColor Cyan }
function Existe($commande) { [bool](Get-Command $commande -ErrorAction SilentlyContinue) }
function Rafraichir-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
  $local = Join-Path $env:USERPROFILE '.local\bin'
  if ((Test-Path $local) -and ($env:Path -notlike "*$local*")) { $env:Path += ";$local" }
}
# Sans vrai Python, « python » est le raccourci de Windows vers le Microsoft Store (WindowsApps\python.exe), qui ne fait rien.
function Python-Present {
  [bool](Get-Command python -All -CommandType Application -ErrorAction SilentlyContinue | Where-Object { $_.Source -notmatch '\\WindowsApps\\' }) -or
  [bool](Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python3*\python.exe') -ErrorAction SilentlyContinue)
}
function Installer($id, $nom, [scriptblock]$present) {
  if (& $present) { Write-Host "  $nom : déjà là"; return }
  Write-Host "  $nom : installation…"
  winget install --id $id -e --silent --accept-source-agreements --accept-package-agreements --scope user | Out-Null
  Rafraichir-Path
  if (-not (& $present)) {
    winget install --id $id -e --silent --accept-source-agreements --accept-package-agreements | Out-Null
    Rafraichir-Path
  }
  if (& $present) { Write-Host "  $nom : installé" }
  else { Write-Host "  $nom : ÉCHEC" -ForegroundColor Red; $aFaire.Add("$nom ne s'est pas installé : relancer la ligne d'installation ; si ça échoue encore, l'installer à la main.") }
}

Write-Host ''
Write-Host 'Installation du projet commun avec Loup : Clara (assistante) et Dave (développeur).' -ForegroundColor Green
Write-Host "Durée : 10 à 20 minutes. Journal : $journal"
$prenom = $env:AMI_PRENOM
while (-not $prenom) { $prenom = (Read-Host 'Ton prénom').Trim() }

Etape '1. Gestionnaire de logiciels (winget)'
# winget manque dans le bac à sable de Windows et sur quelques vieux Windows : recette de Microsoft (module Microsoft.WinGet.Client).
function Winget-Marche { try { $v = winget --version 2>$null; return ($LASTEXITCODE -eq 0 -and [bool]$v) } catch { return $false } }
if (Winget-Marche) { Write-Host '  winget : déjà là' }
else {
  Write-Host '  winget : installation (quelques minutes)…'
  $ProgressPreference = 'SilentlyContinue'
  $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  $portee = if ($admin) { 'AllUsers' } else { 'CurrentUser' }
  Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope $portee | Out-Null
  Install-Module Microsoft.WinGet.Client -Force -Scope $portee -Repository PSGallery -AllowClobber | Out-Null
  Import-Module Microsoft.WinGet.Client
  if ($admin) { Repair-WinGetPackageManager -AllUsers -Force | Out-Null } else { Repair-WinGetPackageManager -Force | Out-Null }
  $ProgressPreference = 'Continue'
  Rafraichir-Path
  if (-not ($env:Path -like "*Microsoft\WindowsApps*")) { $env:Path += ";$env:LOCALAPPDATA\Microsoft\WindowsApps" }
  if (-not (Winget-Marche)) { throw "winget n'a pas pu être installé : installer « App Installer » depuis le Microsoft Store, puis relancer la ligne." }
  Write-Host '  winget : installé'
}

Etape '2. Logiciels'
Installer 'Git.Git' 'Git' { Existe 'git' }
Installer 'OpenJS.NodeJS.LTS' 'Node.js' { Existe 'node' }
Installer 'Python.Python.3.13' 'Python' { Python-Present }
Installer 'GitHub.cli' 'GitHub CLI' { Existe 'gh' }
Installer 'Microsoft.VisualStudioCode' 'Visual Studio Code' { Existe 'code' }
Installer 'Obsidian.Obsidian' 'Obsidian' { (Test-Path (Join-Path $env:LOCALAPPDATA 'Programs\Obsidian\Obsidian.exe')) -or (Test-Path (Join-Path $env:LOCALAPPDATA 'Obsidian\Obsidian.exe')) }
if (Existe 'claude') { Write-Host '  Claude Code : déjà là' }
else {
  Write-Host '  Claude Code : installation…'
  Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
  Rafraichir-Path
  if (Existe 'claude') { Write-Host '  Claude Code : installé' }
  else { $aFaire.Add('Claude Code ne s''est pas installé : relancer la ligne d''installation.') }
}
# Claude Code s'installe dans %USERPROFILE%\.local\bin : on l'ajoute au PATH de l'utilisateur pour les prochaines fenêtres.
$local = Join-Path $env:USERPROFILE '.local\bin'
$pathUser = [Environment]::GetEnvironmentVariable('Path', 'User')
if ((Test-Path $local) -and ($pathUser -notlike "*$local*")) { [Environment]::SetEnvironmentVariable('Path', ($pathUser.TrimEnd(';') + ";$local"), 'User') }

Etape '3. Visual Studio Code : extensions'
if (Existe 'code') {
  foreach ($ext in 'anthropic.claude-code', 'ms-python.python') { code --install-extension $ext --force 2>&1 | Out-Null; Write-Host "  $ext" }
}

Etape '4. Compte GitHub'
if (-not (Existe 'gh')) { throw 'GitHub CLI manque (voir plus haut) : relancer la ligne d''installation.' }
gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Host '  Une page GitHub va s''ouvrir : crée ton compte (ou connecte-toi), puis entre le code affiché ici.' -ForegroundColor Yellow
  gh auth login --web --git-protocol https --hostname github.com
}
gh auth setup-git 2>&1 | Out-Null
$moi = (gh api user 2>$null | Out-String) | ConvertFrom-Json
if (-not $moi.login) { throw 'Connexion à GitHub impossible : relancer la ligne d''installation.' }
$login = $moi.login; $idGitHub = $moi.id
Write-Host "  connecté à GitHub : $login"

Etape '5. Invitation au dépôt du projet'
$limite = (Get-Date).AddMinutes(30)
$annonce = $false
while ($true) {
  gh api "repos/$depotGitHub" --silent 2>$null
  if ($LASTEXITCODE -eq 0) { Write-Host '  accès au dépôt : oui'; break }
  # Une invitation en attente s'accepte ici, sans passer par le courriel.
  $invitation = ((gh api user/repository_invitations 2>$null | Out-String) | ConvertFrom-Json) |
    Where-Object { $_.repository.full_name -eq $depotGitHub } | Select-Object -First 1 -ExpandProperty id
  if ($invitation) {
    gh api -X PATCH "user/repository_invitations/$invitation" --silent 2>$null
    Write-Host '  invitation de Loup acceptée'
    continue
  }
  if (-not $annonce) {
    Write-Host ''
    Write-Host "  Dis à Loup ton nom GitHub : $login" -ForegroundColor Yellow
    Write-Host '  Il t''invite au dépôt ; j''attends son invitation (pas besoin de toucher à rien)…' -ForegroundColor Yellow
    $annonce = $true
  }
  if ((Get-Date) -gt $limite) { throw "Toujours pas d'invitation après 30 minutes : quand Loup aura invité $login, relancer la ligne d'installation." }
  Start-Sleep -Seconds 10
}

Etape '6. Dépôt du projet'
if (-not (git config --global user.name)) { git config --global user.name $prenom }
if (-not (git config --global user.email)) { git config --global user.email "$idGitHub+$login@users.noreply.github.com" }
if (-not (Test-Path (Join-Path $Depot '.git'))) {
  git clone "https://github.com/$depotGitHub.git" $Depot 2>&1 | Out-Null
  if (-not (Test-Path (Join-Path $Depot '.git'))) { throw 'Le dépôt n''a pas pu être copié : relancer la ligne d''installation.' }
  Write-Host "  dépôt copié : $Depot"
} else {
  git -C $Depot pull --ff-only 2>&1 | Out-Null
  Write-Host "  dépôt déjà là, mis à jour : $Depot"
}

Etape '7. Réglages de Claude Code'
$claudeDir = Join-Path $env:USERPROFILE '.claude'
New-Item -ItemType Directory -Force $claudeDir, (Join-Path $claudeDir 'skills') | Out-Null
$reglages = Join-Path $claudeDir 'settings.json'
# On complète les réglages sans jamais remplacer ceux qui existent déjà.
$env:REGLAGES = $reglages
node -e "const fs=require('fs');const f=process.env.REGLAGES;const e=fs.existsSync(f)?JSON.parse(fs.readFileSync(f,'utf8')):{};fs.writeFileSync(f,JSON.stringify({theme:'dark',autoUpdatesChannel:'latest',remoteControlAtStartup:true,...e},null,2))"
Remove-Item Env:\REGLAGES
Copy-Item (Join-Path $Depot 'outils\skills\*') (Join-Path $claudeDir 'skills') -Recurse -Force
Write-Host "  skills : $((Get-ChildItem (Join-Path $Depot 'outils\skills') -Directory).Name -join ', ')"

Etape '8. Brain de Clara (privé, hors du dépôt partagé)'
# Le coffre Obsidian de Clara : ce qui concerne la personne (agenda, contacts, rencontres). Il n'est jamais poussé vers le projet
# et Loup ne le voit pas. On crée ce qui manque sans jamais toucher à ce qui existe.
$brain = Join-Path $env:USERPROFILE 'Brain'
foreach ($d in 'raw/assets', 'wiki/people', 'wiki/projects', 'wiki/meetings', 'wiki/tasks', 'wiki/topics', 'wiki/companies', '.obsidian') {
  New-Item -ItemType Directory -Force (Join-Path $brain $d) | Out-Null
}
$aujourdhui = Get-Date -Format 'yyyy-MM-dd'
$pages = [ordered]@{
  'index.md' = "# Index du brain de Clara`n`nUne ligne par page du wiki : ``- [[Nom de la page]] : résumé (mis à jour : AAAA-MM-JJ)```n`n## Personnes`n`n## Projets`n`n## Rencontres`n`n## Tâches`n`n## Sujets`n`n## Organisations`n"
  'log.md' = "# Journal du brain`n`nEn ajout seulement, le plus récent en bas.`n`n## [$aujourdhui] création | Coffre créé par l'installateur pour $prenom`n"
  'wiki\overview.md' = "---`ntype: topic`ntags: []`ncreated: $aujourdhui`nupdated: $aujourdhui`nsources: []`n---`n`n# Vue d'ensemble`n`nCe qui se passe en ce moment pour $prenom : Clara tient cette page à jour.`n"
  '.obsidian/app.json' = '{}'
}
foreach ($f in $pages.Keys) {
  $chemin = Join-Path $brain $f
  if (-not (Test-Path $chemin)) { [IO.File]::WriteAllText($chemin, $pages[$f], (New-Object Text.UTF8Encoding $false)) }
}
Write-Host "  coffre : $brain"
# Clara (et elle seule) peut lire et écrire le coffre depuis sa fenêtre : réglage local, jamais poussé (.gitignore).
$local = Join-Path $Depot 'Clara\.claude\settings.local.json'
if (-not (Test-Path $local)) {
  $env:BRAIN = $brain.Replace([char]92, [char]47)
  $env:LOCAL = $local
  node -e "require('fs').writeFileSync(process.env.LOCAL, JSON.stringify({permissions:{additionalDirectories:[process.env.BRAIN]}},null,2))"
  Remove-Item Env:\BRAIN, Env:\LOCAL
}

Etape '9. Icône « Agents » du bureau'
& (Join-Path $Depot 'outils\lanceur\creer-icone.ps1')

Etape 'Terminé'
$aFaire.Add('Double-clique l''icône « Agents » du bureau : Dave s''ouvre à gauche, Clara à droite.')
$aFaire.Add('La première fois, dans chaque fenêtre, connecte-toi à Claude (une page s''ouvre) et accepte de faire confiance au dossier.')
$aFaire.Add('Clara lance ensuite d''elle-même le grill de l''application : réponds-lui avec Loup.')
$aFaire.Add('Gmail et Google Agenda (facultatif) : sur claude.ai, Paramètres > Connecteurs, branche Gmail et Google Calendar ; Clara les verra au prochain démarrage.')
$i = 1; foreach ($ligne in $aFaire) { Write-Host "  $i. $ligne"; $i++ }
try { Stop-Transcript | Out-Null } catch {}
}
