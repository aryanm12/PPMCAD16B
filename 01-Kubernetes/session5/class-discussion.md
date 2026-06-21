# Kubernetes Service Exposure: NodePort, LoadBalancer, Ingress, ALB, and NLB

## 1. Objective

These notes explain how applications running in Kubernetes are exposed internally and externally, especially in an AWS/EKS-style production environment.

The key question is:

> If I have multiple microservices running inside Kubernetes, how should they communicate with each other, and how should selected services be exposed to end users securely?

---

## 2. Internal vs External Application Access

In Kubernetes, applications usually need two types of connectivity:

1. **Internal connectivity**  
   Services communicate with each other inside the Kubernetes cluster.

2. **External connectivity**  
   Selected services are exposed to users outside the cluster, such as internet users, enterprise users, partners, or upstream applications.

A good production design separates these two concerns.

---

## 3. Internal Communication Between Microservices

Assume we have 10 microservices deployed in Kubernetes.

Requirement:

> All 10 microservices should be able to communicate with each other inside the cluster.

For this, we use **Kubernetes Service type: ClusterIP**.

`ClusterIP` is the default Kubernetes Service type. It gives each service a stable virtual IP and DNS name inside the cluster.

Example:

```text
checkout-service  -> checkout pods
order-service     -> order pods
product-service   -> product pods
cart-service      -> cart pods
payment-service   -> payment pods
```

Services can call each other using Kubernetes DNS names.

Example from the same namespace:

```text
http://order-service
http://checkout-service
http://payment-service
```

Example from a different namespace:

```text
http://order-service.<namespace>.svc.cluster.local
```

### Key Point

For internal service-to-service communication, we do **not** need `NodePort`, `LoadBalancer`, or `Ingress`.

Use:

```text
Service Type = ClusterIP
```

---

## 4. Why NodePort Is Not Preferred for Production Internet Exposure

`NodePort` exposes a service on a fixed port across the Kubernetes worker nodes.

Example:

```text
http://<worker-node-ip>:30080
```

This can be useful for learning, testing, debugging, or simple non-production environments. However, it is usually not preferred for production internet-facing workloads.

### Common Concerns with NodePort in Production

#### 1. It depends on worker nodes

Traffic reaches the application through worker node IPs and node ports.

This means the external access pattern becomes tightly coupled with the Kubernetes worker nodes.

Worker nodes are not meant to be the stable public entry point for enterprise applications.

#### 2. Public worker nodes increase risk

If end users need to access applications through NodePort directly, worker nodes may need public IPs or broad inbound access.

That is not a good enterprise security pattern.

In a production-grade cloud architecture, compute nodes should usually stay in **private subnets**.

#### 3. Security teams usually reject this pattern

Enterprise security teams typically do not allow worker nodes to be directly exposed to the internet.

Instead, internet-facing traffic should enter through controlled entry points such as:

- Public Load Balancer
- Web Application Firewall
- API Gateway
- Reverse proxy / Ingress controller
- Central gateway layer

#### 4. It increases blast radius

If worker nodes are directly accessible, any misconfiguration can expose a larger part of the compute layer.

A better pattern is:

```text
Internet user
   -> Public Load Balancer / Gateway
      -> Private Kubernetes worker nodes / pod targets
         -> Application pods
```

This keeps the compute layer private and reduces blast radius.

### Important Nuance

NodePort itself is not always "public". A NodePort service can still be protected by private subnets, security groups, firewalls, or internal load balancers.

The real concern is using NodePort as the **direct production internet-facing access mechanism**, especially with public worker node IPs.

---

## 5. LoadBalancer Service Type

Kubernetes `Service type: LoadBalancer` asks the cloud provider to create an external load balancer for the service.

In AWS/EKS, depending on the controller and annotations, this often results in an AWS load balancer such as an NLB.

Example:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: checkout-service
spec:
  type: LoadBalancer
  selector:
    app: checkout
  ports:
    - port: 80
      targetPort: 8080
```

### What happens conceptually

```text
End User
   -> Cloud Load Balancer
      -> Kubernetes service
         -> Application pods
```

### Problem with many external services

If 3 services need to be exposed externally and each one uses `Service type: LoadBalancer`, then we may get 3 separate cloud load balancers.

Example:

```text
checkout-service  -> Load Balancer 1
order-service     -> Load Balancer 2
product-service   -> Load Balancer 3
```

This works, but it may not be the best design when all services are HTTP/HTTPS-based and can be routed through a common entry point.

### When LoadBalancer Service is useful

Use `Service type: LoadBalancer` when:

- You need a dedicated load balancer for one service.
- The service is not HTTP/HTTPS-based.
- You need Layer 4 TCP/UDP load balancing.
- You are exposing infrastructure components such as ingress controllers, brokers, or TCP services.
- You want a simple mapping between one service and one external load balancer.

---

## 6. Application Load Balancer: Layer 7 Routing

An Application Load Balancer works at Layer 7, meaning it understands HTTP and HTTPS traffic.

It can inspect request details such as:

- Host header
- URL path
- HTTP headers
- Query strings
- HTTP method

Example URL:

```text
https://amazon.com/checkout
```

In this request:

```text
Host header = amazon.com
Path        = /checkout
```

Another example:

```text
https://amazon.com/order
```

In this request:

```text
Host header = amazon.com
Path        = /order
```

Because ALB understands HTTP, it can make routing decisions based on host and path.

---

## 7. Path-Based Routing with ALB

In path-based routing, one domain is used, and different URL paths route to different services.

Example:

```text
https://amazon.com/checkout
https://amazon.com/order
https://amazon.com/product
https://amazon.com/cart
```

Traffic flow:

```text
End User
   -> ALB
      -> /checkout -> checkout-service -> checkout pods
      -> /order    -> order-service    -> order pods
      -> /product  -> product-service  -> product pods
      -> /cart     -> cart-service     -> cart pods
```

### Visual Flow

```text
END USER -----------------------> ALB

https://amazon.com/checkout  ---> Checkout Service ---> Checkout Pods
https://amazon.com/order     ---> Order Service    ---> Order Pods
https://amazon.com/product   ---> Product Service  ---> Product Pods
https://amazon.com/cart      ---> Cart Service     ---> Cart Pods
```

### When path-based routing is useful

Use path-based routing when services are part of the same application domain.

Example:

```text
amazon.com/checkout
amazon.com/order
amazon.com/product
amazon.com/cart
```

---

## 8. Host-Based Routing with ALB

In host-based routing, different subdomains route to different services.

Example:

```text
https://checkout.amazon.com
https://order.amazon.com
https://product.amazon.com
https://cart.amazon.com
```

Traffic flow:

```text
End User
   -> ALB
      -> checkout.amazon.com -> checkout-service -> checkout pods
      -> order.amazon.com    -> order-service    -> order pods
      -> product.amazon.com  -> product-service  -> product pods
      -> cart.amazon.com     -> cart-service     -> cart pods
```

### Visual Flow

```text
END USER -----------------------> ALB

https://checkout.amazon.com  ---> Checkout Service ---> Checkout Pods
https://order.amazon.com     ---> Order Service    ---> Order Pods
https://product.amazon.com   ---> Product Service  ---> Product Pods
https://cart.amazon.com      ---> Cart Service     ---> Cart Pods
```

### When host-based routing is useful

Use host-based routing when each service or product module has its own subdomain.

Example:

```text
checkout.company.com
orders.company.com
api.company.com
admin.company.com
```

---

## 9. Kubernetes Ingress

Kubernetes Ingress is used to manage external HTTP/HTTPS access to services running inside the cluster.

Ingress allows us to define rules such as:

```text
/checkout -> checkout-service
/order    -> order-service
/product  -> product-service
/cart     -> cart-service
```

or:

```text
checkout.company.com -> checkout-service
order.company.com    -> order-service
product.company.com  -> product-service
```

### Important Point

Ingress by itself is only a Kubernetes API object.

To make Ingress work, we need an **Ingress Controller**.

The controller watches the Ingress rules and configures the actual traffic-routing component.

---

## 10. Recommended Design for 10 Microservices

Scenario:

> We have 10 microservices to deploy in Kubernetes.

Conditions:

1. All 10 services need to connect with each other inside the cluster.
2. Only 3 services need to be exposed externally for end-user access.

### Recommended Answer

#### For condition 1: Internal communication

Create `ClusterIP` services for all 10 microservices.

```text
service-a -> ClusterIP
service-b -> ClusterIP
service-c -> ClusterIP
...
service-j -> ClusterIP
```

All services communicate with each other using service names.

Example:

```text
http://service-a
http://service-b
http://service-c
```

#### For condition 2: External exposure

Expose only the 3 required services externally.

There are multiple options.

##### Option A: NodePort

```text
End User -> Worker Node Public IP:NodePort -> Service -> Pods
```

Use mostly for:

- Local testing
- Learning
- Non-production
- Temporary debugging

Not recommended as the main production internet-facing pattern.

##### Option B: Service Type LoadBalancer

```text
End User -> Cloud Load Balancer -> Service -> Pods
```

If 3 services are exposed this way, then 3 cloud load balancers may be created.

```text
checkout-service -> Load Balancer 1
order-service    -> Load Balancer 2
product-service  -> Load Balancer 3
```

This is simple but may increase:

- Cost
- Operational overhead
- DNS management
- Certificate management
- Security group management

Good for dedicated Layer 4 or service-specific exposure.

---

##### Option C: Ingress with AWS Load Balancer Controller

```text
End User -> ALB -> Ingress rules -> Service -> Pods
```

This is generally the better production pattern for multiple HTTP/HTTPS services.

Only one ALB can route traffic to multiple backend services using host-based or path-based rules.

Example:

```text
https://app.company.com/checkout -> checkout-service
https://app.company.com/order    -> order-service
https://app.company.com/product  -> product-service
```

or:

```text
https://checkout.company.com -> checkout-service
https://order.company.com    -> order-service
https://product.company.com  -> product-service
```
---


## 11. What Happens with NGINX, HAProxy, Traefik, or Kong Ingress Controller?

AWS Load Balancer Controller is not the only option.

Other popular ingress controllers include:

- NGINX Ingress Controller
- HAProxy Ingress Controller
- Traefik Ingress Controller
- Kong Ingress Controller

When deploying these controllers on a cloud platform such as AWS, Azure, or GCP, the ingress controller itself is commonly exposed using a Kubernetes `Service type: LoadBalancer`.

On AWS, that usually creates a cloud load balancer in front of the ingress controller.

Example with HAProxy Ingress Controller:

```text
End User
   -> AWS NLB
      -> HAProxy Ingress Controller service
         -> HAProxy Ingress Controller pods
            -> Application service
               -> Application pods
```

The request flow becomes:

```text
End User
   -> NLB
      -> HAProxy Ingress Controller
         -> Host header check
         -> Path check
         -> Ingress rule match
         -> Application service
         -> Application pod
```

### Key Difference from AWS ALB Ingress

With AWS Load Balancer Controller:

```text
End User -> ALB -> Application service/pods
```

The ALB itself performs HTTP host/path routing.

With NGINX/HAProxy/Traefik/Kong:

```text
End User -> Cloud Load Balancer -> Ingress Controller -> Application service/pods
```

The cloud load balancer mainly brings traffic to the ingress controller. The ingress controller performs the host/path routing.

---