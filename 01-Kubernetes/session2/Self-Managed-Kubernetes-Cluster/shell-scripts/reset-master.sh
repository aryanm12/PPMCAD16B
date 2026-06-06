# Stop node services
sudo systemctl stop kubelet

# Reset kubeadm state
sudo kubeadm reset -f

# Remove kubernetes static manifests and configs
sudo rm -rf /etc/kubernetes/manifests/*
sudo rm -rf /etc/kubernetes/*

# Remove etcd data
sudo rm -rf /var/lib/etcd

# Remove kubelet state and kube-proxy state
sudo rm -rf /var/lib/kubelet/*
sudo rm -rf /var/lib/kube-proxy/*

# Remove CNI artifacts (Cilium + generic)
sudo cilium uninstall || true                # if cilium cli is present
kubectl delete crds -l app.kubernetes.io/part-of=cilium --ignore-not-found || true
sudo rm -f /usr/local/bin/cilium || true
sudo rm -rf /etc/cni/net.d/*cilium* /etc/cni/net.d/*
sudo rm -rf /var/lib/cni/*
sudo rm -rf /opt/cni/bin/*

# Remove leftover kubernetes manifests, certs, configs
sudo rm -rf /var/lib/kubeadm/*
sudo rm -rf /etc/systemd/system/kubelet.service.d
sudo systemctl daemon-reload
sudo systemctl reset-failed kubelet || true


echo "After this you can re-initialize the control plane with kubeadm init command mentioned in the k8s-master.sh file... using your desired flags (pod network, API advertise address, CRI socket, etc.)."