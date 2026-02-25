#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installa e configura OpenSSH Server su Windows Server Core
    con PowerShell come shell di default
#>

function Write-Step { param([string]$M); Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] >>> $M" -ForegroundColor Cyan }
function Write-OK   { param([string]$M); Write-Host "  [OK] $M" -ForegroundColor Green }
function Write-ERR  { param([string]$M); Write-Host "  [ERR] $M" -ForegroundColor Red }
function Write-WARN { param([string]$M); Write-Host "  [WARN] $M" -ForegroundColor Yellow }

# ============================================================
# STEP 1 - Installa OpenSSH Server (feature opzionale)
# ============================================================

Write-Step "Installazione OpenSSH Server"

$sshServer = Get-WindowsCapability -Online -Name "OpenSSH.Server*"

if ($sshServer.State -eq "Installed") {
    Write-OK "OpenSSH Server già installato"
} else {
    Write-Host "  Download e installazione in corso..." -NoNewline
    $result = Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0"
    if ($result.RestartNeeded -eq $false -or $?) {
        Write-OK "Installato"
    } else {
        Write-ERR "Installazione fallita"
        exit 1
    }
}

# Verifica anche OpenSSH Client (utile per scp/sftp)
$sshClient = Get-WindowsCapability -Online -Name "OpenSSH.Client*"
if ($sshClient.State -ne "Installed") {
    Add-WindowsCapability -Online -Name "OpenSSH.Client~~~~0.0.1.0" | Out-Null
    Write-OK "OpenSSH Client installato"
} else {
    Write-OK "OpenSSH Client già installato"
}

# ============================================================
# STEP 2 - Avvia e abilita servizio sshd
# ============================================================

Write-Step "Configurazione servizio sshd"

Set-Service -Name sshd -StartupType Automatic
Start-Service -Name sshd

$svc = Get-Service -Name sshd
if ($svc.Status -eq "Running") {
    Write-OK "sshd in esecuzione (startup: Automatic)"
} else {
    Write-ERR "sshd non avviato: $($svc.Status)"
    exit 1
}

# ============================================================
# STEP 3 - Firewall: apri porta 22
# ============================================================

Write-Step "Regola Firewall porta 22"

$fwRule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
if ($fwRule) {
    Write-OK "Regola firewall già presente"
} else {
    New-NetFirewallRule `
        -Name        "OpenSSH-Server-In-TCP" `
        -DisplayName "OpenSSH Server (sshd)" `
        -Enabled     True `
        -Direction   Inbound `
        -Protocol    TCP `
        -Action      Allow `
        -LocalPort   22 | Out-Null
    Write-OK "Regola firewall creata (TCP 22 inbound)"
}

# ============================================================
# STEP 4 - PowerShell come default shell
# ============================================================

Write-Step "Impostazione PowerShell come default shell per SSH"

# Cerca pwsh (PowerShell 7+) oppure fallback a Windows PowerShell 5.1
$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwsh) {
    $shellPath = $pwsh.Source
    Write-OK "Trovato PowerShell 7+: $shellPath"
} else {
    $shellPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    Write-WARN "PowerShell 7 non trovato, uso Windows PowerShell 5.1: $shellPath"
}

# Imposta nel registry
$regPath = "HKLM:\SOFTWARE\OpenSSH"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
Set-ItemProperty -Path $regPath -Name "DefaultShell" -Value $shellPath -Force
Set-ItemProperty -Path $regPath -Name "DefaultShellCommandOption" -Value "-NoLogo" -Force

$check = (Get-ItemProperty -Path $regPath -Name "DefaultShell").DefaultShell
Write-OK "DefaultShell impostato: $check"

# ============================================================
# STEP 5 - (Opzionale) Authorized Keys per autenticazione a chiave
# ============================================================

Write-Step "Configurazione authorized_keys (opzionale)"

$sshdConfig = "$env:ProgramData\ssh\sshd_config"

if (Test-Path $sshdConfig) {
    # Leggi config attuale
    $content = Get-Content $sshdConfig -Raw

    # Assicura che PubkeyAuthentication sia abilitato
    if ($content -notmatch "^PubkeyAuthentication yes") {
        $content = $content -replace "#?PubkeyAuthentication.*", "PubkeyAuthentication yes"
        Write-OK "PubkeyAuthentication abilitato"
    }

    # Per gli admin: commentare la riga che punta a administrators_authorized_keys
    # (così si usa il file ~/.ssh/authorized_keys standard)
    # Decommenta le 2 righe sotto se preferisci usare ~/.ssh/authorized_keys per gli admin
    # $content = $content -replace "^(AuthorizedKeysFile __PROGRAMDATA__.*)", "#`$1"
    # $content = $content -replace "^(Match Group administrators.*)", "#`$1"

    $content | Set-Content $sshdConfig -Force
    Write-OK "sshd_config aggiornato: $sshdConfig"

    # Riavvia sshd per applicare
    Restart-Service sshd
    Write-OK "sshd riavviato"
} else {
    Write-WARN "sshd_config non trovato in $sshdConfig"
}

# ============================================================
# STEP 6 - (Opzionale) Installa PowerShell 7
# ============================================================

Write-Step "Verifica PowerShell 7"

if ($pwsh) {
    Write-OK "PowerShell $($pwsh.Version) già installato"
} else {
    Write-WARN "PowerShell 7 non presente. Per installarlo:"
    Write-Host "  # Metodo 1 - winget" -ForegroundColor Gray
    Write-Host "  winget install Microsoft.PowerShell --silent" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Metodo 2 - MSI diretto" -ForegroundColor Gray
    Write-Host "  `$url = 'https://github.com/PowerShell/PowerShell/releases/latest'" -ForegroundColor Gray
    Write-Host "  # Scarica e installa il .msi per Windows x64" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Metodo 3 - script automatico" -ForegroundColor Gray
    Write-Host "  Invoke-Expression `"& { `$(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet`"" -ForegroundColor Gray
}

# ============================================================
# RIEPILOGO
# ============================================================

Write-Step "SSHD configurato con successo"
Write-Host ""
Write-Host "  Porta     : 22" -ForegroundColor White
Write-Host "  Shell     : $shellPath" -ForegroundColor White
Write-Host "  Config    : $sshdConfig" -ForegroundColor White
Write-Host "  Firewall  : TCP 22 aperto" -ForegroundColor White
Write-Host ""
Write-Host "  Test connessione:" -ForegroundColor Yellow
Write-Host "  ssh Administrator@$((Get-NetIPAddress -AddressFamily IPv4 | Where InterfaceAlias -notlike '*Loopback*' | Select -First 1).IPAddress)" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# COMANDI UTILI
# ============================================================
<#
--- STATO SERVIZIO ---
Get-Service sshd
Get-NetTCPConnection -LocalPort 22

--- LOG SSHD ---
Get-WinEvent -LogName "OpenSSH/Operational" | Select -First 20

--- AGGIUNGERE CHIAVE PUBBLICA (admin) ---
# Percorso speciale per Administrator e membri del gruppo Administrators:
$keyFile = "$env:ProgramData\ssh\administrators_authorized_keys"
Add-Content $keyFile "ssh-ed25519 AAAA... utente@host"
# Imposta ACL corretti (obbligatorio)
icacls $keyFile /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"

--- AGGIUNGERE CHIAVE PUBBLICA (utente normale) ---
$keyFile = "$env:USERPROFILE\.ssh\authorized_keys"
New-Item -ItemType Directory -Path "$env:USERPROFILE\.ssh" -Force | Out-Null
Add-Content $keyFile "ssh-ed25519 AAAA... utente@host"

--- DISABILITARE AUTH CON PASSWORD ---
# In sshd_config:
# PasswordAuthentication no

--- CAMBIARE PORTA ---
# In sshd_config: Port 2222
# Poi: New-NetFirewallRule ... -LocalPort 2222
# Restart-Service sshd
#>
