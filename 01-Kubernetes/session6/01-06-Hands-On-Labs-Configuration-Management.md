# Session 01-06: ConfigMaps, Secrets, Namespaces, and DaemonSets

- Hands-On Labs


This document contains 6 practical labs to build hands-on experience with ConfigMaps, Secrets, Namespaces, and DaemonSets.

---

## Lab 1: Create and Use ConfigMaps

### Objective
Create ConfigMaps from literals and files, then inject them as environment variables and volume mounts into deployments.

### Prerequisites
- Working Kubernetes cluster (minikube, kind, or EKS)
- kubectl configured
- A text editor

### Steps

#### 1.1: Create ConfigMap from Literals

Create the file `app-config.yaml` with the following content:

```yaml
# app-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  db_host: "postgres.default.svc.cluster.local"
  db_port: "5432"
  log_level: "info"
  cache_ttl: "3600"
```

```bash
kubectl apply -f app-config.yaml
```

#### 1.2: Verify the ConfigMap
```bash
# Get ConfigMap details
kubectl get configmap app-config
kubectl describe configmap app-config
kubectl get configmap app-config -o yaml
```

Expected output shows key-value pairs under `data:` field.

#### 1.3: Create a file-based ConfigMap

Create the file `nginx-config.yaml` with the following content:

```yaml
# nginx-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    server {
        listen 80;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
```

```bash
kubectl apply -f nginx-config.yaml
kubectl get configmap nginx-config -o yaml
```

#### 1.4: Inject ConfigMap as Environment Variables
Create the file `deploy-with-env.yaml` with the following content:

```yaml
# deploy-with-env.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deploy-env
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-env
  template:
    metadata:
      labels:
        app: app-env
    spec:
      containers:
      - name: app
        image: busybox
        command: ['sh', '-c', 'echo DB_HOST=$DB_HOST, LOG_LEVEL=$LOG_LEVEL; sleep 10000']
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: db_host
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: db_port
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: log_level
```

```bash
kubectl apply -f deploy-with-env.yaml
kubectl logs deployment/app-deploy-env
```

Expected output shows environment variables properly set.

#### 1.5: Inject All ConfigMap Keys as Environment Variables
Create the file `deploy-with-envfrom.yaml` with the following content:

```yaml
# deploy-with-envfrom.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deploy-envfrom
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-envfrom
  template:
    metadata:
      labels:
        app: app-envfrom
    spec:
      containers:
      - name: app
        image: busybox
        command: ['sh', '-c', 'env | sort; sleep 10000']
        envFrom:
        - configMapRef:
            name: app-config
```

```bash
kubectl apply -f deploy-with-envfrom.yaml
kubectl logs deployment/app-deploy-envfrom | grep -E "db_|log_|cache_"
```

All ConfigMap keys should appear as environment variables.

#### 1.6: Mount ConfigMap as Volume
Create the file `nginx-deploy-volume.yaml` with the following content:

```yaml
# nginx-deploy-volume.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-vol
  template:
    metadata:
      labels:
        app: nginx-vol
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: config
        configMap:
          name: nginx-config
```

```bash
kubectl apply -f nginx-deploy-volume.yaml
POD=$(kubectl get pods -l app=nginx-vol -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- cat /etc/nginx/conf.d/nginx.conf
```

ConfigMap file should be readable at the mount point.

---

## Lab 2: Create and Use Secrets

### Objective
Create Secrets using stringData and data fields, understand base64 encoding, and mount secrets in deployments.

### Prerequisites
- Lab 1 completed
- Understanding of base64 encoding

### Steps

#### 2.1: Create Secret Using stringData
Create the file `db-secret.yaml` with the following content:

```yaml
# db-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  username: admin
  password: SuperSecure!Pass123
  connection_string: "postgresql://admin:SuperSecure!Pass123@postgres:5432/mydb"
```

```bash
kubectl apply -f db-secret.yaml
kubectl get secret db-credentials
```

#### 2.2: Verify Secret Encoding
```bash
# View the secret in YAML (base64 encoded)
kubectl get secret db-credentials -o yaml

# Decode the base64 password
kubectl get secret db-credentials -o jsonpath='{.data.password}' | base64 -d
```

Output should show the decoded password.

#### 2.3: Create Secret Declaratively
Create the file `api-secret.yaml` with the following content:

```yaml
# api-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-secret
type: Opaque
stringData:
  api_key: "sk-1234567890abcdef"
  api_token: "token_xyz_789"
```

```bash
kubectl apply -f api-secret.yaml
kubectl get secret api-secret -o yaml
```

#### 2.4: Inject Secret as Environment Variables
Create the file `deploy-with-secret.yaml` with the following content:

```yaml
# deploy-with-secret.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-secret
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-secret
  template:
    metadata:
      labels:
        app: app-secret
    spec:
      containers:
      - name: app
        image: busybox
        command: ['sh', '-c', 'echo "DB User: $DB_USER, DB Pass: $DB_PASS"; sleep 10000']
        env:
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: DB_PASS
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
```

```bash
kubectl apply -f deploy-with-secret.yaml
kubectl logs deployment/app-with-secret
```

Environment variables should show the secret values.

#### 2.5: Mount Secret as Volume Files
Create the file `deploy-secret-volume.yaml` with the following content:

```yaml
# deploy-secret-volume.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-secret-volume
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-secret-vol
  template:
    metadata:
      labels:
        app: app-secret-vol
    spec:
      containers:
      - name: app
        image: busybox
        command: ['sh', '-c', 'ls -la /etc/db-secret && cat /etc/db-secret/username && sleep 10000']
        volumeMounts:
        - name: db-secret
          mountPath: /etc/db-secret
          readOnly: true
      volumes:
      - name: db-secret
        secret:
          secretName: db-credentials
          defaultMode: 0400
```

```bash
kubectl apply -f deploy-secret-volume.yaml
kubectl logs deployment/app-secret-volume
```

Secret files should be readable with proper permissions.

#### 2.6: Demonstrate Base64 Encoding

Create the file `manual-secret.yaml` with the following content:

```yaml
# manual-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: manual-secret
type: Opaque
data:
  secret_key: bXlQYXNzd29yZDEyMw==
```

> **Note:** The value `bXlQYXNzd29yZDEyMw==` is the base64 encoding of `myPassword123`.  
> You can verify with: `echo -n "myPassword123" | base64`

```bash
kubectl apply -f manual-secret.yaml

# Decode it back
kubectl get secret manual-secret -o jsonpath='{.data.secret_key}' | base64 -d
```

Output should show the original password.

---

## Lab 3: ConfigMap as Volume Mount (Nginx Example)

### Objective
Mount a ConfigMap containing HTML files and Nginx configuration into an Nginx deployment.

### Prerequisites
- Lab 1 completed
- Docker/container knowledge helpful

### Steps

#### 3.1: Create ConfigMaps for HTML and Configuration

Create the file `nginx-html-configmap.yaml` with the following content:

```yaml
# nginx-html-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-html
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>ConfigMap Demo</title>
    </head>
    <body>
        <h1>Hello from ConfigMap!</h1>
        <p>This HTML is served from a ConfigMap-mounted volume.</p>
    </body>
    </html>
```

Create the file `nginx-conf-configmap.yaml` with the following content:

```yaml
# nginx-conf-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-conf
data:
  nginx.conf: |
    server {
        listen 80;
        server_name _;

        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
        }

        location /health {
            access_log off;
            return 200 "Healthy\n";
            add_header Content-Type text/plain;
        }
    }
```

```bash
kubectl apply -f nginx-html-configmap.yaml
kubectl apply -f nginx-conf-configmap.yaml
```

#### 3.2: Create Nginx Deployment with Mounted ConfigMaps
Create the file `nginx-configmap-deploy.yaml` with the following content:

```yaml
# nginx-configmap-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-config-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-demo
  template:
    metadata:
      labels:
        app: nginx-demo
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
          name: http
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
        - name: config
          mountPath: /etc/nginx/conf.d
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
      volumes:
      - name: html
        configMap:
          name: nginx-html
      - name: config
        configMap:
          name: nginx-conf
```

```bash
kubectl apply -f nginx-configmap-deploy.yaml
kubectl wait --for=condition=ready pod -l app=nginx-demo --timeout=30s
```

#### 3.3: Verify Nginx Configuration
```bash
# Port forward to access nginx
POD=$(kubectl get pods -l app=nginx-demo -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward $POD 8080:80 &

# Test the web server
curl http://localhost:8080/
curl http://localhost:8080/health

# Kill the port-forward
pkill -f "port-forward"
```

Both endpoints should respond successfully.

#### 3.4: Update ConfigMap and Observe Changes

Update the file `nginx-html-configmap.yaml` with new content:

```yaml
# nginx-html-configmap.yaml (updated)
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-html
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <body>
        <h1>Updated from ConfigMap!</h1>
        <p>This update was made after deployment creation.</p>
    </body>
    </html>
```

```bash
kubectl apply -f nginx-html-configmap.yaml

# Wait a few seconds (kubelet polls for updates)
sleep 10

# Port forward again
POD=$(kubectl get pods -l app=nginx-demo -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward $POD 8080:80 &
sleep 2

# Test the updated content
curl http://localhost:8080/

pkill -f "port-forward"
```

Updated content should be served (note: updates can take up to 60 seconds to propagate).

---

## Lab 4: Namespace Management

### Objective
Create and manage namespaces, set resource quotas and limit ranges, and deploy applications across namespaces.

### Prerequisites
- Previous labs completed
- Understanding of Kubernetes resources (CPU, memory)

### Steps

#### 4.1: Create Custom Namespaces

Create the file `namespaces.yaml` with the following content:

```yaml
# namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: development
---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
---
apiVersion: v1
kind: Namespace
metadata:
  name: production
```

```bash
kubectl apply -f namespaces.yaml

# List all namespaces
kubectl get namespaces
kubectl get ns -o wide
```

#### 4.2: Deploy Application within a Namespace
Create the file `app-deployment.yaml` with the following content:

```yaml
# app-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quota-demo-app
  namespace: development
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
      - name: app
        image: busybox
        command: ['sh', '-c', 'echo "App running"; sleep 10000']
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
```

```bash
kubectl apply -f app-deployment.yaml
kubectl get pods -n development
```

---

## Lab 5: Deploy DaemonSets

### Objective
Deploy a DaemonSet that runs one pod per node, understand node targeting, and observe DaemonSet behavior.

### Prerequisites
- Cluster with at least 2 nodes (or 1 master + 1 worker)
- Previous labs completed

### Steps

#### 5.1: Create a Simple DaemonSet
Create the file `node-logger-daemonset.yaml` with the following content:

```yaml
# node-logger-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-logger
  namespace: default
spec:
  selector:
    matchLabels:
      app: node-logger
  template:
    metadata:
      labels:
        app: node-logger
    spec:
      hostNetwork: true
      containers:
      - name: logger
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          echo "Running on node: $(hostname)"
          echo "Node IP: $(hostname -I)"
          echo "Uptime: $(uptime)"
          while true; do
            echo "Timestamp: $(date)"
            sleep 30
          done
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
```

```bash
kubectl apply -f node-logger-daemonset.yaml
kubectl get daemonset
kubectl get pods -l app=node-logger
```

#### 5.2: Verify One Pod Per Node
```bash
# Get all nodes
kubectl get nodes

# Get all DaemonSet pods and their nodes
kubectl get pods -l app=node-logger -o wide

# Count pods: should match number of nodes
kubectl get pods -l app=node-logger | wc -l
```

Pod count should equal node count.

#### 5.3: Check DaemonSet Status
```bash
# Describe the DaemonSet
kubectl describe daemonset node-logger

# Watch DaemonSet rollout status
kubectl rollout status daemonset/node-logger

# View events
kubectl get events | grep node-logger
```

#### 5.4: View Pod Logs
```bash
# Get pod names
PODS=$(kubectl get pods -l app=node-logger -o name)

# View logs from each pod
for pod in $PODS; do
  echo "=== Logs from $pod ==="
  kubectl logs $pod | head -5
done
```
---