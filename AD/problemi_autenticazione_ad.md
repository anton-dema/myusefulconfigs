# Problemi di autenticazione AD — Cartelle Condivise

**Contesto:** Le workstation nel profilo di rete mostrano "Rete dominio (non autenticato)" e non riescono ad accedere alle share di rete tramite `\\FQDN` (funziona solo con `\\IP`).

---

## Causa radice

**NLA (Network Location Awareness)** non riesce a verificare la connettività al dominio contattando il DC via DNS + LDAP. Windows degrada il profilo firewall a "dominio non autenticato" e blocca SMB in ingresso. Con `\\ipaddress` NTLM bypassa questo controllo.

---

## Diagnosi

```powershell
# Verifica profilo rete attivo (deve essere DomainAuthenticated)
Get-NetConnectionProfile

# Verifica raggiungibilità DC
nltest /dsgetdc:<dominio>
Test-NetConnection <DC-IP> -Port 389
```

---

## Cause tipiche

| Causa | Verifica |
|---|---|
| DNS primario non punta al DC | `ipconfig /all` → DNS server |
| DC irraggiungibile al boot | NLA testa al login, se DC lento → fallisce |
| Scheda di rete con più profili sovrapposti | `Get-NetConnectionProfile` mostra duplicati |
| Canale sicuro degradato | `nltest /sc_reset` necessario |

---

## Fix rapido

```powershell
# 1. Forza re-autenticazione NLA (senza reboot)
Restart-Service nlasvc -Force

# 2. Verifica/imposta DC come DNS primario
ipconfig /all | findstr "DNS Servers"
```

Se dopo il restart di `nlasvc` il profilo diventa `DomainAuthenticated` → problema di timing al boot. Soluzione stabile: ritardare l'avvio di alcuni servizi o verificare la velocità di link-up della NIC.

---

## Trust del dominio rotto? Repair prima del Rejoin

```powershell
# Verifica
Test-ComputerSecureChannel -Verbose

# Repair (bassa invasività)
Test-ComputerSecureChannel -Repair -Credential (Get-Credential)

# Conferma
nltest /sc_verify:<dominio>
```

Errori `0xc000006d` o `0x51f` da `nltest` confermano il trust rotto.

### Repair vs Rejoin

| | Repair | Rejoin |
|---|---|---|
| Invasività | Bassa | Alta |
| Downtime | Nessuno | Riavvio necessario |
| Profili utente | Intatti | Intatti (stesso nome PC) |
| Quando usarlo | Sempre prima | Solo se repair fallisce |

```powershell
# Repair alternativo (più aggressivo)
Reset-ComputerMachinePassword -Credential (Get-Credential)
```

> **Consiglio:** `Test-ComputerSecureChannel -Repair` risolve il 70% dei casi di trust rotto. Parti sempre da lì.

---

**Nota rejoin:** nessun dato viene perso se il computer mantiene lo stesso nome e l'oggetto AD viene eliminato prima del rejoin. Rischio reale solo su software con licenze legate al SID macchina o certificati machine-based.
