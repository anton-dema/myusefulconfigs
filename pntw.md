# TechWARU Piccole note all'uso

Anche se il tool di repairtechsolutions si dichiara completamente automatizzato, ci sono dei programmi che non ne vogliono sapere di rispettare questa presunta automazione.        
Un esempio è hitmanpro. Hitmanpro è un second hit malware scanner, molto efficace e offerto in maniera trial per 30 giorni, prima di richiedere il pagamento di una regolare licenza.       
Anche se techWARU dichiara che prevede una sorta di automazione per il tool in questione, bisogna considerare che questo è vero se si sceglie _scan and quit_ come iterazione possibile. Altrimenti, alla fine della scansione del tool, bisogna a mano scegliere di eliminare gli elementi nocivi e il sistema viene riavviato per completare la rimozione del malware. 
Un altro problema che riscontra techWARU è che viene rilevato come malware esso stesso e, in alcuni casi, viene terminato dagli stessi tool che lancia nella routine programmata.           
Uno di questi tool che ritiene techWARU un malware e ne termina l'esecuzione è Junkware Removal Tool.          
Nelle nostre routines programmate, ho quindi rimosso l'inclusione di questo tool.           

Sto testando su una macchina sana una routine semplice ed efficace da applicare a tutti i computer che arrivano a laboratorio.              
La sto chiamando  CPLINE FINE DI MONDO, in parafrasi al famoso film Dottor Stranamore, e sarà il tool da lanciare ad ogni computer che viene portato in assistenza.                 
Questa routine dovrà fornire una scheda completa della macchina a livello software e hardware e al tempo stesso provedere ad una rimozione di tutti i malware e spyware sicuramente presenti in tutte le macchine.          
Sono sempre in test. Appena terminato evidenzierò i miei risultati e posterò anche i tempi medi per l'esecuzione dei tools, uno ad uno. 

## Una routine accettabile 

- Per prima cosa, una volta lanciato techWARU.exe e inserito il nome del cliente e del ticket in lavorazione, andare su Options->Config File->Import from tech Portal. 
- Andare su Tools, cancellare la routine di default e lanciare la routine techWARU **CPLINE Diagnostica**. In questo modo si potrà avere una lista dei programmi installati, il loro product code e altre informazioni importanti. 
- Prima di procedere con la routine **CPLINE FINE DI MONDO**, disinstallare TUTTI gli antivirus presenti dentro la macchina. Se il cliente ha acquistato merdESET NOD32, esportare prima la conf in file XML e salvarlo in un luogo sicuro (se il tecnico ha deciso di usare il sistema support.cpline.net, una buona location per salvare la conf è inserire un allegato al ticket del cliente)
- Lanciare la routine FINE DI MONDO con i seguenti tempi (indicativi)

| tool name | tempo medio esecuzione | richiede iterazione |            
| --------------| :---------------------------------:| :------------------------: |
| ERUNT Backup REgistry  | 30 Secondi | no |
| List installed Apps  | 30 Secondi | no |
| Whatsinstartup  | 30 Secondi | no |
| BlueScreenView  | 30 Secondi | no |
| Fix Shell/Run  | 1 minuto | no |
| Repair SSL/HTTPS/Cryptography  | 3 minuti | no |
| Flush DNS REsolver Cache  | 5 minuti | no |
| ESET powelinks Cleaner  | 30 secondi | no |
| Hijack This  | 30 secondi | no |
| Kaspersky TDSKiller  | 30 secondi | no |
| McAfee GetSusp | 5 minuti | no |
| McAfee RootkitRemover  | 3 minuti | no |
| Registry Investigator | 30 secondi | no |
| Farbar Service Scanner  | 30 secondi | no |
| Cleanings IE | 1 minuto | no |
| Cleanings Firefox | 1 minuto | no |
| Cleanings Chrome | 1 minuto | no |
| Cleanings Internet Explorer| 1 minuto | no |
| Cleanings Opera | 5 secondi | no |
| Hitman Pro* | 15 minuti | YES | 
| ADWCleaner| 5 minuti | YES |
| RogueKiller | 20 minuti | YES |
| MalwareBytes | 40 minuti | YES |
| PCDecrapifier | dipende dai programmi da rimuovere | YES |

Purtroppo, può succedere che qualche tool si blocchi per motivi di pesante infezione della macchina. Segnarsi il tool che non ha portato a termine il suo lavoro e lanciarlo manualmente in un secondo tempo. 

Alla routine ho aggiunto anche tutti i tool per la rimozione del malware. In presenza di Win7, aggiungere a mano in coda anche Combofix, che male non fa. 

## La macchina è pulita, now what? 

Lanciare i windows update e alla fine dichiarare finalmente ripulito il computer. 