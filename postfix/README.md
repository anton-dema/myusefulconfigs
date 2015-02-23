# Il file di configurazione di postfix per un invio rapido di mail dai server 

Con questo, il server invierà i suoi alert via mail all'amministratore maldestro. 

## Passi da Compiere 

- Installare postifix (con il package manager della vostra distro preferita)        
- Clonare questa repo, in particolare la cartella postfix                     
- Sovrascrivere `/etc/postfix`               
- Cambiare i seguenti  parametri a questi files:                
`/etc/main.cf`                  

        # CAMBIA I PARAMETRI QUI 
        myhostname = yourawesomedomain
        alias_maps = hash:/etc/aliases
        alias_database = hash:/etc/aliases
        mydestination = localhost, localhost.localdomain, localhost
        mynetworks = la.tua.subnet.0/24 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
        mailbox_size_limit = 0
        recipient_delimiter = +
        inet_interfaces = all
        compatibility_level = 2
`/etc/sasl_passwd`          

        [smtp.mandrillapp.com] yourmandrillusername:yourmandrillAPIKey 

- Provare il setup con :        

        echo "prova di invio mail" | mail -s "test" yourmail@yourdomain.com

- Come al solito lasciare bigliettino da visita al cliente dopo il setup            
![come al solito lasciare ](http://demaitalia.s3.amazonaws.com/db.jpg)
