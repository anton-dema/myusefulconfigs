# Invio email per Veeam Endpoint Backup 

## Parte 1: Dotarsi di un server mail all'interno della LAN

Per avere un servizio che spara messaggi mail, abbiamo bisogno di un server smtp interno, in quanto la quasi totalità degli smtp daemons esterni avrà bisogno di qualche layer di complicazione di autentica, che questo script per powershell, rudimentale, ma molto efficace, non supporta. 

Per lo scopo, bisognerà appoggiarsi ad un server linux interno alla rete locale, o, in mancanza di un server linux vero e proprio appoggiarsi ad un Raspberry P che può egregiamente funzionare come server smtp di relay esterno. 

Tralascio la configurazione di un server smtp semplice interno alla lan che faccia relay verso un altro smtp. Noi amiamo il servizio di invio massivo di mandrillapp e per configurare postfix per fare relay verso mandrilapp, si può copiare la configurazione che si trova sulla [repo pubblica myusefulconfig su github](https://github.com/anton-dema/myusefulconfigs/tree/master/postfix)  

Una volta appurato che il nostro server mail interno riesce correttamente ad inviare email attraverso il relay di mandrillapp, possiamo concentrarci sui singoli client di windows per l'invio di email di allarme per il programma Veeam Endpoint Backup. 


## Parte 2: Configurare Windows PowerShell per l'esecuzione di script. 

Già, perché di default, windows power shell non ammette l'esecuzione di script che:

- non abbiano una apposita signature che ne accerta la sicurezza
- che provengano da un altro computer
- che provengano da internet e ogni volta ci verrà richiesto di confermare se si intende  eseguire lo script oppure no. 

Per prima cosa, lanciamo  Powershell come Amministratore e ``Set-ExecutionPolicy Unrestricted`` .           
In questo modo potremo eseguire script di powershell non firmati. 

È a questo punto che dobbiamo compilare il seguente script per estrarre l'ultima entry del log di Veeam Endpoint Backup e inviare una mail con il report di sucesso o fallimento delle copie.           
Ecco lo script qui di seguito:              

    ###########################################################
    # Edit this part:
    $youremailserver=    ""$an.internal.mailserver""
    $sender      =   "you@yourorganization"
    $recipient   =   "you@yourrecipient"
    ###########################################################

    # Put most info into the body of the email:
    $TimeGenerated   =    get-eventlog "Veeam Endpoint Backup" -newest 1 -entrytype Information, Warning, Error -source "Veeam Endpoint Backup" | Format-List -property TimeGenerated | out-string
    $Source      =   get-eventlog "Veeam Endpoint Backup" -newest 1 -entrytype Information, Warning, Error -source "Veeam Endpoint Backup" | Format-List -property Source | out-string
    $EntryType   =   get-eventlog "Veeam Endpoint Backup" -newest 1 -entrytype Information, Warning, Error -source "Veeam Endpoint Backup" | Format-List -property EntryType | out-string
    $Message   =   get-eventlog "Veeam Endpoint Backup" -newest 1 -entrytype Information, Warning, Error -source "Veeam Endpoint Backup" | Format-List -property Message | out-string
    $InstanceID   =   get-eventlog "Veeam Endpoint Backup" -newest 1 -entrytype Information, Warning, Error -source "Veeam Endpoint Backup" | Format-List -property InstanceID| out-string
    $Body      =   " $TimeGenerated Instance-ID: $InstanceID $Message "


    # Determine the subject according to the result of the backup:
    if ($Message.contains("Success")) {
       $subject = "EndpointBackup finished with Success." 
    } elseif ($InstanceID.contains("110")) {
       $subject = "EndpointBackup started."
    } else {   
       $subject = "EndpointBackup finished but NO SUCCESS!! Check Body for details."
    }


    # Send the email using the powershell object (replace with e.g. blat.exe for older powershell-Versions)
    if ($InstanceID.contains("110") -Or  $InstanceID.contains("190")) {
       Send-MailMessage -To $recipient -Subject $subject -From $sender -Body $body -SmtpServer $Youremailserver 
    } else {
       write-host "I don't want messages on 10010 and 10050 Restorepoint-creation or -remove Emails, skip those"
    }


    write-host "Script finished with -$instanceID- as the last event-ID"


 Oltre ai parametri da variare subito all'inizio dello script, occorrerà cambiare anche la stringa 
 

    -source "Veeam Endpoint Backup"


in quanto mi è capitato che alcune installazioni di Veeam Endpoint Backup scrivono all'interno del registro di windows come sorgente Veeam EP. In questo caso, occorre rimpiazzare  il testo _Veeam Endpoint Backup_  con  _Veeam EP_. 

Una volta aggiustato lo script con i giusti parametri, possiamo salvarlo con estensione ps1 all'inteno di una directory di nostra scelta.                   
Io l'ho messo all'interno di **\documents\VEB\veb.ps1**. Quindi basta lanciare powershell, posizionarsi su **C:\Users\$User\Documents\VEB\** e lanciare **.\veb.ps1** .                 
Se tutto andrà bene, dovremmo ricevere la mail con il risultato delle ultime copie di Veeam Endpoint Backup. 
Se abbiamo compilato lo script su un altro computer, dobbiamo compiere un ulteriore passo per sbloccare il file, e fare in modo che powershell non chieda ogni volta se vogliamo eseguire lo script in questione. Lo facciamo da esplora risorse, posizionandoci sul file veb.ps1, cliccando con il tasto destro e scegliendo _sblocca file_.

## Automatizziamo con  Pianifica Attività di Windows

Dobbiamo a questo punto pianificare l'esecuzione dello script, di modo che, ogni volta che viene eseguita una copia tramite Veeam Endpoint Backup, una mail di notifica venga inviata al nostro indirizzo email scelto.                     
Apriamo il gestore di utilità di pianificazione di windows e nel riquadro di destra  scegliamo "Crea attività di base"

Seguiamo il wizard, inserendo le seguenti istruzioni:                   
- crea un'attività di base -> Nome : Veeam Endpoint Backup Email - Descrizione: "facoltativa"                              
- _avanti_                            
-  Attivazione: Specificare quando avviare l'attività: Alla registrazione di un evento specifico.                               
- _avanti_                                 
- Registro : Drop down e scegliamo Veeam Endpoint Backup - Origine : dropdown Veeam Endpoint Backup - ID evento: **190**            
- Azione: Avvio programma.                  
- _avanti_                          
- Nella box programma o script, scrivere il full path di Windows PowerShell:        
        
        C:\Windows\Sytem32\WindowsPowerShell\v1.0\powershell.exe

e su _aggiungi argomenti (facoltativo)_             

    C:\Users\$user\Documents\VEB\veb.ps1

- _avanti_                      
- Verificare i parametri e scegliere _fine_.                        

Se tutto è andato liscio, appena Veeam Endpoint Backup terminerà le sue copie giornaliere, il nostro script andrà a leggere il registro eventi di Windows, selezionerà la riga che più ci interessa, ossia se le copie si sono completate con successo oppure no e ci notificherà a riguardo via email. 

Questo foglio di howto, è stato reso disponibile per la prima volta il 15/06/2015 all'interno del nostro slack aziendale, cpline.slack.com

Credits [@feelgoodeule sul forum di Veeam](http://forums.veeam.com/veeam-endpoint-backup-f33/here-it-is-powershell-script-to-add-veb-emails-t27569.html) 