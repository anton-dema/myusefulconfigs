#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installa e configura AD DS + DNS su Windows Server Core
.DESCRIPTION
    - Imposta IP statico, hostname
    - Installa ruoli AD DS e DNS
    - Promuove il server a Domain Controller (nuovo forest o join)
.NOTES
    Eseguire come Administrator su Windows Server Core
    Testato su: Windows Server 2019/2022
#>

# ============================================================
# CONFIGURAZIONE - Modifica questi valori
# ============================================================

$Config = @{
    # Rete
    InterfaceAlias  = "Ethernet"          # Get-NetAdapter per trovare il nome
    IPAddress       = "192.168.1.2"
    PrefixLength    = 24                   # /24 = 255.255.255.0
    Gateway         = "192.168.1.1"
    DNSServers      = @("192.168.1.1", "8.8.8.8")

    # Hostname
    ComputerName    = "DCX"

    # Active Directory
    DomainName      = "good.domain"      # FQDN del dominio
    NetBIOSName     = "GOOD"            # max 15 caratteri
    DomainMode      = "WinThreshold"       # WinThreshold = 2016+
    ForestMode      = "WinThreshold"

    # Password DSRM (usa una password sicura!)
    DSRMPassword    = "Supersecretpassowrd"

    # Opzioni
    IsNewForest     = $false                # $false = aggiungi DC a dominio esistente
    ExistingDomain  = "good.domain"      # usato solo se IsNewForest = $false
}

# ============================================================
# FUNZIONI
# ============================================================

function Write-Step {
    param([string]$Message)
    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] >>> $Message" -ForegroundColor Cyan
}

function Write-OK   { param([string]$M); Write-Host "  [OK] $M" -ForegroundColor Green }
function Write-ERR  { param([string]$M); Write-Host "  [ERR] $M" -ForegroundColor Red }
function Write-WARN { param([string]$M); Write-Host "  [WARN] $M" -ForegroundColor Yellow }

# ============================================================
# STEP 1 - IP STATICO
# ============================================================

Write-Step "Configurazione IP statico"

try {
    $iface = Get-NetAdapter -Name $Config.InterfaceAlias -ErrorAction Stop

    # Rimuovi configurazioni esistenti
    Remove-NetIPAddress -InterfaceAlias $Config.InterfaceAlias -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute -InterfaceAlias $Config.InterfaceAlias -Confirm:$false -ErrorAction SilentlyContinue
    Set-DnsClientServerAddress -InterfaceAlias $Config.InterfaceAlias -ResetServerAddresses -ErrorAction SilentlyContinue

    New-NetIPAddress `
        -InterfaceAlias $Config.InterfaceAlias `
        -IPAddress      $Config.IPAddress `
        -PrefixLength   $Config.PrefixLength `
        -DefaultGateway $Config.Gateway | Out-Null

    Set-DnsClientServerAddress `
        -InterfaceAlias $Config.InterfaceAlias `
        -ServerAddresses $Config.DNSServers

    Write-OK "IP impostato: $($Config.IPAddress)/$($Config.PrefixLength) - GW: $($Config.Gateway)"
} catch {
    Write-ERR "Errore configurazione rete: $_"
    exit 1
}

# ============================================================
# STEP 2 - HOSTNAME
# ============================================================

Write-Step "Impostazione hostname: $($Config.ComputerName)"

$currentName = $env:COMPUTERNAME
if ($currentName -ne $Config.ComputerName) {
    try {
        Rename-Computer -NewName $Config.ComputerName -Force
        Write-OK "Hostname cambiato da '$currentName' a '$($Config.ComputerName)'"
        Write-WARN "Il server verrà riavviato per applicare il nuovo nome. Riesegui lo script dopo il riavvio."
        
        # Pianifica riesecuzione script dopo reboot
        $scriptPath = $MyInvocation.MyCommand.Path
        if ($scriptPath) {
            $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""
            $trigger = New-ScheduledTaskTrigger -AtLogOn
            Register-ScheduledTask -TaskName "AD-Setup-Continue" -Action $action -Trigger $trigger -RunLevel Highest -Force | Out-Null
            Write-WARN "Task schedulato: lo script riprenderà al prossimo logon."
        }
        
        Restart-Computer -Force
        exit 0
    } catch {
        Write-ERR "Errore rename: $_"
        exit 1
    }
} else {
    Write-OK "Hostname già corretto: $currentName"
}

# ============================================================
# STEP 3 - INSTALLAZIONE RUOLI
# ============================================================

Write-Step "Installazione ruoli: AD-Domain-Services, DNS, RSAT-AD-Tools"

$roles = @("AD-Domain-Services", "DNS", "RSAT-AD-AdminCenter", "RSAT-ADDS-Tools")

foreach ($role in $roles) {
    $installed = Get-WindowsFeature -Name $role
    if ($installed.Installed) {
        Write-OK "$role già installato"
    } else {
        Write-Host "  Installazione $role..." -NoNewline
        $result = Install-WindowsFeature -Name $role -IncludeManagementTools
        if ($result.Success) {
            Write-OK "OK"
        } else {
            Write-ERR "Fallito per $role"
            exit 1
        }
    }
}

# ============================================================
# STEP 4 - PROMOZIONE A DOMAIN CONTROLLER
# ============================================================

# Controlla se già DC
$dcCheck = Get-Service -Name "NTDS" -ErrorAction SilentlyContinue
if ($dcCheck -and $dcCheck.Status -eq "Running") {
    Write-WARN "Il server è già un Domain Controller. Skip promozione."
} else {
    $dsrmSecure = ConvertTo-SecureString $Config.DSRMPassword -AsPlainText -Force

    if ($Config.IsNewForest) {
        Write-Step "Promozione: Nuovo Forest '$($Config.DomainName)'"

        try {
            Install-ADDSForest `
                -DomainName                    $Config.DomainName `
                -DomainNetbiosName             $Config.NetBIOSName `
                -DomainMode                    $Config.DomainMode `
                -ForestMode                    $Config.ForestMode `
                -SafeModeAdministratorPassword $dsrmSecure `
                -InstallDns `
                -CreateDnsDelegation:$false `
                -DatabasePath                  "C:\Windows\NTDS" `
                -SysvolPath                    "C:\Windows\SYSVOL" `
                -LogPath                       "C:\Windows\NTDS" `
                -NoRebootOnCompletion:$false `
                -Force
        } catch {
            Write-ERR "Errore promozione forest: $_"
            exit 1
        }

    } else {
        Write-Step "Promozione: Aggiunta DC al dominio '$($Config.ExistingDomain)'"

        $domainCred = Get-Credential -Message "Credenziali Domain Admin per $($Config.ExistingDomain)"

        try {
            Install-ADDSDomainController `
                -DomainName                    $Config.ExistingDomain `
                -Credential                    $domainCred `
                -SafeModeAdministratorPassword $dsrmSecure `
                -InstallDns `
                -NoRebootOnCompletion:$false `
                -Force
        } catch {
            Write-ERR "Errore promozione DC aggiuntivo: $_"
            exit 1
        }
    }
}

# ============================================================
# STEP 5 - POST-CONFIGURAZIONE DNS (eseguito dopo reboot)
# ============================================================
# Questo blocco può essere eseguito separatamente dopo la promozione

function Configure-DNS {
    Write-Step "Configurazione DNS post-promozione"

    # Forwarder DNS esterni
    $forwarders = @("8.8.8.8", "1.1.1.1")
    try {
        Set-DnsServerForwarder -IPAddress $forwarders -PassThru | Out-Null
        Write-OK "Forwarder impostati: $($forwarders -join ', ')"
    } catch {
        Write-WARN "Errore forwarder: $_"
    }

    # Aging/Scavenging DNS
    try {
        Set-DnsServerScavenging -ScavengingState $true -ScavengingInterval 7.00:00:00
        Set-DnsServerZoneAging -Name $Config.DomainName -Aging $true `
            -NoRefreshInterval 4.00:00:00 -RefreshInterval 4.00:00:00
        Write-OK "DNS Aging/Scavenging abilitato"
    } catch {
        Write-WARN "Errore scavenging: $_"
    }

    # Zona di ricerca inversa (PTR)
    # Calcola automaticamente dal range IP
    $ipParts = $Config.IPAddress -split "\."
    $reverseZone = "$($ipParts[2]).$($ipParts[1]).$($ipParts[0]).in-addr.arpa"
    
    $existing = Get-DnsServerZone -Name $reverseZone -ErrorAction SilentlyContinue
    if (-not $existing) {
        try {
            Add-DnsServerPrimaryZone -NetworkID "$($ipParts[0]).$($ipParts[1]).$($ipParts[2]).0/$($Config.PrefixLength)" `
                -ReplicationScope "Forest"
            Write-OK "Zona inversa creata: $reverseZone"
        } catch {
            Write-WARN "Errore zona inversa: $_"
        }
    } else {
        Write-OK "Zona inversa già esistente: $reverseZone"
    }

    # Mostra stato finale
    Write-Step "Stato DNS"
    Get-DnsServerZone | Select-Object ZoneName, ZoneType, IsReverseLookupZone | Format-Table -AutoSize

    Write-Step "Forwarder attivi"
    Get-DnsServerForwarder | Select-Object -ExpandProperty IPAddress
}

# ============================================================
# PULIZIA TASK SCHEDULATO (se presente)
# ============================================================

$task = Get-ScheduledTask -TaskName "AD-Setup-Continue" -ErrorAction SilentlyContinue
if ($task) {
    Unregister-ScheduledTask -TaskName "AD-Setup-Continue" -Confirm:$false
    Write-OK "Task schedulato rimosso"
}

# ============================================================
# RIEPILOGO
# ============================================================

Write-Step "Setup completato!"
Write-Host ""
Write-Host "  Dominio  : $($Config.DomainName)" -ForegroundColor White
Write-Host "  NetBIOS  : $($Config.NetBIOSName)" -ForegroundColor White
Write-Host "  IP       : $($Config.IPAddress)" -ForegroundColor White
Write-Host "  Hostname : $($Config.ComputerName)" -ForegroundColor White
Write-Host ""
Write-Host "  Per configurare DNS dopo il reboot, esegui:" -ForegroundColor Yellow
Write-Host "  . .\Setup-AD-DNS-Core.ps1; Configure-DNS" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# COMANDI UTILI POST-INSTALLAZIONE
# ============================================================
<#
--- VERIFICA AD ---
Get-ADDomainController
Get-ADDomain
Get-ADForest
nltest /dsgetdc:contoso.local
dcdiag /test:dns /v

--- VERIFICA DNS ---
Get-DnsServerZone
Resolve-DnsName contoso.local
nslookup contoso.local 127.0.0.1

--- UTENTI E OU ---
New-ADOrganizationalUnit -Name "Computers" -Path "DC=contoso,DC=local"
New-ADUser -Name "Mario Rossi" -SamAccountName "mrossi" -UserPrincipalName "mrossi@contoso.local" -AccountPassword (Read-Host -AsSecureString "Password") -Enabled $true

--- GESTIONE DA REMOTO (RSAT) ---
# Da client Windows con RSAT installato
Enter-PSSession -ComputerName DC01 -Credential CONTOSO\Administrator
#>
