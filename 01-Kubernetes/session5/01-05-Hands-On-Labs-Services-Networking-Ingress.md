# Session 01-05:  Networking - Services & Ingress

---

## Lab 1: Create a ClusterIP Service

### Objective
Deploy a simple nginx Pod and expose it via a ClusterIP Service. Test connectivity from within the cluster.

### Prerequisites
- Kubernetes cluster running (minikube, kind, or EKS)
- kubectl configured
- Basic understanding of Pods and manifests

### Steps

1. **Create an nginx deployment**
   ```bash
   kubectl create deployment nginx-app --image=nginx:latest --replicas=3
   kubectl get pods
   ```
   Expected: 3 nginx pods running

2. **Expose the deployment with a ClusterIP service**

   Create a file named `nginx-clusterip-service.yaml`:
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: nginx-service
   spec:
     type: ClusterIP
     selector:
       app: nginx-app
     ports:
       - port: 80
         targetPort: 80
   ```
   ```bash
   kubectl apply -f nginx-clusterip-service.yaml
   kubectl get svc
   ```
   Expected output shows `nginx-service` with a ClusterIP (e.g., 10.96.x.x)

3. **Inspect the service details**
   ```bash
   kubectl describe svc nginx-service
   ```
   Note:
   - ClusterIP: stable internal IP
   - Endpoints: list of Pod IPs that back this service
   - Port mapping: 80 → 80
   - Selector: app=nginx-app (matches Pod labels)

4. **Test service connectivity from inside the cluster**
   ```bash
   # Get the name of one nginx pod
   POD_NAME=$(kubectl get pods -l app=nginx-app -o jsonpath='{.items[0].metadata.name}')

   # Execute curl from inside the pod to test the service
   kubectl exec -it $POD_NAME -- curl http://nginx-service:80
   ```
   Expected: nginx welcome page HTML output

5. **Test DNS resolution**
   ```bash
   kubectl exec -it $POD_NAME -- nslookup nginx-service
   ```
   Expected: Resolves to the ClusterIP

6. **Test with full FQDN**
   ```bash
   kubectl exec -it $POD_NAME -- curl http://nginx-service.default.svc.cluster.local:80
   ```
   Expected: Same as step 4


### Troubleshooting
- **Service DNS not resolving**: Check CoreDNS pods are running (`kubectl get pods -n kube-system -l k8s-app=kube-dns`)
- **No endpoints shown**: Verify Pod labels match service selector (`kubectl get pods --show-labels`)
- **Connection refused**: Ensure target-port matches Pod container port (80 for nginx)

---

## Lab 2: Create a NodePort Service

### Objective
Expose the nginx application on a NodePort so it's accessible from outside the cluster.

### Prerequisites
- Lab 1 completed (nginx deployment running)
- Access to a worker node IP
- Network access to worker nodes

### Steps

1. **Create a NodePort service**

   Create a file named `nginx-nodeport-service.yaml`:
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: nginx-nodeport
   spec:
     type: NodePort
     selector:
       app: nginx-app
     ports:
       - port: 80
         targetPort: 80
         # nodePort is optional - omit to let Kubernetes auto-assign in range 30000-32767
   ```
   ```bash
   kubectl apply -f nginx-nodeport-service.yaml
   kubectl get svc
   ```
   Expected output shows `nginx-nodeport` with NodePort (30000-32767)

2. **Get the assigned NodePort**
   ```bash
   NODE_PORT=$(kubectl get svc nginx-nodeport -o jsonpath='{.spec.ports[0].nodePort}')
   echo "NodePort: $NODE_PORT"
   ```
   Example: 30845

3. **Get a worker node IP**
   ```bash
   NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
   echo "Node IP: $NODE_IP"
   ```

4. **Access the service from outside the cluster**

   Pre-req: Make sure that the node's Security Group in AWS has NodePort added in the Inbound rule from your IP or from everywhere for demo purpose

   ```bash
   # Replace with your actual IP and port
   curl http://<NODE_IP>:<NODE_PORT>
   ```
   or Open it in the browser

   Expected: nginx welcome page HTML output

5. **Verify the service has both ClusterIP and NodePort**
   ```bash
   kubectl describe svc nginx-nodeport
   ```
   Note:
   - ClusterIP: Still has internal IP
   - Port: 80/TCP (internal)
   - NodePort: 30xxx/TCP (external)

6. **Test round-robin across nodes**
   ```bash
   # If using minikube, test local access
   minikube ssh
   curl localhost:<NODE_PORT>
   # or from host
   curl http://$(minikube ip):<NODE_PORT>
   ```

---

## Lab 3: Create a LoadBalancer Service

### Objective
Expose nginx via a cloud provider LoadBalancer (for EKS)

### Prerequisites
- Running on cloud Kubernetes (EKS)

### Steps

1. **Create a LoadBalancer service**

   Create a file named `nginx-lb-service.yaml`:
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: nginx-lb
   spec:
     type: LoadBalancer
     selector:
       app: nginx-app
     ports:
       - port: 80
         targetPort: 80
   ```
   ```bash
   kubectl apply -f nginx-lb-service.yaml
   kubectl get svc
   ```
   Expected: Service shows `<pending>` for EXTERNAL-IP initially

2. **Wait for external IP to be assigned**
   ```bash
   # Watch for EXTERNAL-IP to appear
   kubectl get svc nginx-lb --watch

   # For EKS: Usually assigned within 1-2 minutes
   ```

3. **Get the external IP and access the service**
   ```bash
   EXTERNAL_IP=$(kubectl get svc nginx-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   echo "External IP: $EXTERNAL_IP"

   curl http://$EXTERNAL_IP:80
   ```
   Expected: nginx welcome page HTML output

4. **Inspect the service details**
   ```bash
   kubectl describe svc nginx-lb
   ```
   Note:
   - ClusterIP: Still present for internal routing
   - Port: 80/TCP
   - NodePort: Also assigned (30000-32767)
   - LoadBalancer Ingress: Shows cloud LB IP or hostname (EKS provisions an NLB by default)

5. **Verify routing path**
   - External request hits cloud Layer 4 load balancer (e.g., AWS NLB)
   - LB forwards to node on NodePort
   - kube-proxy forwards to Pod on target-port


6. **Create an NLB with annotations**

   Create a file named `nginx-lb-service-nlb.yaml`:
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: nginx-lb-nlb
     annotations:
       service.beta.kubernetes.io/aws-load-balancer-type: "nlb"  # Use Network Load Balancer
       service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
       service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
       service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
   spec:
     selector:
       app: nginx-app
     ports:
       - protocol: TCP
         port: 80
         targetPort: 80
     type: LoadBalancer
   ```

   ```bash
   kubectl apply -f nginx-lb-service-nlb.yaml
   kubectl get svc
   ```
   Expected: Service shows `<pending>` for EXTERNAL-IP initially
   then a NLB gets created

---

## Lab 4: Service Discovery with DNS

### Objective
Understand how Kubernetes DNS resolves service names and test various FQDN formats.

### Prerequisites
- Lab 1-3 completed (services running)
- kubectl configured

### Steps

1. **Verify CoreDNS is running**
   ```bash
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   # or for newer versions
   kubectl get deployment -n kube-system coredns
   ```
   Expected: CoreDNS pod(s) in Running state

2. **Deploy a test pod for DNS queries**
   ```bash
   kubectl run -it dns-test --image=alpine --restart=Never -- sh

   # Inside the pod:
   apk add --no-cache curl
   apk add --no-cache bind-tools
   ```

3. **Test DNS resolution with short name**
   ```bash
   # Still inside dns-test pod
   nslookup nginx-service
   # or using dig
   dig nginx-service
   ```
   Expected: Resolves to the ClusterIP (10.96.x.x)

4. **Test DNS with namespace**
   ```bash
   nslookup nginx-service.default
   ```
   Expected: Same IP as short name

5. **Test full FQDN**
   ```bash
   nslookup nginx-service.default.svc.cluster.local
   ```
   Expected: Same IP as previous tests

6. **Test service connectivity via DNS name**
   ```bash
   curl http://nginx-service
   curl http://nginx-service.default.svc.cluster.local:80
   ```
   Expected: nginx welcome page

   ```bash
   kubectl delete pod dns-test
   ```

7. **Test DNS for service in different namespace**
   ```bash
   # Create another namespace
   kubectl create namespace dev

   # Create a ClusterIP service in the dev namespace
   ```
   Create a file named `web-service-dev.yaml`:
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: web-service
     namespace: dev
   spec:
     type: ClusterIP
     selector:
       app: nginx-app
     ports:
       - port: 80
         targetPort: 80
   ```
   ```bash
   kubectl apply -f web-service-dev.yaml

   # From dns-test pod, resolve it
   nslookup web-service.dev.svc.cluster.local
   ```
   Expected: Different ClusterIP from the default namespace service

8. **Test DNS timeout for non-existent service**
   ```bash
   nslookup nonexistent-service
   ```
   Expected: NXDOMAIN or timeout

9. **Exit the test pod**
   ```bash
   exit
   kubectl delete pod dns-test
   ```

### Troubleshooting
- **DNS resolution fails**: Check CoreDNS logs: `kubectl logs -n kube-system -l k8s-app=kube-dns`
- **Cannot resolve other namespace service**: Must use full FQDN: `service.namespace.svc.cluster.local`

---

## Lab 5: Install AWS Load Balancer Controller

### Overview
In this session, you'll deploy AWS Load Balancer Controller, create sample applications, and implement path-based routing using Ingress. You'll verify that AWS creates an ALB for your Ingress and that traffic correctly routes to your applications.

**Prerequisites:**
- EKS cluster running
- kubectl configured to access your cluster
- Helm 3+ installed
- AWS CLI configured with cluster access

### Pre-Req: 

Helm 3 Installation: https://helm.sh/docs/intro/install/

### Goal
Install AWS Load Balancer Controller via Helm using the IRSA service account.

### Step 1 - Create the IAM Policy

1. Go to **AWS Console → IAM → Policies → Create Policy**
2. Switch to **JSON** view and paste the official policy from:
   ```
   https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
   ```
3. Name it `AWSLoadBalancerControllerIAMPolicy`
4. Review and create the policy

---

### Step 2 - Create the OIDC Identity Provider for Your EKS Cluster

1. Go to **AWS Console → IAM → Identity Providers → Add Provider**
2. Select **OpenID Connect**
3. Get your OIDC provider URL from:
   **EKS Console → Your Cluster → Details → OpenID Connect provider URL**
4. Set **Audience** to `sts.amazonaws.com`
5. Verify thumbprint and create the provider

---

### Step 3 - Create the IAM Role

1. Go to **AWS Console → IAM → Roles → Create Role**
2. Select **Web Identity** as the trusted entity type
3. Select the OIDC Provider you just created
4. Set **Audience** to `sts.amazonaws.com`
5. In the trust relationship, update the `StringEquals` condition as follows - replace `${OIDC_PROVIDER}` with the OIDC URL copied from the EKS details page (without the `https://` prefix):

   ```json
   "StringEquals": {
     "${OIDC_PROVIDER}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
     "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
   }
   ```

6. Attach the `AWSLoadBalancerControllerIAMPolicy` created in Step 1
7. Name the role - e.g., `AWSLoadBalancerControllerRole`

---

### Step 4 - Add the EKS Helm Repository

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

**Expected output:**
```
"eks" has been added to your repositories
Hang tight while we grab the latest from your chart repositories...
Successfully got an update from the "eks" chart repository
```

---

### Step 5 - Install the AWS Load Balancer Controller

Connect to your EKS cluster
```bash
aws eks update-kubeconfig --region <aws-region> --name <your-cluster-name>
```

Make sure to update the command with actual values from your EKS cluster

```bash
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<your-cluster-name> \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations.eks\.amazonaws\.com/role-arn="<arn-of-iam-role-from-step-3>" \
  --set region=<aws-region> \
  --set vpcId="<vpc-id-of-eks-cluster>" \
  --set enableWaf="false" \
  --set enableWafv2="false"
```

working command for mac:

```bash
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=EKS-B15 \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set-string serviceAccount.annotations.eks\\.amazonaws\\.com\\/role-arn=arn:aws:iam::233245302554:role/AWSLBCROLE \
  --set region=ap-south-1 \
  --set vpcId=vpc-067db2a4438ac151a
```
---

### Step 6 - Verify the Installation

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```

**Expected output:**
```
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
aws-load-balancer-controller   2/2     2            2           2m

aws-load-balancer-controller-789abc123-def45   1/1   Running   0   2m
aws-load-balancer-controller-789abc123-ghi67   1/1   Running   0   2m
```

Check logs to confirm the controller is healthy and watching for Ingress resources:
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

---

## Lab 6: Deploy Two Sample Applications & Create Path-Based Ingress

### Goal
Create two simple web applications with custom HTML pages and ClusterIP services so we can route to them via Ingress Then create an Ingress resource that routes traffic to different services based on URL path using the AWS Load Balancer Controller.


### Step 1 - Deploy App 1

Create file `app1-deployment.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app1-config
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <body>
        <h1>Hello, World, I am serving from app1!</h1>
    </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
      - name: app1
        image: nginx
        volumeMounts:
        - name: app1-volume
          mountPath: /usr/share/nginx/html/app1
        ports:
        - containerPort: 80
      volumes:
      - name: app1-volume
        configMap:
          name: app1-config
---
apiVersion: v1
kind: Service
metadata:
  name: app1-service
spec:
  type: ClusterIP
  selector:
    app: app1
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

Deploy:
```bash
kubectl apply -f app1-deployment.yaml
```

Verify:
```bash
kubectl get pods -l app=app1
kubectl get svc app1-service
```

### Step 2 - Deploy App 2

Create file `app2-deployment.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app2-config
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <body>
        <h1>Hello, World, I am serving from app2!</h1>
    </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app2
  template:
    metadata:
      labels:
        app: app2
    spec:
      containers:
      - name: app2
        image: nginx
        volumeMounts:
        - name: app2-volume
          mountPath: /usr/share/nginx/html/app2
        ports:
        - containerPort: 80
      volumes:
      - name: app2-volume
        configMap:
          name: app2-config
---
apiVersion: v1
kind: Service
metadata:
  name: app2-service
spec:
  type: ClusterIP
  selector:
    app: app2
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

Deploy:
```bash
kubectl apply -f app2-deployment.yaml
```

Verify:
```bash
kubectl get pods -l app=app2
kubectl get svc app2-service
```

### Step 3 - Create Ingress Manifest

Create file `ingress-alb.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-ingress-alb
  namespace: default
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /app1
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 80
      - path: /app2
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 80
```

### Step 4 - Deploy Ingress

```bash
kubectl apply -f ingress-alb.yaml
```

Check status:
```bash
kubectl get ingress
```

**Initial output (ALB creation in progress):**
```
NAME               CLASS   HOSTS   ADDRESS   PORTS   AGE
demo-ingress-alb   alb     *                 80      10s
```

Wait for the ADDRESS field to populate - this takes 2–3 minutes while the ALB is being provisioned:
```bash
kubectl get ingress -w
```

**Once ready:**
```
NAME               CLASS   HOSTS   ADDRESS                                                   PORTS   AGE
demo-ingress-alb   alb     *       k8s-default-demoingr-xyz123.us-east-1.elb.amazonaws.com   80      3m
```

### Step 5 - Retrieve ALB DNS Name

```bash
ALB_DNS=$(kubectl get ingress demo-ingress-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $ALB_DNS
```

Save this DNS name - you'll use it to test routing.

---

## Lab 7: Test Traffic Routing

### Goal
Verify that traffic correctly routes to the right service based on path.

### Step 1 - Test /app1 Path

```bash
ALB_DNS=$(kubectl get ingress demo-ingress-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$ALB_DNS/app1/
```

**Expected output:**
```html
<!DOCTYPE html>
<html>
<body>
    <h1>Hello, World, I am serving from app1!</h1>
</body>
</html>
```

### Step 2 - Test /app2 Path

```bash
curl http://$ALB_DNS/app2/
```

**Expected output:**
```html
<!DOCTYPE html>
<html>
<body>
    <h1>Hello, World, I am serving from app2!</h1>
</body>
</html>
```

### Step 3 - Test Non-Existent Path

```bash
curl http://$ALB_DNS/admin
```

**Expected output:**
HTTP 404 - no routing rule is configured for this path.

---

## Lab 8: Host-Based Routing (Optional/Self-Practice)

### Goal
If you have a domain, implement host-based routing.

### Step 1 - Create Host-Based Ingress

Create file `ingress-host-based.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-host-ingress
  namespace: default
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
spec:
  ingressClassName: alb
  rules:
  - host: app1.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 80
  - host: app2.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 80
```

### Step 2 - Deploy and Test

```bash
kubectl apply -f ingress-host-based.yaml

# Get ALB DNS
ALB_DNS=$(kubectl get ingress demo-host-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test with Host header (if you don't own the domain)
curl -H "Host: app1.yourdomain.com" http://$ALB_DNS/
curl -H "Host: app2.yourdomain.com" http://$ALB_DNS/
```

If you own the domain, update your DNS records:
```
app1.yourdomain.com    CNAME    <ALB_DNS>
app2.yourdomain.com    CNAME    <ALB_DNS>
```

Then test directly:
```bash
curl http://app1.yourdomain.com/
curl http://app2.yourdomain.com/
```

---

## Clean Up

### Goal
Remove all resources created in this session.

### Step 1 - Delete Ingress Resources

```bash
kubectl delete ingress demo-ingress-alb
kubectl delete ingress demo-host-ingress
```

Verify the ALB is deleted in AWS Console (takes ~1–2 minutes):
```bash
# Check AWS Console → EC2 → Load Balancers
# The ALB should disappear
```

### Step 2 - Delete Applications

```bash
kubectl delete -f app1-deployment.yaml
kubectl delete -f app2-deployment.yaml
```

This deletes the Deployments, Services, and ConfigMaps for both apps.

### Step 3 - (Optional) Uninstall AWS LBC

```bash
helm uninstall aws-load-balancer-controller -n kube-system
kubectl delete serviceaccount aws-load-balancer-controller -n kube-system
```

> Keep AWS LBC installed if you'll use it for future sessions.

### Step 4 - Verify Cleanup

```bash
kubectl get ingress
kubectl get deployment
kubectl get svc
kubectl get configmap
```

Should show no resources (except the default `kubernetes` service and `kube-root-ca.crt` configmap).

---

## Troubleshooting

### Issue: Ingress ADDRESS stays `<pending>`

**Cause:** AWS LBC isn't running or has permission issues.

**Fix:**
```bash
# Check AWS LBC pods
kubectl get pods -n kube-system | grep aws-load-balancer

# Check logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check IRSA annotation on the service account
kubectl describe sa aws-load-balancer-controller -n kube-system
```

### Issue: ALB targets show "Unhealthy"

**Cause:** Pods aren't responding to health checks on the expected path.

**Fix:**
```bash
# Check pod logs
kubectl logs -l app=app1

# Check pod is running
kubectl get pods -l app=app1

# Test the path from inside the pod
kubectl exec -it <pod-name> -- curl localhost:80/app1/
```

> Note: The ALB health check will probe `/app1` on the pod. Make sure the ConfigMap content is mounted correctly and the path resolves.

### Issue: curl returns 404 or Connection Refused

**Cause:** Target group not yet healthy, or the path in your curl doesn't match the Ingress rule.

**Fix:**
1. Wait 30–60 seconds for health checks to pass after ALB creation
2. Verify the path in your `curl` command matches exactly what's in the Ingress (e.g., `/app1/` vs `/app1`)
3. Check ALB listener rules in the AWS Console