# VM操作系

## VMを生やすスクリプト
```sh
/bin/bash <(curl -s https://raw.githubusercontent.com/ssmc-network/proxmox-cloudinit-ubuntu-pi/refs/heads/main/vm-setup/mv-setup-kubernetes.sh)
```

## VMを消すスクリプト
```sh
/bin/bash <(curl -s https://raw.githubusercontent.com/ssmc-network/proxmox-cloudinit-ubuntu-pi/refs/heads/main/vm-setup/mv-destroy.sh)
```

# kubernetes操作系

## k8s CPを生やす
```sh
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## flannel
```sh
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

## Metal-LB
```sh
# see what changes would be made, returns nonzero returncode if different
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl diff -f - -n kube-system

# actually apply the changes, returns nonzero returncode on errors only
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system
```

```sh
export METALLB_VERSION=v0.14.8
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml
kubectl apply -f https://raw.githubusercontent.com/ssmc-network/proxmox-cloudinit-ubuntu-pi/refs/heads/main/manifests/metallb-config.yaml
```

## nginx
```sh
kubectl apply -f https://raw.githubusercontent.com/ssmc-network/proxmox-cloudinit-ubuntu-pi/refs/heads/main/manifests/nginx.yaml
```

## Ingress-Nginx
```sh
export INGRESS_NGINX_VERSION=v1.12.0-beta.0
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_NGINX_VERSION}/deploy/static/provider/cloud/deploy.yaml
```

## CoreDNS
```sh
kubectl apply -f https://raw.githubusercontent.com/ssmc-network/proxmox-cloudinit-ubuntu-pi/refs/heads/main/manifests/coredns-etcd.yaml
```

```sh
kubectl get pods
```


```sh
kubectl exec -it <etcd-pod-name> -- etcdctl put /skydns/home/pi-pve01 '{"host":"192.168.20.20"}'
kubectl exec -it <etcd-pod-name> -- etcdctl put /skydns/home/pve01 '{"host":"192.168.20.3"}'
```

# kubectl導入
クラスター外からkubectlコマンドが実行できると便利

## kubectl準備
バージョンがクラスターと合わせること
```sh
export KUBERNETES_VERSION=v1.31.1
curl -LO "https://dl.k8s.io/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

```sh
kubectl version --client

> Client Version: v1.31.1
> Kustomize Version: v5.4.2
```


## kubectl config
kubernetes コントロールプレーンのconfigをコピーしてくる。
```sh
mkdir -p $HOME/.kube
touch $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## 接続チェック
```sh
kubectl cluster-info

> Kubernetes control plane is running at https://192.168.20.40:6443
> CoreDNS is running at https://192.168.20.40:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

> To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```


# その他便利系

## known_host登録削除
```sh
ssh-keygen -R 192.168.20.40
ssh-keygen -R 192.168.20.41
ssh-keygen -R 192.168.20.42
ssh-keygen -R 192.168.20.43
ssh-keygen -R 192.168.20.44
ssh-keygen -R 192.168.20.45
```


