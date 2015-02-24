# Creare nuovi KVM guests con virsh 

Questo articolo è stato preso dal blog di [Ali Khan](http://askaralikhan.blogspot.it/2011/01/creating-kvm-guests-using-virsh-tool.html) e illustra in modo parecchio chiaro i semplici piccoli passi per iniziare a lavorare con le VM di KVM. 

Ho alterato alcuni comandi per riflettere gli ultimi comandi di qemu, in quanto l'articolo è parecchio datato e un semplice copia incolla non funzionerebbe. 


Creating KVM Guests using virsh tool
An example XML file to install an operating system from an ISO image The following example XML file can be modified to create a KVM and boot to any operating system from an ISO image or a CD-ROM drive.

    <domain type='kvm'>
       <name>kvm1</name>
       <uuid>a1e40383-2dfb-47f7-9cf6-589fc9679aa7</uuid>
       <memory>524288</memory>
       <currentMemory>524288</currentMemory>
       <vcpu>1</vcpu>
       <os>
         <type arch='x86_64' machine='pc'>hvm</type>
         <boot dev='cdrom'/>
     </os>
     <features>
        <acpi/>
     </features>
     <clock offset='utc'/>
     <on_poweroff>destroy</on_poweroff>
     <on_reboot>restart</on_reboot>
     <on_crash>restart</on_crash>
     <devices>
         <emulator>/usr/bin/qemu-system-x86_64</emulator>
         <disk type='file' device='disk'>
           <source file='/var/lib/libvirt/images/kvm1.img'/>
           <target dev='vda' bus='virtio'/>
         </disk>
        <disk type='file' device='cdrom'>
         <source file='/home/askarali/.bb/Fedora-14-x86_64-Live/Fedora-14-x86_64-Live-Desktop.iso'/>
         <target dev='hdc' bus='ide'/>
         <readonly/>
         </disk>
         <interface type='network'>
          <mac address='54:52:00:2a:58:0d'/>
          <source network='default'/>
        </interface>
         <input type='mouse' bus='ps2'/>
         <graphics type='vnc' port='-1' autoport='yes' keymap='en-us'/>
     </devices>
     </domain>

Edit the following before proceeding
a) Each guest needs a universal unique identifier (uuid), You must generate one for your guest by running the following command, and then copy and paste the identifier into the XML file <uuid>HERE</uuid>

    # uuidgen

b) Replace <memory>524288</memory> and <currentMemory>524288</currentMemory> tag to memory you want to allocate to your guest.

c) Replace <mac address='54:52:00:2a:58:0d'/> with the mac address, To generate unique mac address, get the python script from http://www.centos.org/docs/5/html/5.2/Virtualization/sect-Virtualization-Tips_and_tricks-Generating_a_new_unique_MAC_address.html

Creating Storage Image file

    # qemu-img create -f qcow2 /var/lib/libvirt/images/kvm1.img 10G

Using virsh to create a KVM
1. Define your KVM by running:

    # virsh define kvm1.xml

2. Start the KVM so that the installation of its operating system can begin:
# virsh start kvm1

If your KVM does not start, complete one of the following to redefine the KVM:

    # virsh edit <Name of KVM>

After editing the definition file, try to start guest vm again

    # virsh start vmName

Tips for installing your guest operating system (This should be run on mother host

To Connect from your PC/laptop

1. install virt-viewer
2. Upload your ssh public key to KVM host /root/.ssh/authorized_keys (For this you should allow root login in /etc/ssh/sshd_config)

From your laptop, run

    $ virt-viewer -c qemu+ssh://root@KVMHostIP/system vmName

To connect KVMs from the Host

To connect using the virt-viewer tool, run the following command:

    # virt-viewer vmName

To connect using the virt-manager tool, run the following command:

    # virt-manager vmName

Editing the KVM definition file after operating system installation

To boot to the installed guest after the guest operating system installation is complete, revise the guest
definition so that it will boot from its hard disk drive.

    # virsh edit vmName

Replace <boot dev='cdrom'/> line with <boot dev='hd'/> (To boot from hard disk)
and remove the ISO disk definitions are removed because they are no longer needed.

Propagating your KVMs
For example, if your task is to create 10 identical KVMs that have simple configurations, you can propagate existing KVMs rather than manually installing 10 identical KVMs.

Stop the template KVM with the virsh tool:
 
    # virsh shutdown templateKVM

Make copies of the KVM disk image by using the qemu-image command with the convert option:

    # qemu-img convert templateKVM.img -O qcow2 NewKVM1.img

Make copies of the templateKVM XML definition file. You can find it in the /etc/libvirt/qemu/directory or you can run the following command to see the definition file.

    # virsh dumpxml templateKVM

Edit the definition files for name, memory, mac address, source file etc to define the new KVMs. It is important that a unique MAC address is used in the definition file to make sure that the network functions without a problem.

Networking in Bridge Mode

Configure the bridge interface on host operating system
replace <interface type='network'> section in kvm.xml with the following

    <interface type='bridge'>
          <mac address='00:16:3e:56:40:ad'/>
          <source bridge='br0'/>
    </interface>

Install the guest OS, after installation configure the IP on guest.

Auto start KVM VMs on Host system boot

The following command will mark the VM for auto start on system reboot

    # virsh autostart vmName
Posted by Askar Ali Khan at 10:24 PM 