# Kubernetes ConfigMaps and Secrets - Class Notes

## Imagine you have one application with three parts:

1. **Frontend**
2. **Admin portal**
3. **Backend API**

For each part, you created a Docker image:

```text
frontend:v1
admin:v1
backend:v1
```

Then you pushed these images to an image registry such as:

- Docker Hub
- Amazon ECR
- Google Artifact Registry
- Azure Container Registry

After that, you added the image URL and tag inside your Kubernetes `Deployment` manifest.

Example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/backend:v1
          ports:
            - containerPort: 8080
```

Kubernetes pulls the image and runs it as a container inside a Pod.

So far, everything looks fine.

---

## 2. The real problem: Hardcoded configuration

During development, the backend code had certain values hardcoded inside it.

Examples:

```text
Database host
Database URL
Database username
Database password
Payment provider API key
Third-party service token
```

In the Dev environment, this may work because the hardcoded values point to the Dev database and Dev APIs.

But when the same image is deployed to QA, UAT, staging, or production, the application may fail.

Why?

Because the same backend image is still trying to connect to Dev-specific resources.

Example:

```text
Backend running in QA
    -> still connecting to Dev database
    -> still using Dev payment API key
    -> QA database receives no entries
    -> application behaviour becomes confusing
```

At this point, debugging begins. After checking logs, database entries, and application behaviour, the obvious mistake becomes clear:

> Environment-specific values were hardcoded inside the application code.

This is a bad practice.

---

## 3. Correct principle: Separate code from configuration

The application image should be environment-neutral.

That means the same image should be usable in all environments:

```text
backend:v1 -> Dev
backend:v1 -> QA
backend:v1 -> UAT
backend:v1 -> Staging
backend:v1 -> Production
```

The image should contain the application code only.

Environment-specific values should be supplied at runtime.

This gives us a clean separation:

| Item | Should it be inside the image? | Example |
|---|---:|---|
| Application code | Yes | Java, Node.js, Python code |
| Application binaries | Yes | JAR file, compiled app, static files |
| Non-sensitive config | No | database host, log level, feature flag |
| Sensitive config | No | password, token, API key |

This is why we use external configuration.

---

## 4. How this is handled outside Kubernetes

In a non-Kubernetes setup, you may commonly use:

- `.env` files
- environment variables
- configuration files
- cloud secrets managers
- HashiCorp Vault
- CI/CD pipeline variables

Example `.env` file:

```bash
DB_HOST=qa-db.example.internal
DB_NAME=orders_qa
LOG_LEVEL=debug
PAYMENT_API_KEY=qa-payment-key
```

The application reads these values at runtime instead of reading them from hardcoded source code.

---

## 5. How Kubernetes handles this

In Kubernetes, the standard native objects are:

1. **ConfigMap**
2. **Secret**

And in production-grade environments, these are often extended with:

3. **External Secrets / Secrets Store CSI Driver / Vault integration**

Simple rule:

```text
ConfigMap -> non-sensitive configuration
Secret    -> sensitive configuration
External secret store -> better source of truth for real production secrets
```

---

# Kubernetes ConfigMap

## 6. What is a ConfigMap?

A **ConfigMap** is a Kubernetes object used to store non-sensitive configuration data.

Use ConfigMaps for values like:

```text
DB_HOST
DB_PORT
APP_ENV
LOG_LEVEL
FEATURE_FLAG_ENABLED
API_BASE_URL
CACHE_TTL
```

Do **not** store passwords, tokens, private keys, or API keys in a ConfigMap.

---

## 7. Example ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: qa
data:
  APP_ENV: "qa"
  DB_HOST: "qa-db.example.internal"
  DB_PORT: "5432"
  DB_NAME: "orders_qa"
  LOG_LEVEL: "debug"
```

This ConfigMap stores the non-sensitive runtime configuration for the backend application.

---

## 8. Using ConfigMap values as environment variables

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: qa
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/backend:v1
          envFrom:
            - configMapRef:
                name: backend-config
```

Now the container receives these values as environment variables.

Inside the application, you read them like this:

```text
process.env.DB_HOST        # Node.js example
System.getenv("DB_HOST")   # Java example
os.getenv("DB_HOST")       # Python example
```

---

# Kubernetes Secret

## 9. What is a Kubernetes Secret?

A **Secret** is a Kubernetes object used to store sensitive data such as:

```text
Database password
API key
Access token
TLS certificate
SSH private key
Docker registry credential
```

A Secret helps avoid putting sensitive values directly inside:

- source code
- Docker images
- Deployment YAML files
- Pod specs

---

## 10. Example Secret

You can create a Secret using `stringData`, which is easier to read and write.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: backend-secret
  namespace: qa
type: Opaque
stringData:
  DB_USERNAME: "orders_user"
  DB_PASSWORD: "super-secret-password"
  PAYMENT_API_KEY: "qa-payment-api-key"
```

Kubernetes stores the values under the `data` field after encoding them.

Important point:

> Base64 encoding is not encryption.

Anyone who can read the Secret can decode the value.

---

## 11. Using Secret values as environment variables

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: qa
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/backend:v1
          envFrom:
            - configMapRef:
                name: backend-config
            - secretRef:
                name: backend-secret
```

Now the backend container gets both:

```text
Non-sensitive config from ConfigMap
Sensitive config from Secret
```

---

## 12. Why Kubernetes Secrets are limited

### 1. Secrets are only Base64 encoded

Kubernetes Secret values are base64 encoded.

Base64 is only encoding, not encryption.

Example:

```bash
echo "c3VwZXItc2VjcmV0LXBhc3N3b3Jk" | base64 -d
```

Output:

```text
super-secret-password
```

So if someone can read the Secret object, they can decode the value easily.

---

### 2. Secrets may be stored unencrypted in etcd by default

Kubernetes stores cluster state in etcd.

If encryption at rest is not enabled, Secret data may be stored in etcd without proper encryption.

This means etcd access becomes highly sensitive.

---

### 3. RBAC mistakes can expose secrets

If a user, service account, or automation has permission to read Secrets, it can read sensitive values.

Even more importantly, a user who can create Pods in a namespace may be able to mount or consume Secrets available in that namespace.

So Secret security depends heavily on correct RBAC design.

---

### 4. Secrets can leak through environment variables

When Secrets are injected as environment variables, they may accidentally appear in:

- debug output
- crash dumps
- application logs
- support bundles
- process inspection tools

Mounting Secrets as files is often safer than injecting everything as environment variables, but the application still needs access to the value.

---

### 5. No strong native lifecycle management

Kubernetes Secrets do not provide a complete lifecycle management system by themselves.

They do not automatically solve:

- secret rotation
- expiry
- approval workflow
- centralized audit trail
- dynamic credentials
- cross-cluster secret governance
- integration with enterprise identity systems

For these capabilities, organizations usually use a dedicated secrets manager.

---

### 6. Secrets often end up in Git by mistake

If teams write Secret YAML files manually and commit them to Git, sensitive values can leak.

This is very common in GitOps workflows if proper tooling is not used.

For GitOps, use safer options such as:

- External Secrets Operator
- Secrets Store CSI Driver
- Sealed Secrets
- Mozilla SOPS
- HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault
- Google Secret Manager

---

# Recommended production approach

## 17. Better way to handle secrets in production

A more production-ready design looks like this:

```text
Application code
    -> reads config from environment variables or mounted files

Kubernetes Deployment
    -> references ConfigMap and Secret

ConfigMap
    -> stores non-sensitive environment-specific values

External Secret Store
    -> stores real secrets securely

External Secrets Operator / CSI Driver
    -> syncs or mounts secrets into Kubernetes

Pod
    -> receives only the secrets it actually needs
```

---