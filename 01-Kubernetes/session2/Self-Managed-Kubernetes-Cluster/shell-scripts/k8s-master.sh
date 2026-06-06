#!/bin/bash

#Open these ports in the AWS Security group
#6443 from 0.0.0.0/0
#2379 - 2380 from same-security-group-id
#10250 - 10252 from same-security-group-id
#Always become "root" to run this script

# For Ubuntu DISTRIB_RELEASE=22/24

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

# ensure kubelet are running before init
sudo systemctl unmask kubelet || true
sudo systemctl daemon-reload
sudo systemctl enable --now kubelet
sleep 2

# Install crictl: It is a command-line interface for CRI-compatible container runtimes. You can use it to inspect and debug container runtimes and applications on a Kubernetes node.
export CRICTL_VERSION="v1.33.0"
export CRICTL_ARCH=$(dpkg --print-architecture)
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRICTL_VERSION/crictl-$CRICTL_VERSION-linux-$CRICTL_ARCH.tar.gz
tar zxvf crictl-$CRICTL_VERSION-linux-$CRICTL_ARCH.tar.gz -C /usr/local/bin
rm -f crictl-$CRICTL_VERSION-linux-$CRICTL_ARCH.tar.gz
crictl version

# Initialize the cluster
kubeadm init --control-plane-endpoint <master-node-public-ip>:6443 --kubernetes-version 1.33.10 --pod-network-cidr 192.168.0.0/16 --v=5 --ignore-preflight-errors=NumCPU,Mem

# Breakdown the above command:

# kubeadm init: This is the primary command used to initialize a Kubernetes control-plane node.
# It bootstraps the Kubernetes control plane, which includes components like the API server, controller manager, and scheduler.

# --control-plane-endpoint <master-node-public-ip>:<PORT>: VERY IMPORTANT!
# This specifies the stable address (IP or DNS name) and port that other nodes (workers) and kubectl users will use to communicate with the API server on this control plane node.
# <master-node-public-ip> is a placeholder you MUST replace with the actual public IP address of this machine.
# <PORT> is typically 6443 (the default Kubernetes API server secure port).
# --kubernetes-version 1.33.10: Specifies the Kubernetes version to initialize, matching the installed packages.
# --pod-network-cidr 192.168.0.0/16: Defines the IP address range from which Pods will get their IP addresses.
# This CIDR (Classless Inter-Domain Routing) block should not overlap with your node IPs or any other network ranges in your infrastructure.
# The CNI (Container Network Interface) plugin you install later will use this range.
# --v=5: Sets the verbosity level for kubeadm logging (higher is more verbose).

# Set up kubectl for the root user
# This command will setup connection from kubectl to the kubernetes cluster
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# CNI plugin installation with Cilium CLI
export CILIUM_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
export CILIUM_ARCH=$(dpkg --print-architecture)
# Download the Cilium CLI binary and its sha256sum
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/$CILIUM_VERSION/cilium-linux-$CILIUM_ARCH.tar.gz{,.sha256sum}

# Verify sha256sum
sha256sum --check cilium-linux-$CILIUM_ARCH.tar.gz.sha256sum

# Move binary to correct location and remove tarball
tar xzvf cilium-linux-$CILIUM_ARCH.tar.gz -C /usr/local/bin 
rm cilium-linux-$CILIUM_ARCH.tar.gz{,.sha256sum}

# Verify the Cilium CLI is installed
cilium version --client

# Install network plugin.
cilium install

# Wait for the CNI plugin to be installed.
cilium status --wait

echo "Kubernetes master node setup complete!"

# Print the join command for worker nodes
echo "Run the following command on your worker nodes to join the cluster:"
kubeadm token create --print-join-command

# kubeadm token create: This part of the command creates a new bootstrap token.
# Bootstrap tokens are used for establishing bidirectional trust between a node wanting to join the cluster and the control plane node.
# --print-join-command: This flag tells kubeadm to print out the full kubeadm join command that can be used to join a new node to the cluster