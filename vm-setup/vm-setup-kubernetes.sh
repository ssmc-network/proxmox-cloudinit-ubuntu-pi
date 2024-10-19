#!/usr/bin/env bash

TEMPLATE_VMID_LIST=(
    # ---
    # template_vmid:       proxmox上でVMを識別するID
    # targetip:   VMの配置先となるProxmoxホストのIP
    # targethost: VMの配置先となるProxmoxホストのホスト名
    # ---
    #template_vmid #targetip    #targethost
    "9000 192.168.20.20 pi-pve01"
    "9001 192.168.20.21 pi-pve02"
    "9002 192.168.20.22 pi-pve03"
)

VM_LIST=(
    # ---
    # vmid:       proxmox上でVMを識別するID
    # vmname:     proxmox上でVMを識別する名称およびホスト名
    # vmip:       VMに割り振る固定IP
    # targetip:   VMの配置先となるProxmoxホストのIP
    # targethost: VMの配置先となるProxmoxホストのホスト名
    # ---
    #vmid  #template_vmid  #vmname              #vmip          #targetip      #targethost
    "1001  9000            pi-ubuntu-k8s-cp-01  192.168.20.40  192.168.20.20  pi-pve01"
    "1002  9001            pi-ubuntu-k8s-wk-01  192.168.20.41  192.168.20.21  pi-pve02"
    "1003  9002            pi-ubuntu-k8s-wk-02  192.168.20.42  192.168.20.22  pi-pve03"
)

for array in "${TEMPLATE_VMID_LIST[@]}"
do
    echo "${array}" | while read -r template_vmid targetip targethost
    do
        if ! ssh -n "${targetip}"  qm list | grep "${template_vmid}"; then
            echo "Template VMID ${template_vmid} does not exist. Creating template."

            # download the image(ubuntu 24.04 LTS)
            ssh -n "${targetip}" wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img

            # create a new VM and attach Network Adaptor
            ssh -n "${targetip}" qm create $template_vmid --cores 4 --memory 6,144 --net0 virtio,bridge=vmbr0


            ssh -n "${targetip}" qm set $template_vmid --agent 1 --bios ovmf --cpu host --efidisk0 local:1,format=qcow2,efitype=4m,pre-enrolled-keys=1,size=64M

            # import the downloaded disk to local-lvm storage
            ssh -n "${targetip}" qm importdisk $template_vmid noble-server-cloudimg-arm64.img local -format qcow2

            # add
            ssh -n "${targetip}" qm set $template_vmid --scsihw virtio-scsi-pci --scsi0 local:$template_vmid/vm-$template_vmid-disk-1.qcow2 --ostype l26

            # add Cloud-Init CD-ROM drive
            ssh -n "${targetip}" qm set $template_vmid --scsi2 local:cloudinit

            # set the bootdisk parameter to scsi0
            ssh -n "${targetip}" qm set $template_vmid --boot c,order=scsi0

            # set serial console
            ssh -n "${targetip}" qm set $template_vmid --serial0 socket --vga serial0

            # migrate to template
            ssh -n "${targetip}" qm template $template_vmid

            # cleanup
            # ssh -n "${targetip}" rm noble-server-cloudimg-arm64.img

        else
            echo "Template VMID ${template_vmid} already exists. Skipping template creation."
        fi

    done
done

for array in "${VM_LIST[@]}"
do
    echo "${array}" | while read -r vmid template_vmid vmname vmip targetip targethost
    do
        if ! ssh -n "${targetip}"  qm list | grep "${vmip}"; then
            # clone from template
            # in clone phase, can't create vm-disk to local volume
            ssh -n "${targetip}" qm clone "${template_vmid}" "${vmid}" --name "${vmname}" --full true --target "${targethost}"

            # resize disk (Resize after cloning, because it takes time to clone a large disk)
            ssh -n "${targetip}" qm resize "${vmid}" scsi0 32G

            # create snippet for cloud-init(user-config)
# ----- #
cat > ${vmname}-user.yaml << EOF
#cloud-config
hostname: ${vmname}
timezone: Asia/Tokyo
manage_etc_hosts: true
ssh_authorized_keys: []
chpasswd:
  expire: False
users:
  - default
  - name: cloudinit
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    passwd: \$5\$t17XO334\$pPuwv1rAgg6Ie/etN3oEhmyDWe7qR1IXvCIGkGPOFB5
package_upgrade: true
runcmd:
  # set ssh_authorized_keys
  - su - cloudinit -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
  - su - cloudinit -c "curl -sS https://github.com/goegoe0212.keys >> ~/.ssh/authorized_keys"
  - su - cloudinit -c "chmod 600 ~/.ssh/authorized_keys"
  # change default shell to bash
  - chsh -s \$(which bash) cloudinit
  # set kubernetes
  - su - cloudinit -c "curl -s https://raw.githubusercontent.com/ssmc-network/proxmox-cloudinit-ubuntu-pi/refs/heads/main/k8s-setup/setup.sh > ~/setup.sh"
  - su - cloudinit -c "sudo bash ~/setup.sh"
EOF
# ----- #
            # upload snippet to vm
            scp ${vmname}-user.yaml ${targetip}:/var/lib/vz/snippets/${vmname}-user.yaml
            rm ${vmname}-user.yaml
            # set snippet to vm
            ssh -n "${targetip}" qm set "${vmid}" --cicustom "user=local:snippets/${vmname}-user.yaml"
            ssh -n "${targetip}" qm set "${vmid}" --ipconfig0 ip=$vmip/24,gw=192.168.20.2

        else
            echo "VMID ${vmip} already exists. Skipping creation."
        fi
    done
done

# ----- #

for array in "${VM_LIST[@]}"
do
    echo "${array}" | while read -r vmid vmname vmsrvip vmsanip targetip targethost
    do
        # start vm
        ssh -n "${targetip}" qm start "${vmid}"
    done
done

# ----- #