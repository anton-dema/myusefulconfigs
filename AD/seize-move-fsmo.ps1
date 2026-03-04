# ============================================================
# Manage-FSMORoles.ps1
# Gestione completa ruoli FSMO - Transfer, Seize, Verify
# Autore: CPLine | Compatibile: Windows Server 2012R2+
# ============================================================

#Requires -Modules ActiveDirectory

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Verify","Transfer","Seize","TransferSingle","SeizeSingle")]
    [string]$Action = "",

    [string]$TargetDC = "",

    [ValidateSet("SchemaMaster","DomainNamingMaster","PDCEmulator","RIDMaster","InfrastructureMaster","All")]
    [string]$Role = "All"
)

# ---- Helpers ----

function Write-Title($text) {
    Write-Host "`n======================================" -ForegroundColor DarkCyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkCyan
}

function Show-CurrentFSMO {
    Write-Title "FSMO - Stato Attuale"
    $domain = Get-ADDomain
    $forest = Get-ADForest
    Write-Host "  [FOREST]"
    Write-Host "    Schema Master        : " -NoNewline; Write-Host $forest.SchemaMaster -ForegroundColor Yellow
    Write-Host "    Domain Naming Master : " -NoNewline; Write-Host $forest.DomainNamingMaster -ForegroundColor Yellow
    Write-Host "  [DOMAIN]"
    Write-Host "    PDC Emulator         : " -NoNewline; Write-Host $domain.PDCEmulator -ForegroundColor Yellow
    Write-Host "    RID Master           : " -NoNewline; Write-Host $domain.RIDMaster -ForegroundColor Yellow
    Write-Host "    Infrastructure Master: " -NoNewline; Write-Host $domain.InfrastructureMaster -ForegroundColor Yellow
}

function Verify-DCReachable($dcName) {
    try {
        $dc = Get-ADDomainController -Identity $dcName -ErrorAction Stop
        Write-Host "  [OK] $($dc.HostName) raggiungibile - OS: $($dc.OperatingSystem)" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  [ERR] $dcName non trovato o non raggiungibile." -ForegroundColor Red
        return $false
    }
}

function Verify-PostMigration($dcName) {
    Write-Title "Verifica Post-Migrazione"
    $domain = Get-ADDomain
    $forest = Get-ADForest
    $roles = @{
        "Schema Master"         = $forest.SchemaMaster
        "Domain Naming Master"  = $forest.DomainNamingMaster
        "PDC Emulator"          = $domain.PDCEmulator
        "RID Master"            = $domain.RIDMaster
        "Infrastructure Master" = $domain.InfrastructureMaster
    }
    $allOk = $true
    foreach ($r in $roles.GetEnumerator()) {
        $ok = $r.Value -like "$dcName*"
        $color = if ($ok) { "Green" } else { "Red" }
        $symbol = if ($ok) { "[OK]" } else { "[!!]" }
        Write-Host ("  {0} {1,-24}: {2}" -f $symbol, $r.Key, $r.Value) -ForegroundColor $color
        if (-not $ok) { $allOk = $false }
    }
    if ($allOk) {
        Write-Host "`n  Tutti i ruoli FSMO sono su $dcName" -ForegroundColor Green
    } else {
        Write-Warning "  Alcuni ruoli non risultano su $dcName. Verifica manualmente."
    }
}

function Get-RoleList($role) {
    if ($role -eq "All") {
        return @("SchemaMaster","DomainNamingMaster","PDCEmulator","RIDMaster","InfrastructureMaster")
    }
    return @($role)
}

# ---- Menu interattivo ----

function Show-Menu {
    Write-Title "FSMO Manager - cunningam.local"
    Write-Host "  1) Verifica ruoli attuali"
    Write-Host "  2) Transfer tutti i ruoli (DC sorgente ONLINE)"
    Write-Host "  3) Transfer ruolo singolo (DC sorgente ONLINE)"
    Write-Host "  4) Seize tutti i ruoli (DC sorgente OFFLINE/guasto)"
    Write-Host "  5) Seize ruolo singolo (DC sorgente OFFLINE/guasto)"
    Write-Host "  Q) Esci"
    Write-Host ""
    return (Read-Host "  Scelta").Trim()
}

function Ask-TargetDC {
    $dc = Read-Host "  Nome DC di destinazione (es. DC50)"
    return $dc.Trim()
}

function Ask-Role {
    Write-Host "  Ruoli disponibili:"
    Write-Host "    1) SchemaMaster"
    Write-Host "    2) DomainNamingMaster"
    Write-Host "    3) PDCEmulator"
    Write-Host "    4) RIDMaster"
    Write-Host "    5) InfrastructureMaster"
    $choice = Read-Host "  Scelta (1-5)"
    switch ($choice) {
        "1" { return "SchemaMaster" }
        "2" { return "DomainNamingMaster" }
        "3" { return "PDCEmulator" }
        "4" { return "RIDMaster" }
        "5" { return "InfrastructureMaster" }
        default { Write-Host "  Scelta non valida." -ForegroundColor Red; return $null }
    }
}

# ---- Azioni ----

function Do-Transfer($dcTarget, $roles) {
    Write-Title "TRANSFER: $($roles -join ', ') -> $dcTarget"
    if (-not (Verify-DCReachable $dcTarget)) { return }
    Show-CurrentFSMO
    $confirm = Read-Host "`n  Confermi il trasferimento? [S/N]"
    if ($confirm -notin @("S","s")) { Write-Host "  Annullato." -ForegroundColor Yellow; return }

    Write-Host "`n  Trasferimento in corso..." -ForegroundColor Cyan
    try {
        Move-ADDirectoryServerOperationMasterRole `
            -Identity $dcTarget `
            -OperationMasterRole $roles `
            -Confirm:$false -ErrorAction Stop
        Write-Host "  Completato." -ForegroundColor Green
    } catch {
        Write-Error "  Errore durante il transfer: $_"
        return
    }
    Verify-PostMigration $dcTarget
}

function Do-Seize($dcTarget, $roles) {
    Write-Title "SEIZE (forzato): $($roles -join ', ') -> $dcTarget"
    Write-Host "`n  ATTENZIONE: Il seize e' un'operazione distruttiva." -ForegroundColor Red
    Write-Host "  Usare SOLO se il DC sorgente e' offline e non tornera' in produzione." -ForegroundColor Red
    Write-Host "  Se il DC sorgente venisse riacceso dopo un seize, potrebbe causare conflitti." -ForegroundColor Red

    if (-not (Verify-DCReachable $dcTarget)) { return }

    $confirm = Read-Host "`n  Sei sicuro di voler procedere con il SEIZE? [SEIZE/N]"
    if ($confirm -ne "SEIZE") { Write-Host "  Annullato." -ForegroundColor Yellow; return }

    Write-Host "`n  Seize in corso..." -ForegroundColor Cyan
    try {
        Move-ADDirectoryServerOperationMasterRole `
            -Identity $dcTarget `
            -OperationMasterRole $roles `
            -Force `
            -Confirm:$false -ErrorAction Stop
        Write-Host "  Completato." -ForegroundColor Green
    } catch {
        Write-Error "  Errore durante il seize: $_"
        return
    }
    Verify-PostMigration $dcTarget
}

# ---- Entry point ----

# Se parametri passati da CLI, esecuzione diretta
if ($Action -ne "") {
    switch ($Action) {
        "Verify"         { Show-CurrentFSMO }
        "Transfer"       { Do-Transfer $TargetDC (Get-RoleList "All") }
        "Seize"          { Do-Seize    $TargetDC (Get-RoleList "All") }
        "TransferSingle" { Do-Transfer $TargetDC (Get-RoleList $Role) }
        "SeizeSingle"    { Do-Seize    $TargetDC (Get-RoleList $Role) }
    }
    exit
}

# Menu interattivo
do {
    $choice = Show-Menu
    switch ($choice) {
        "1" { Show-CurrentFSMO }
        "2" {
            $dc = Ask-TargetDC
            if ($dc) { Do-Transfer $dc (Get-RoleList "All") }
        }
        "3" {
            $dc = Ask-TargetDC
            $r  = Ask-Role
            if ($dc -and $r) { Do-Transfer $dc (Get-RoleList $r) }
        }
        "4" {
            $dc = Ask-TargetDC
            if ($dc) { Do-Seize $dc (Get-RoleList "All") }
        }
        "5" {
            $dc = Ask-TargetDC
            $r  = Ask-Role
            if ($dc -and $r) { Do-Seize $dc (Get-RoleList $r) }
        }
        "Q" { Write-Host "`n  Uscita.`n" -ForegroundColor Cyan }
        default { Write-Host "  Scelta non valida." -ForegroundColor Red }
    }
} while ($choice -notin @("Q","q"))
