#!/usr/bin/env bash

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
    "1002  9000            pi-ubuntu-k8s-wk-01  192.168.20.41  192.168.20.20  pi-pve01"
    "1003  9001            pi-ubuntu-k8s-cp-02  192.168.20.42  192.168.20.21  pi-pve02"
    "1004  9001            pi-ubuntu-k8s-wk-02  192.168.20.43  192.168.20.21  pi-pve02"
    "1005  9002            pi-ubuntu-k8s-cp-03  192.168.20.44  192.168.20.22  pi-pve03"
    "1006  9002            pi-ubuntu-k8s-wk-03  192.168.20.45  192.168.20.22  pi-pve03"
)

for array in "${VM_LIST[@]}"
do
    echo "${array}" | while read -r vmid template_vmid vmname vmip targetip targethost
    do
        ssh -n "${targetip}" qm stop "${vmid}"
        ssh -n "${targetip}" qm destroy "${vmid}"
    done
done