# Session 01-03: AWS EKS - Hands-On Labs

This document contains 4 practical labs to build hands-on experience with AWS EKS.

---

## Lab 1: Provision EKS Cluster Manually via AWS console

### Objective
Deploy a complete EKS cluster with VPC, subnets, node groups, and IAM roles.

### Prerequisites
- AWS Account with appropriate permissions (IAM, EC2, VPC, EKS)
- AWS CLI configured
- kubectl installed

### Follow the steps during the live class
---

## Lab 2: Connect to EKS from Local Machine

### Objective
Download kubeconfig and verify kubectl connectivity to the EKS cluster.

### Prerequisites
- Completed Lab 1 (cluster is running)
- AWS CLI configured
- kubectl installed
- Cluster name from Terraform output

### Steps

1. **Grant your IAM user/role access to the cluster**

   First, get your IAM ARN:
   ```bash
   aws sts get-caller-identity --query Arn --output text
   ```
   Expected output:
   ```
   arn:aws:iam::123456789:user/your-username
   ```

2. Add this ARN as an access entry in the EKS console:

   - Open the [EKS console](https://console.aws.amazon.com/eks/) and select your cluster (`myapp-cluster`).
   - Go to the **Access** tab.
   - Under **IAM access entries**, click **Create access entry**.
   - In the **IAM principal ARN** field, paste the ARN from the previous step.
   - Set **Type** to `Standard` and click **Next**.
   - On the **Add access policy** step, select a policy such as `AmazonEKSClusterAdminPolicy` (for full admin access), and click **Add policy**.
   - Click **Next**, review the configuration, then click **Create**.

3. **Update kubeconfig**
   ```bash
   aws eks update-kubeconfig \
     --name myapp-cluster \
     --region us-east-1
   ```
   Expected output:
   ```
   Added new context arn:aws:eks:us-east-1:123456789:cluster/myapp-cluster to /home/user/.kube/config
   ```

4. **Verify kubeconfig**
   ```bash
   cat ~/.kube/config
   ```
   Look for:
   - `clusters:` section with EKS API endpoint
   - `contexts:` section with cluster name
   - `current-context:` set to your EKS cluster

5. **List current context**
   ```bash
   kubectl config current-context
   ```
   Expected output: `arn:aws:eks:us-east-1:123456789:cluster/myapp-cluster`

6. **Get cluster info**
   ```bash
   kubectl cluster-info
   ```
   Expected output:
   ```
   Kubernetes control plane is running at https://xxxxx.eks.amazonaws.com
   CoreDNS is running at https://xxxxx.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
   ```

7. **Check cluster nodes**
   ```bash
   kubectl get nodes
   ```
   Expected output:
   ```
   NAME                                        STATUS   ROLES    AGE     VERSION
   ip-10-0-1-100.ec2.internal                  Ready    <none>   2m      v1.28.x
   ip-10-0-2-200.ec2.internal                  Ready    <none>   2m      v1.28.x
   ```
   Note: Node names use VPC CIDR IPs

8. **Check system namespaces**
   ```bash
   kubectl get pods -n kube-system
   ```
   Expected pods: `coredns`, `kube-proxy`, `aws-node` (VPC CNI), `ebs-csi-controller`

9. **Get more node details**
   ```bash
   kubectl describe node <node-name>
   ```
   Look for:
   - Status: `Ready`
   - Kubelet Version: matches cluster version
   - Capacity: CPU, memory from EC2 instance type
   - Allocatable: slightly less than capacity (reserved for kubelet)

---

## Lab 3: Explore EKS Cluster Structure

### Objective
Understand what differs from self-managed Kubernetes: AWS integrations, add-ons, and management patterns.

### Prerequisites
- Completed Lab 2 (kubectl configured)

### Steps

1. **Compare system namespaces**
   ```bash
   kubectl get namespaces
   ```
   Expected output:
   ```
   NAME              STATUS   AGE
   default           Active   10m
   kube-node-lease   Active   10m
   kube-public       Active   10m
   kube-system       Active   10m
   kube-apiserver    Active   10m
   ```

2. **Inspect kube-system pods (EKS-specific)**
   ```bash
   kubectl get pods -n kube-system
   ```
   Look for:
   - `coredns-*` — DNS service (managed by EKS)
   - `kube-proxy-*` — Network proxy (managed by EKS)
   - `aws-node-*` — VPC CNI plugin (AWS-specific)
   - `ebs-csi-controller-*` — EBS storage driver (AWS-specific)
   - `aws-load-balancer-controller-*` — ALB/NLB controller (AWS-specific)

3. **Inspect EKS add-ons**
   ```bash
   aws eks describe-addon-resources --cluster-name myapp-cluster --region us-east-1
   ```
   Or in AWS console: EKS → Cluster → Add-ons

4. **Check VPC CNI configuration**
   ```bash
   kubectl get daemonset -n kube-system aws-node -o yaml
   ```
   Look for:
   - `AWS_VPC_K8S_CNI_*` environment variables
   - IAM role attached to aws-node ServiceAccount

5. **Inspect OIDC provider (for IRSA)**
   ```bash
   aws eks describe-cluster --name myapp-cluster --region us-east-1 \
     --query 'cluster.identity.oidc.issuer'
   ```
   Expected output: HTTPS URL like `https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLEID`

---

## Lab 4: Deploy an Application on EKS

### Objective
Deploy a multi-tier Flask application on EKS and expose it via AWS Load Balancer.

### Prerequisites
- Completed Lab 2 (kubectl configured)
- Container image available (from Docker/Container Registry sessions)

### Steps

1. **Create namespace for application**
   ```bash
   kubectl create namespace myapp
   kubectl config set-context --current --namespace=myapp
   ```

2. **Create Flask Deployment**
   ```bash
   cat <<EOF | kubectl apply -f -
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: flask-app
     namespace: myapp
   spec:
     replicas: 3
     selector:
       matchLabels:
         app: flask
     template:
       metadata:
         labels:
           app: flask
       spec:
         containers:
         - name: flask
           image: <your-ecr-image>:latest  # Replace with your image
           ports:
           - containerPort: 5000
           resources:
             requests:
               cpu: 100m
               memory: 128Mi
             limits:
               cpu: 200m
               memory: 256Mi
           livenessProbe:
             httpGet:
               path: /health
               port: 5000
             initialDelaySeconds: 10
             periodSeconds: 10
           readinessProbe:
             httpGet:
               path: /ready
               port: 5000
             initialDelaySeconds: 5
             periodSeconds: 5
   EOF
   ```

3. **Verify deployment**
   ```bash
   kubectl get deployment -n myapp
   kubectl get pods -n myapp
   ```
   Expected: 3 pods in `Running` state.

4. **Check pod distribution across nodes**
   ```bash
   kubectl get pods -n myapp -o wide
   ```
   Pods should be spread across multiple nodes (if available).

5. **Create Service**
   ```bash
   cat <<EOF | kubectl apply -f -
   apiVersion: v1
   kind: Service
   metadata:
     name: flask-service
     namespace: myapp
   spec:
     selector:
       app: flask
     ports:
     - protocol: TCP
       port: 80
       targetPort: 5000
     type: LoadBalancer
   EOF
   ```

6. **Wait for LoadBalancer IP**
   ```bash
   kubectl get service -n myapp
   ```
   The `EXTERNAL-IP` field will show the AWS NLB/ALB DNS name after ~2 minutes.

7. **Test application**
   ```bash
   LOAD_BALANCER_DNS=$(kubectl get service flask-service -n myapp \
     -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
   curl http://$LOAD_BALANCER_DNS
   ```
   Expected: Flask application response (e.g., "Hello from Flask!").

8. **View application logs**
   ```bash
   kubectl logs -n myapp deployment/flask-app --tail=50
   ```

9. **Scale application**
   ```bash
   kubectl scale deployment flask-app -n myapp --replicas=5
   kubectl get pods -n myapp
   ```
   Expected: 5 pods running.

10. **Verify rolling update**
    ```bash
    kubectl set image deployment/flask-app -n myapp flask=<new-image>:v2
    kubectl rollout status deployment/flask-app -n myapp
    ```

### Success Criteria
- [ ] 3+ Flask pods are Running and Ready
- [ ] Service has external LoadBalancer IP
- [ ] Curl returns HTTP 200 from the app
- [ ] Logs show request handling
- [ ] Application survives scaling and updates

### Troubleshooting
- **Pods pending**: Check node capacity and resource requests
- **No external IP**: Verify AWS Load Balancer Controller is installed (check add-ons)
- **Connection refused**: Check security groups and Flask app listening port

---