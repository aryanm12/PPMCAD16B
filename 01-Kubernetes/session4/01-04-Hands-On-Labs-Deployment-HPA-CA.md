# Session 01-04: Deployment, HPA and CA - Hands-On Labs

## Prerequisites
- Kubernetes cluster running (kind, minikube, or managed cluster)
- `kubectl` configured to access cluster
- Text editor for YAML files
- Previous sessions completed (pods, basic kubectl commands)

---

## Lab 1: Create a ReplicaSet & Observe Self-Healing

### Objective
Understand how ReplicaSets maintain desired pod count through label selection.

### Step-by-Step

1. Create a ReplicaSet manifest file `lab1-replicaset.yaml`:
```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: web-rs
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      tier: frontend
  template:
    metadata:
      labels:
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.24-alpine
        ports:
        - containerPort: 80
```

2. Apply the manifest:
```bash
kubectl apply -f lab1-replicaset.yaml
```

**Expected output:**
```
replicaset.apps/web-rs created
```

3. Verify pods were created:
```bash
kubectl get pods -L tier
```

**Expected output:**
```
NAME          READY   STATUS    RESTARTS   AGE     TIER
web-rs-abc12  1/1     Running   0          10s     frontend
web-rs-def45  1/1     Running   0          10s     frontend
web-rs-ghi78  1/1     Running   0          10s     frontend
```

4. Check ReplicaSet status:
```bash
kubectl get replicaset web-rs
```

**Expected output:**
```
NAME     DESIRED   CURRENT   READY   AGE
web-rs   3         3         3       20s
```

### Self-Healing Test

5. Delete one pod:
```bash
kubectl delete pod web-rs-abc12
```

6. Immediately check pods:
```bash
kubectl get pods -L tier
```

**Expected behavior:** ReplicaSet immediately creates a new pod to maintain 3 replicas. You should see a new pod (e.g., `web-rs-xyz99`) in Creating/Running state.

7. Watch reconciliation in real-time:
```bash
kubectl get pods -L tier --watch
```

Press Ctrl+C to stop watching.

### Success Criteria
- [ ] 3 pods running with `tier=frontend` label
- [ ] ReplicaSet shows DESIRED=3, CURRENT=3, READY=3
- [ ] After deleting a pod, new pod created within seconds
- [ ] Pod names are automatically generated (hash suffix)

---

## Lab 2: Create a Deployment (First Steps)

### Objective
Deploy an application using Deployment instead of ReplicaSet directly.

### Step-by-Step

1. Create deployment manifest `lab2-deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.24-alpine
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 5
```

2. Apply the deployment:
```bash
kubectl apply -f lab2-deployment.yaml
```

**Expected output:**
```
deployment.apps/web-app created
```

3. Check deployment status:
```bash
kubectl get deployment web-app
```

**Expected output:**
```
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
web-app   3/3     3            3           30s
```

4. List underlying ReplicaSets:
```bash
kubectl get replicaset -l app=web
```

**Expected output:**
```
NAME                 DESIRED   CURRENT   READY   AGE
web-app-xyz1a2b3c   3         3         3       30s
```

5. List pods:
```bash
kubectl get pods -l app=web
```

**Expected output:**
```
NAME                      READY   STATUS    RESTARTS   AGE
web-app-xyz1a2b3c-abc12   1/1     Running   0          30s
web-app-xyz1a2b3c-def45   1/1     Running   0          30s
web-app-xyz1a2b3c-ghi78   1/1     Running   0          30s
```

6. Port Forward and test locally
```bash
kubectl port-forward deploy/web-app 8090:80
```

### Success Criteria
- [ ] Deployment shows READY=3/3
- [ ] Exactly 1 ReplicaSet exists (the active one)
- [ ] All 3 pods show Running status
- [ ] Pod names include both ReplicaSet hash and pod hash

---

## Lab 3: Rolling Updates (Image Update)

### Objective
Perform a rolling update and observe how Kubernetes gradually replaces pods.

### Setup

Use the deployment from Lab 2 (if not running, create it again):
```bash
kubectl apply -f lab2-deployment.yaml
```

### Step-by-Step

1. Watch the rollout in a separate terminal (leave running):
```bash
kubectl rollout status deployment/web-app --watch
```

2. In another terminal, update the image:
```bash
kubectl set image deployment/web-app nginx=nginx:1.25-alpine
```

**Expected output:**
```
deployment.apps/web-app image updated
```

3. Watch the status terminal — you should see:
```
Waiting for deployment "web-app" to rollout.
Waiting for deployment "web-app" to rollout.
deployment "web-app" successfully rolled out
```

4. Check ReplicaSets during update (quickly):
```bash
kubectl get replicaset -l app=web -o wide
```

**Expected output (if caught mid-update):**
```
NAME                   DESIRED   CURRENT   READY   AGE
web-app-old-hash       1         1         1       5m      (old RS scaling down)
web-app-new-hash       2         2         2       20s     (new RS scaling up)
```

5. After update completes, verify new image:
```bash
kubectl get pods -l app=web -o jsonpath='{.items[0].spec.containers[0].image}'
```

**Expected output:**
```
nginx:1.25-alpine
```

6. Check rollout history:
```bash
kubectl rollout history deployment/web-app
```

**Expected output:**
```
deployment.apps/web-app
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

### Success Criteria
- [ ] Rollout status shows "successfully rolled out"
- [ ] All pods now run `nginx:1.25-alpine`
- [ ] History shows 2 revisions
- [ ] Old ReplicaSet scaled to 0, new ReplicaSet scaled to 3
- [ ] No pods in `Terminating` or `CrashLoopBackOff` state

---

## Lab 4: Rollback a Deployment

### Objective
Demonstrate reverting to a previous deployment version.

### Setup

Ensure you have the deployment with 2 revisions from Lab 3. If not, run Labs 2-3 first.

### Step-by-Step

1. View current deployment:
```bash
kubectl get deployment web-app -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Expected output:**
```
nginx:1.25-alpine
```

2. View revision history:
```bash
kubectl rollout history deployment/web-app
```

**Expected output:**
```
deployment.apps/web-app
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

3. Get details of revision 1:
```bash
kubectl rollout history deployment/web-app --revision=1
```

**Expected output:**
```
deployment.apps/web-app with revision #1
Pod Template:
  Labels:	app=web
  Containers:
   nginx:
    Image:      nginx:1.24-alpine
```

4. Rollback to revision 1:
```bash
kubectl rollout undo deployment/web-app --to-revision=1
```

**Expected output:**
```
deployment.apps/web-app rolled back
```

5. Watch rollout:
```bash
kubectl rollout status deployment/web-app
```

6. Verify the image reverted:
```bash
kubectl get pods -l app=web -o jsonpath='{.items[0].spec.containers[0].image}'
```

**Expected output:**
```
nginx:1.24-alpine
```

7. Check revision history again:
```bash
kubectl rollout history deployment/web-app
```

**Expected output:**
```
deployment.apps/web-app
REVISION  CHANGE-CAUSE
2         <none>
3         <none>
```

Note: Old revision 1 is now revision 3 (history rotates, keeping last 10 by default).

### Success Criteria
- [ ] Rollback command completes successfully
- [ ] All pods revert to `nginx:1.24-alpine`
- [ ] Rollout status shows "successfully rolled out"
- [ ] Revision history shows new entry

---

## Lab 5: Scaling Replicas

### Objective
Practice manual scaling up and down using kubectl.

### Step-by-Step

1. Current state:
```bash
kubectl get deployment web-app
```

**Expected output:**
```
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
web-app   3/3     3            3           10m
```

2. Scale up to 5 replicas:
```bash
kubectl scale deployment/web-app --replicas=5
```

**Expected output:**
```
deployment.apps/web-app scaled
```

3. Watch pods being created:
```bash
kubectl get pods -l app=web --watch
```

You should see 2 new pods in Creating state, then Running. Press Ctrl+C when done.

4. Verify scaling:
```bash
kubectl get deployment web-app
```

**Expected output:**
```
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
web-app   5/5     5            5           10m
```

5. Check ReplicaSet:
```bash
kubectl get replicaset -l app=web
```

Should show DESIRED=5, CURRENT=5, READY=5 for the active ReplicaSet.

6. Now scale down to 2 replicas:
```bash
kubectl scale deployment/web-app --replicas=2
```

7. Watch pods being terminated:
```bash
kubectl get pods -l app=web --watch
```

You should see 3 pods in Terminating state. Press Ctrl+C when done.

8. Final verification:
```bash
kubectl get deployment web-app
kubectl get pods -l app=web
```

Should show READY=2/2 and only 2 pods.

### Success Criteria
- [ ] Scale up to 5 replicas succeeds
- [ ] Scale down to 2 replicas succeeds
- [ ] Deployment READY field matches replica count
- [ ] Pod distribution changes smoothly (no hanging states)

---

## Lab 6: Install Metrics Server and Verify Monitoring

**Objective**: Deploy Metrics Server and test `kubectl top` command.

### Steps:

1. **Check if Metrics Server is installed**:
   ```bash
   kubectl get deployment metrics-server -n kube-system
   ```
   - If it exists, skip to step 3.
   - If not found, proceed to step 2.

2. **Install Metrics Server** (for self-managed clusters):
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

3. **Wait for Metrics Server to be ready**:
   ```bash
   kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=300s
   ```

4. **Verify metrics collection** (wait ~30 seconds for first data):
   ```bash
   kubectl top nodes
   kubectl top pods --all-namespaces
   ```


5. **Troubleshooting** (if no metrics appear):
   - Check Metrics Server logs: `kubectl logs -n kube-system deployment/metrics-server`
   - Common issues:
     - Kubelet API not accessible (firewall/certificate issues)
     - Metrics Server pod not running: `kubectl describe pod -n kube-system -l k8s-app=metrics-server`

---

## Lab 7: Create and Configure HPA

**Objective**: Set up Horizontal Pod Autoscaler targeting CPU utilization.

### 1. Create deployment manifest: `app-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hpa-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hpa-demo
  template:
    metadata:
      labels:
        app: hpa-demo
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests: # Must have resource requests defined
            cpu: "100m"
            memory: "64Mi"
          limits:
            cpu: "500m"
            memory: "256Mi"
```

### 2. Create HPA manifest: `hpa.yaml`

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hpa-demo
  minReplicas: 2
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50  # Scale when average CPU > 50%
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0 # No cool down. The HPA reacts immediately to increased load without waiting to see if the spike is sustained.
      policies:
      - type: Percent # type: Percent, value: 100, periodSeconds: 30: Can double (100%) the current pod count every 30 seconds. So 2 pods → 4 → 8 etc.
        value: 100
        periodSeconds: 30
    scaleDown:
      stabilizationWindowSeconds: 300 # Waits 5 minutes of sustained low load before scaling down, preventing flapping from brief dips in traffic.
      policies:
      - type: Percent # Percent, value: 50, periodSeconds: 60: Can only remove half the pods per minute. So 16 → 8 → 4 → 2, stepping down gradually.
        value: 50
        periodSeconds: 60
```


### Steps:

1. **Deploy the application and the HPA**:
   ```bash
   kubectl apply -f app-deployment.yaml
   kubectl apply -f hpa.yaml
   ```

2. **Verify HPA creation**:
   ```bash
   kubectl get hpa
   kubectl describe hpa hpa-demo
   ```

3. **View HPA status repeatedly**:
   ```bash
   kubectl get hpa hpa-demo --watch
   ```

4. **Examine HPA events**:
   ```bash
   kubectl describe hpa hpa-demo
   kubectl get events --sort-by='.lastTimestamp' | grep hpa-demo
   ```

---

## Lab 8: Generate Load and Watch HPA Scale

**Objective**: Create CPU load and observe pods scale up in real-time.

### Steps:

1. **Open three terminals**:

   **Terminal 1 - Watch HPA status**:
   ```bash
   kubectl get hpa hpa-demo --watch
   ```

   **Terminal 2 - Watch pod count**:
   ```bash
   kubectl get pods -l app=hpa-demo --watch
   ```

2. **Generate load** (Terminal 3):
   ```bash
   # Get the service IP or LoadBalancer endpoint
   SERVICE_IP=$(kubectl get svc hpa-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

   # Generate continuous HTTP requests (using kubectl run)
   kubectl run -it --rm load-generator --image=busybox /bin/sh

   # Inside the load-generator pod:
   while true; do wget -q -O- http://hpa-demo; done
   ```

3. **Observe scaling**:
   - Within 1-2 minutes, metrics should show increasing CPU usage
   - HPA should calculate desired replicas and scale up
   - Watch Terminal 2 for new pods appearing
   - Terminal 1 shows replica count increasing

4. **Monitor HPA decision calculation**:
   ```bash
   kubectl describe hpa hpa-demo
   ```
   Look for `Current Metrics` showing actual CPU utilization percentage.

---

## Lab 9: Deploy Cluster Autoscaler on EKS

**Objective**: Install and configure the Kubernetes Cluster Autoscaler on an EKS cluster so that worker nodes scale automatically when pods cannot be scheduled due to insufficient resources.

**Why is this needed?** HPA scales pods, but if the existing nodes don't have enough capacity for those new pods, they remain in `Pending` state. The Cluster Autoscaler watches for unschedulable pods and automatically adds nodes by adjusting the EC2 Auto Scaling Group (ASG) desired capacity. It also removes underutilized nodes to save costs.

### Step 1: Verify Your Node Group's ASG Configuration

Before installing the Cluster Autoscaler, check your node group's Auto Scaling Group settings and increase the maximum capacity to allow scaling:

```bash
# Find the ASG name for your cluster
# Replace <your-cluster-name> with your actual EKS cluster name
export CLUSTER_NAME=<your-cluster-name>

aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[? Tags[? (Key=='eks:cluster-name') && Value=='${CLUSTER_NAME}']].[AutoScalingGroupName, MinSize, MaxSize, DesiredCapacity]" \
  --output table
```

Increase the max capacity to allow the autoscaler room to add nodes:

```bash
# Get the ASG name
export ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[? Tags[? (Key=='eks:cluster-name') && Value=='${CLUSTER_NAME}']].AutoScalingGroupName" \
  --output text)

# Update max capacity (e.g., allow up to 5 nodes)
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name ${ASG_NAME} \
  --min-size 2 \
  --desired-capacity 2 \
  --max-size 5

# Verify the updated values
aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[? Tags[? (Key=='eks:cluster-name') && Value=='${CLUSTER_NAME}']].[AutoScalingGroupName, MinSize, MaxSize, DesiredCapacity]" \
  --output table
```

### Step 2: Create an IAM Policy for Cluster Autoscaler

The Cluster Autoscaler needs permissions to describe and modify Auto Scaling Groups.

1. Create the policy JSON file:

```bash
cat > cluster-autoscaler-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeLaunchTemplateVersions"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
```

2. Create the IAM policy:

```bash
aws iam create-policy \
  --policy-name AmazonEKSClusterAutoscalerPolicy \
  --policy-document file://cluster-autoscaler-policy.json
```

Note the **Policy ARN** from the output — you will need it in Step 3.

### Step 3: Create an IAM Role for the Cluster Autoscaler Service Account

- Open the IAM console at https://console.aws.amazon.com/iam/.
- In the left navigation pane, choose **Roles**.
- On the Roles page, choose **Create role**.
- On the Select trusted entity page, do the following:
  - In the Trusted entity type section, choose **Web identity**.
  - For Identity provider, choose the **OpenID Connect provider URL** for your cluster (as shown under Overview in Amazon EKS).
  - For Audience, choose **sts.amazonaws.com**.
  - Choose **Next**.
- On the Add permissions page, do the following:
  - In the Filter policies box, enter **AmazonEKSClusterAutoscalerPolicy**.
  - Select the check box to the left of the **AmazonEKSClusterAutoscalerPolicy** returned in the search.
  - Choose **Next**.
- On the Name, review, and create page, do the following:
  - For Role name, enter **AmazonEKS_Cluster_Autoscaler_Role**.
  - Choose **Create role**.
- After the role is created, choose the role in the console to open it for editing.
- Choose the **Trust relationships** tab, and then choose **Edit trust policy**.
- Find the line that looks similar to the following line:

```
"oidc.eks.region-code.amazonaws.com/id/CF856D2CC9C5E229C4C6D3D43B178C5E:aud": "sts.amazonaws.com"
```

- Add a comma to the end of the previous line, and then add the following line after it. Replace `region-code` with the AWS Region that your cluster is in. Replace `CF856D2CC9C5E229C4C6D3D43B178C5E` with your cluster's OIDC provider ID.

```
"oidc.eks.region-code.amazonaws.com/id/CF856D2CC9C5E229C4C6D3D43B178C5E:sub": "system:serviceaccount:kube-system:cluster-autoscaler"
```

- Choose **Update policy** to finish.
- Note the **Role ARN** — you will need it in Step 4.

### Step 4: Deploy the Cluster Autoscaler

1. Download the Cluster Autoscaler manifest:

```bash
curl -o cluster-autoscaler-autodiscover.yaml \
  https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

2. Edit the manifest — replace `<YOUR CLUSTER NAME>` with your actual cluster name:

```bash
sed -i "s/<YOUR CLUSTER NAME>/${CLUSTER_NAME}/g" cluster-autoscaler-autodiscover.yaml
```

3. Annotate the Service Account in the manifest with the IAM role ARN. Open `cluster-autoscaler-autodiscover.yaml` and add the annotation under the ServiceAccount section:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/AmazonEKS_Cluster_Autoscaler_Role
```

4. Apply the manifest:

```bash
kubectl apply -f cluster-autoscaler-autodiscover.yaml
```

5. Add the safe-to-evict annotation to prevent the Cluster Autoscaler from evicting itself:

```bash
kubectl -n kube-system annotate deployment.apps/cluster-autoscaler \
  cluster-autoscaler.kubernetes.io/safe-to-evict="false"
```

6. Set the Cluster Autoscaler image to match your Kubernetes version. Check the [Cluster Autoscaler releases page](https://github.com/kubernetes/autoscaler/releases) for the version that matches your cluster:

```bash
# Check your cluster's Kubernetes version
kubectl version --short

# Update the image (replace v1.XX.X with the matching version)
kubectl set image deployment cluster-autoscaler \
  -n kube-system \
  cluster-autoscaler=registry.k8s.io/autoscaling/cluster-autoscaler:v1.XX.X
```

### Step 5: Verify the Cluster Autoscaler is Running

```bash
# Check the pod is running
kubectl get pods -n kube-system -l app=cluster-autoscaler

# Check the logs
kubectl logs -n kube-system deployment/cluster-autoscaler | tail -20
```

You should see log entries indicating the autoscaler is scanning for unschedulable pods and monitoring node utilization.

---

## Lab 10: Test Cluster Autoscaler - Scale Nodes Up and Down

**Objective**: Create a workload that exceeds current node capacity and observe the Cluster Autoscaler add new nodes automatically.

### Steps:

1. **Check the current node count**:

```bash
kubectl get nodes
```

Note the current number of nodes (e.g., 2).

2. **Open monitoring terminals**:

   **Terminal 1 - Watch nodes**:
   ```bash
   kubectl get nodes --watch
   ```

   **Terminal 2 - Watch pods**:
   ```bash
   kubectl get pods -l app=ca-test --watch
   ```

   **Terminal 3 - Watch Cluster Autoscaler logs**:
   ```bash
   kubectl logs -f -n kube-system deployment/cluster-autoscaler
   ```

3. **Deploy a workload that requests more resources than available**:

```bash
cat > ca-test-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ca-test
spec:
  replicas: 15
  selector:
    matchLabels:
      app: ca-test
  template:
    metadata:
      labels:
        app: ca-test
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        resources:
          requests:
            cpu: "200m"
            memory: "128Mi"
EOF

kubectl apply -f ca-test-deployment.yaml
```

4. **Observe the scaling behavior**:

```bash
# Check for pending pods (these trigger the autoscaler)
kubectl get pods -l app=ca-test | grep Pending

# Check Cluster Autoscaler activity
kubectl logs -n kube-system deployment/cluster-autoscaler | grep -i "scale up"
```

- Some pods will go into `Pending` state because existing nodes don't have enough capacity.
- The Cluster Autoscaler detects these pending pods within ~10 seconds.
- It calculates that a new node is needed and increases the ASG desired capacity.
- A new EC2 instance launches (takes ~2-3 minutes to join the cluster).
- Once the new node is `Ready`, pending pods get scheduled on it.

5. **Verify a new node was added**:

```bash
kubectl get nodes
# You should see more nodes than before
```

6. **Test scale-down — reduce the workload**:

```bash
kubectl scale deployment ca-test --replicas=2
```

- Wait ~10 minutes (the default scale-down delay).
- The Cluster Autoscaler identifies underutilized nodes (below 50% utilization by default).
- It drains the node and terminates the EC2 instance.

```bash
# Watch the nodes reduce over time
kubectl get nodes --watch

# Check autoscaler logs for scale-down activity
kubectl logs -n kube-system deployment/cluster-autoscaler | grep -i "scale down"
```

7. **Cleanup**:

```bash
kubectl delete deployment ca-test
```

**Key Takeaway:** The Cluster Autoscaler complements HPA by ensuring there is always enough node capacity for the pods that HPA creates. HPA scales pods, Cluster Autoscaler scales nodes.

---