# Session 01-08: Helm Package Manager - Hands-On Labs

## Lab 1: Install Helm CLI

**Objective:** Install Helm on your workstation and verify the installation.

### Tasks

1. **Install Helm** (if not already installed)
   - macOS: `brew install helm`
   - Linux: `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash`
   - Windows: `choco install kubernetes-helm` or download from https://github.com/helm/helm/releases

2. **Verify Installation**
   ```bash
   helm version
   helm env
   helm repo list
   ```

3. **Add default repo and update**
   ```bash
   helm repo add stable https://charts.helm.sh/stable
   helm repo update
   ```

### Expected Output
- `helm version` should show v3.x.x
- `helm repo list` should show at least one repo
- `helm env` displays Helm configuration

---

## Lab 2: Create Your First Chart

**Objective:** Generate and explore the structure of a Helm chart.

### Tasks

1. **Scaffold a new chart**
   ```bash
   helm create simple-webapp
   cd simple-webapp
   ```

2. **Explore the chart structure**
   ```bash
   tree simple-webapp
   # or: ls -la simple-webapp/
   ```

3. **Examine Chart.yaml**
   ```bash
   cat Chart.yaml
   ```
   - Note: apiVersion, name, version, description, type, appVersion

4. **Review default values.yaml**
   ```bash
   cat values.yaml
   ```
   - Note: replicaCount, image, service, resources, ingress

5. **List template files**
   ```bash
   ls -la templates/
   ```
   - deployment.yaml, service.yaml, ingress.yaml, _helpers.tpl, NOTES.txt

6. **Preview rendered manifests without deploying**
   ```bash
   helm template simple-webapp .
   ```
   - Verify the output shows proper Deployment, Service, and ConfigMap YAML

7. **Customize values.yaml** (optional)
   - Open `values.yaml` in your editor
   - Change `replicaCount` to 2
   - Change `image.repository` to `nginx`
   - Change `service.type` to `LoadBalancer`

### Expected Output
- Chart structure with Chart.yaml, values.yaml, and templates/ directory
- `helm template` output shows valid Kubernetes YAML with your customizations

---

## Lab 3: Deploy Your Chart

**Objective:** Deploy the chart to a running Kubernetes cluster and verify the deployment.

### Prerequisites
- A running Kubernetes cluster (minikube, Docker Desktop K8s, or KIND)
- Helm CLI installed (Lab 1)

### Tasks

1. **Deploy the chart to your cluster**
   ```bash
   helm install my-webapp ./simple-webapp
   ```

2. **Verify the release was created**
   ```bash
   helm list
   helm status my-webapp
   ```

3. **Check deployed resources**
   ```bash
   kubectl get deployments
   kubectl get pods
   kubectl get services
   ```

4. **View release details**
   ```bash
   helm get values my-webapp
   helm get manifest my-webapp
   ```

5. **Test the application** (if service is accessible)
   ```bash
   # For LoadBalancer service, get external IP
   kubectl get svc my-webapp

   # Port-forward for local testing
   kubectl port-forward svc/my-webapp 8080:80 &
   curl http://localhost:8080
   ```

6. **Check Helm release hooks and notes**
   ```bash
   helm get notes my-webapp
   ```

### Expected Output
- Release appears in `helm list`
- Deployment shows 2 (or configured) pods running
- Service is accessible locally via port-forward
- `helm status` shows "deployed" status

---

## Lab 4: Upgrade & Rollback

**Objective:** Learn how to upgrade a release and roll back to a previous version.

### Tasks

1. **Check current release revision**
   ```bash
   helm history my-webapp
   ```

2. **Upgrade the release with new values**
   ```bash
   helm upgrade my-webapp ./simple-webapp --set replicaCount=3
   ```

3. **Verify the upgrade**
   ```bash
   helm history my-webapp
   helm status my-webapp
   kubectl get pods
   # Should show 3 pods now
   ```

4. **Make another change**
   ```bash
   helm upgrade my-webapp ./simple-webapp --set replicaCount=1
   helm history my-webapp
   kubectl get pods
   # Should show 1 pod
   ```

5. **Rollback to the previous revision** (revision 2)
   ```bash
   helm rollback my-webapp 2
   helm history my-webapp
   kubectl get pods
   # Should show 3 pods again
   ```

6. **Verify rollback worked**
   ```bash
   helm status my-webapp
   helm get values my-webapp
   ```

### Expected Output
- `helm history` shows 3+ revisions
- Rollback restores the exact configuration from revision 2
- Pod count matches the rolled-back revision

---

## Lab 5: Environment-Specific Deployments

**Objective:** Create and use environment-specific values files.

### Tasks

1. **Create dev values file**
   ```bash
   cat > simple-webapp/values-dev.yaml <<EOF
replicaCount: 1
image:
  repository: nginx
  tag: "latest"
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  port: 80
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"
EOF
   ```

2. **Create prod values file**
   ```bash
   cat > simple-webapp/values-prod.yaml <<EOF
replicaCount: 3
image:
  repository: nginx
  tag: "1.21.0"
  pullPolicy: IfNotPresent
service:
  type: LoadBalancer
  port: 80
resources:
  requests:
    memory: "256Mi"
    cpu: "500m"
  limits:
    memory: "512Mi"
    cpu: "1000m"
EOF
   ```

3. **Deploy dev release to dev namespace**
   ```bash
   kubectl create namespace dev
   helm install webapp-dev ./simple-webapp -f ./simple-webapp/values-dev.yaml -n dev
   ```

4. **Deploy prod release to prod namespace**
   ```bash
   kubectl create namespace prod
   helm install webapp-prod ./simple-webapp -f ./simple-webapp/values-prod.yaml -n prod
   ```

5. **Compare the two deployments**
   ```bash
   helm list -A
   helm get values webapp-dev -n dev
   helm get values webapp-prod -n prod
   kubectl get pods -n dev
   kubectl get pods -n prod
   kubectl get services -n dev
   kubectl get services -n prod
   ```

6. **Clean up**
   ```bash
   helm uninstall my-webapp
   helm uninstall webapp-dev -n dev
   helm uninstall webapp-prod -n prod
   ```

### Expected Output
- Dev namespace has 1 replica with ClusterIP service and low resource limits
- Prod namespace has 3 replicas with LoadBalancer service and higher resource limits
- Both use the same chart but different configurations

---

## Lab 6: Install and Inspect Public Charts

**Objective:** Add a public repository and install a pre-built chart.

### Tasks

1. **Add Bitnami Helm repository**
   ```bash
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm repo update
   ```

2. **Search for available charts**
   ```bash
   helm search repo bitnami | head -20
   helm search repo mysql
   ```

3. **Inspect MySQL chart details**
   ```bash
   helm show chart bitnami/mysql
   helm show values bitnami/mysql | head -50
   ```

4. **Pull the chart for local inspection** (optional)
   ```bash
   helm pull bitnami/mysql --untar
   cd mysql
   cat Chart.yaml
   cat values.yaml | head -100
   cd ..
   ```

5. **Create a values override file for MySQL**
   ```bash
   cat > mysql-values.yaml <<EOF
auth:
  rootPassword: "testpassword"
  database: "myapp"
  username: "appuser"
  password: "apppassword"
primary:
  persistence:
    enabled: true
    size: 10Gi
metrics:
  enabled: true
EOF
   ```

6. **Install MySQL using Bitnami chart**
   ```bash
   kubectl create namespace database
   helm install mydb bitnami/mysql -f mysql-values.yaml -n database
   ```

7. **Verify the installation**
   ```bash
   helm list -n database
   helm status mydb -n database
   helm get values mydb -n database
   kubectl get pods -n database
   kubectl get pvc -n database
   ```

8. **Test database connection** (optional)
   ```bash
   kubectl run -it --rm mysql-client --image=mysql:latest --restart=Never -- \
     mysql -h mydb-mysql.database.svc.cluster.local -u appuser -p myapp -e "SELECT 1"
   # Enter password: apppassword
   ```

9. **Clean up**
   ```bash
   helm uninstall mydb -n database
   kubectl delete namespace database
   ```

### Expected Output
- Bitnami repo added to `helm repo list`
- MySQL chart installed with custom credentials
- Persistent volume created for database
- Pod running and ready in database namespace

---
