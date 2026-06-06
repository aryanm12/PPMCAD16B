# Session 01-02: Self-Managed Kubernetes with Kubeadm
## Hands-On Labs


In this labs, you'll build a real, multi-node Kubernetes cluster from scratch using kubeadm. You'll provision infrastructure on AWS, bootstrap the control plane, join worker nodes, and deploy applications on your cluster.

---

## Lab 1: Provision Infrastructure on AWS

**Objective:** Create 3 EC2 instances (1 master, 2 workers) using Terraform

**Prerequisites:**
- AWS account with sufficient permissions
- Provision 3 EC2 servers on your existing VPC in the public subnets
- EC2 server type: t3.medium

## Lab 2: Initialize the Master Node with Kubeadm

**Objective:** SSH into the master instance and bootstrap the control plane

**Prerequisites:**
- Lab 1 complete: EC2 instances running
- SSH access to master node

### Steps

#### 2.1: SSH into Master Node

```bash
# Use the public IP of the Master Node from AWS Console
ssh -i ~/.ssh/my-k8s-key.pem ubuntu@master-public-ip

# Use the k8s-master.sh script to provision the master node
cd /home/ubuntu
vim "k8s-master.sh" # Copy the script from: Self-Managed-Kubernetes-Cluster\shell-scripts\k8s-master.sh
chmod +x k8s-master.sh
bash k8s-master.sh
```

#### 2.2: SSH into Worker Nodes (Both one-by-one)

```bash
# Use the public IP of Worker Node from AWS Console
ssh -i ~/.ssh/my-k8s-key.pem ubuntu@worker-public-ip

# Use the k8s-worker.sh script to provision the worker node
cd /home/ubuntu
vim "k8s-worker.sh" # Copy the script from: Self-Managed-Kubernetes-Cluster\shell-scripts\k8s-worker.sh
chmod +x k8s-worker.sh
bash k8s-worker.sh
```
#### 2.3: Merge the Kubeconfig file to your local workstation (which will mostly be your laptop)

a.) Copy the content of this file from Master node: /etc/kubernetes/admin.conf 

b.) Run below mentioned commands:

From Powershell:

```powershell
cd C:\Users\<username>\.kube
notepad self-managed-cluster-config.txt # Paste the content from the master node "/etc/kubernetes/admin.conf" to self-managed-cluster-config.txt file
$env:KUBECONFIG = "$PWD\config;$PWD\self-managed-cluster.txt"
kubectl config view --flatten | Out-File -FilePath "$PWD\config-merged" -Encoding utf8
Rename-Item "$env:USERPROFILE\.kube\config" "config-backup"
Move-Item ".\config-merged" "$env:USERPROFILE\.kube\config"
```

or from Bash:

```bash
cd ~/.kube/
vim self-managed-cluster-config # Paste the content from the master node "/etc/kubernetes/admin.conf" to self-managed-cluster-config file
KUBECONFIG=~/.kube/config:~/.kube/self-managed-cluster-config kubectl config view --flatten > config-merged
cp config config_bak
mv config-merged config
```

#### 2.4: Set as Default Context (Optional)


# Verify
kubectl config current-context
kubectl config get-contexts
kubectl config use-context <CONTEXT_NAME>
# Should show "kubernetes-admin@kubernetes"

#### 2.5: Verify Cluster Access

```bash
# Check cluster info
kubectl cluster-info
# Should show API server and DNS endpoints

# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Check services
kubectl get svc
# Should show kubernetes service
```

### Success Criteria

- [ ] kubectl works with kubeconfig from home directory
- [ ] kubectl get nodes returns all 3 nodes
- [ ] kubectl cluster-info shows API server URL
- [ ] Can view kube-system pods from local machine

---

## Lab 3: Explore the Self-Managed Cluster

**Objective:** Understand how the self-managed cluster differs from Minikube, explore static pods and control plane components

### Steps

#### 3.1: View Static Pod Manifests

On **master node**:

```bash
# SSH to master
ssh -i ~/.ssh/my-k8s-key.pem ubuntu@master-public-ip

# List static pod manifests
ls -la /etc/kubernetes/manifests/

# Expected files:
# -rw------- kube-apiserver.yaml
# -rw------- kube-controller-manager.yaml
# -rw------- kube-scheduler.yaml
# -rw------- etcd.yaml
```

#### 3.2: Inspect Static Pods

```bash
# View API server manifest
cat /etc/kubernetes/manifests/kube-apiserver.yaml

# Note the key fields:
# spec.containers[0].image: k8s.gcr.io/kube-apiserver:v1.27.0
# spec.containers[0].args: flags passed to the binary
# volumeMounts: where certificates/kubeconfig are mounted

# View etcd manifest
cat /etc/kubernetes/manifests/etcd.yaml

# Note:
# spec.containers[0].image: k8s.gcr.io/etcd:v3.5.x
# volumeMounts for data and certs
```

#### 3.3: Explore Control Plane Components

```bash
# View all control plane components
kubectl get pods -n kube-system -o wide

# Check specific component health
kubectl logs -n kube-system -l component=kube-apiserver --tail=20
kubectl logs -n kube-system -l component=kube-controller-manager --tail=20
kubectl logs -n kube-system -l component=kube-scheduler --tail=20

# Watch etcd health (runs as static pod on master)
kubectl get pods -n kube-system -l component=etcd
kubectl logs -n kube-system -l component=etcd --tail=30
```

#### 3.4: Check Node Information

```bash
# Detailed node info
kubectl describe node ip-10-0-1-100

# Shows:
# - Labels: cloud provider metadata
# - Capacity: CPU, memory available
# - Allocatable: what's available for pods
# - Conditions: Ready, MemoryPressure, DiskPressure, etc.
# - System pods running on node

```
---