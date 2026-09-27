# Installation du projet commun

Dans PowerShell (menu Démarrer, taper « PowerShell »), coller cette ligne puis appuyer sur Entrée :

```powershell
irm https://raw.githubusercontent.com/Loupharvey/projet-ami-installation/main/installer.ps1 | iex
```

Elle installe Git, Node.js, Python, GitHub CLI, Visual Studio Code, Claude Code, puis copie le dépôt privé du projet (sur invitation de Loup) et pose l'icône « Agents » sur le bureau. Ce dépôt ne contient que l'installateur : aucun code du projet, aucun secret.
