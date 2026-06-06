# stop services
sudo systemctl stop kubelet

# reset kubeadm (this removes join information, iptables rules in many cases)
sudo kubeadm reset -f

# remove kubelet/static manifests (workers have some manifests so clean them)
sudo rm -rf /etc/kubernetes/manifests/*
sudo rm -rf /etc/kubernetes/*

# remove kubelet and kube-proxy state
sudo rm -rf /var/lib/kubelet/*
sudo rm -rf /var/lib/kube-proxy/*

# reload systemd
sudo systemctl daemon-reload
sudo systemctl reset-failed kubelet || true
