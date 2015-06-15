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