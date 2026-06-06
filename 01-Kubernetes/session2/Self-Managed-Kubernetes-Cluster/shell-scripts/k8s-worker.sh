#!/bin/bash

# For Ubuntu DISTRIB_RELEASE=22/24
#Always become "root" to run this script


# Update the system
sudo apt-get update
sudo apt-get upgrade -y

# Install Containerd as container runtime
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install containerd.io -y
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g' -i /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd
cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

# Disable swap
# Predictable performance: Swap can lead to unpredictable node performance.
# Resource management: Kubernetes manages container resources, and swap can interfere with this.
# Consistency: Ensures consistent behavior across all nodes in the cluster.
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab


# Add some settings to sysctl
# These settings are crucial for Kubernetes networking to function correctly.
# They allow Kubernetes services to communicate with each other and the outside world.
# They ensure that iptables rules are properly applied to bridge traffic.
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF


# Enable kernel modules
# overlay: Needed for efficient container filesystem operations.
# br_netfilter: Enables transparent masquerading and facilitates Virtual Extensible LAN (VxLAN) traffic for communication between Kubernetes pods across nodes.
sudo modprobe overlay
sudo modprobe br_netfilter

# Reload sysctl
sudo sysctl --system

systemctl status containerd

# Add Kubernetes repo
sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes components
sudo apt-get update
sudo apt-get install -y kubelet=1.33.10-1.1 kubeadm=1.33.10-1.1 kubectl=1.33.10-1.1
sudo apt-mark hold kubelet kubeadm kubectl
# apt-mark hold command marks the kubelet, kubeadm, and kubectl packages as "held back".
# When you run apt-get upgrade, these packages will not be upgraded, even if newer versions are available.


# Install crictl: It is a command-line interface for CRI-compatible container runtimes. You can use it to inspect and debug container runtimes and applications on a Kubernetes node
export CRICTL_VERSION="v1.33.0"
export CRICTL_ARCH=$(dpkg --print-architecture)
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRICTL_VERSION/crictl-$CRICTL_VERSION-linux-$CRICTL_ARCH.tar.gz
tar zxvf crictl-$CRICTL_VERSION-linux-$CRICTL_ARCH.tar.gz -C /usr/local/bin
rm -f crictl-$CRICTL_VERSION-linux-$CRICTL_ARCH.tar.gz
crictl version

# Ensure kubelet unit is available, unmasked and started so it can pick up configs written by kubeadm
sudo systemctl unmask kubelet || true
sudo systemctl daemon-reload
sudo systemctl enable --now kubelet
sleep 2


echo "Kubernetes worker node setup complete!"
echo "To join the cluster, run the kubeadm join command provided by the master node."