# AWS API Gateway, ALB, Lambda, RDS, S3 and Deployment Strategies

## 1. What is Amazon API Gateway?

Amazon API Gateway is a managed AWS service used to create, publish, secure, monitor, and manage APIs.

You can think of it as a **front door for APIs**.

A client such as a browser, mobile application, or another service sends a request to API Gateway. API Gateway can then validate, control, transform, and route the request to a backend such as:

- AWS Lambda
- ECS / EKS applications
- EC2 applications
- HTTP endpoints
- Other AWS services

### Simple flow

```text
Client
  |
  v
API Gateway
  |
  +--> Authentication / Authorization
  +--> Throttling
  +--> Request validation
  +--> Logging / Monitoring
  |
  v
Backend
Lambda / ECS / EC2 / HTTP Service
```

### Why use API Gateway?

API Gateway is useful when you need capabilities specifically related to APIs rather than only traffic distribution.

Common benefits include:

1. **Authentication and authorization**
   - IAM authorization
   - Lambda authorizers
   - Amazon Cognito integration
   - JWT authorization for HTTP APIs

2. **Request throttling**
   - Protects backend systems from too many requests.
   - Useful for implementing request limits and API usage controls.

3. **Request and response transformation**

4. **API keys and usage plans**

5. **Monitoring and logging**

6. **Versioned API endpoints**

```text
/v1/orders
/v2/orders
```

---

## 2. API Gateway vs Application Load Balancer

At first glance, **API Gateway and Application Load Balancer (ALB) overlap quite a lot**.

Both can receive HTTP/HTTPS requests and route them to backend applications.

For example, both can be used in architectures like:

```text
Client
   |
   v
API Gateway / ALB
   |
   +----> Lambda
   |
   +----> Application services
```

So the difference is **not simply**:

> API Gateway is for APIs and ALB is for websites.

That explanation is too simplistic.

The more useful distinction is:

> **ALB primarily routes traffic to application workloads.
> API Gateway additionally manages and governs the API itself.**

### Practical comparison

| Requirement                                     | ALB                             | API Gateway                 |
| ----------------------------------------------- | ------------------------------- | --------------------------- |
| Receive HTTP/HTTPS requests                     | ✅                               | ✅                           |
| Route `/users` and `/orders` differently        | ✅                               | ✅                           |
| Route using hostname                            | ✅                               | ✅                           |
| Send traffic to EC2/ECS applications            | ✅                               | ✅                           |
| Invoke Lambda                                   | ✅                               | ✅                           |
| Authentication                                  | ✅ Some options                  | ✅ More API-oriented options |
| Per-client API keys                             | ❌                               | ✅                           |
| Per-client usage plans                          | ❌                               | ✅                           |
| Request-rate throttling                         | ❌ Not an API throttling feature | ✅                           |
| Request quotas such as 10,000 calls/day         | ❌                               | ✅                           |
| Validate API requests before reaching backend   | ❌                               | ✅                           |
| Transform API requests/responses                | ❌ / very limited                | ✅                           |
| Manage an API as a product exposed to consumers | ❌                               | ✅                           |
| Load balance across application instances       | ✅ Core purpose                  | Not its core purpose        |

API Gateway can apply API keys, usage plans, quotas and throttling before requests reach the application.

---

## Think about the difference using an example

Suppose you have three microservices:

```text
/users
/orders
/payments
```

running as:

```text
ECS Service
ECS Service
ECS Service
```

You could very easily use an ALB:

```text
                    ALB
                     |
          +----------+----------+
          |          |          |
       /users     /orders    /payments
          |          |          |
        ECS        ECS         ECS
```

The ALB can inspect the incoming request and route it to the appropriate target.

For many internal applications, this may be completely sufficient.

---

# When API Gateway becomes useful

Now imagine the same APIs are exposed to:

* mobile applications
* partners
* external developers
* different customers

and you want rules such as:

```text
Customer A
    |
    | API Key A
    |
    | Maximum 100 requests/sec
    v

GET /orders
```

while:

```text
Customer B
    |
    | API Key B
    |
    | Maximum 20 requests/sec
    v

GET /orders
```

Now you are no longer solving only a **traffic-routing problem**.

You are solving an **API management problem**.

This is where API Gateway becomes much more useful.

API Gateway supports usage plans where API clients can be associated with API keys, throttling targets and quotas.

---

## A very simple way to remember it

```text
ALB
 |
 +---- Where should this request go?
```

versus:

```text
API Gateway
 |
 +---- Is this caller allowed?
 |
 +---- How many calls can they make?
 |
 +---- Is the request valid?
 |
 +---- Should the request be transformed?
 |
 +---- Which backend should receive it?
```

API Gateway provides API-oriented capabilities including authorization, traffic management, request validation/transformation and API lifecycle features.

---

# Example where ALB alone is perfectly fine

Suppose you have:

```text
Internet
   |
   v
CloudFront
   |
   v
ALB
   |
   +-------------------+
   |                   |
   v                   v
ECS Service A      ECS Service B
/users             /orders
```

If your main requirement is:

* expose the application
* terminate HTTPS
* route based on host/path
* distribute traffic among containers
* perform health checks

then adding API Gateway may provide little benefit.

ALB is specifically designed to distribute application traffic across targets and provides sophisticated HTTP routing.

---

# Example where API Gateway makes more sense

Consider a public banking API:

```text
Partner Application
        |
        | API Key / Token
        v
+----------------------+
|     API Gateway      |
+----------------------+
        |
        | Authentication
        | Authorization
        | Throttling
        | Request validation
        | API policies
        |
        v
      Lambda
        |
        v
       RDS
```

Here the API itself needs to be controlled.

API Gateway therefore acts as the **API front door**, rather than merely distributing traffic. AWS describes API Gateway as a managed service for creating, publishing, maintaining, monitoring and securing APIs.

---

# One important correction about WebSockets

Do not use:

> ALB does not support WebSockets.

That is incorrect.

**ALB supports WebSocket connections as well.**

API Gateway, however, provides a dedicated **WebSocket API model**, where WebSocket messages can be mapped to routes and integrations such as Lambda.

So again, the difference is not simply whether the protocol is supported.

The difference is how much **API-level management** AWS provides around it.

---

# Final rule of thumb

### Use ALB when your requirement sounds like:

> "I have applications/containers/servers and I need to distribute and route HTTP traffic to them."

For example:

```text
Internet
   |
   v
ALB
   |
   +---- EC2
   +---- ECS
   +---- EKS
```

### Use API Gateway when your requirement sounds like:

> "I am exposing an API and I need to control how consumers use that API."

For example:

```text
Clients
   |
   v
API Gateway
   |
   |-- Authentication
   |-- Authorization
   |-- API Keys
   |-- Throttling
   |-- Quotas
   |-- Validation
   |
   v
Backend
```

### In one sentence

> **ALB is primarily concerned with routing traffic to healthy application targets; API Gateway is concerned with exposing, controlling and managing APIs.**

There is significant overlap between them, so **do not introduce API Gateway simply because your application exposes REST endpoints**. Use it when the additional API-management capabilities are actually required.

---

## 3. Why can’t we run everything serverless using Lambda?

#### 1. Lambda can become expensive for continuously running or compute-heavy workloads

Lambda is priced based on factors such as:

* Number of requests
* Execution duration
* Memory allocated
* Additional features/configuration used

This works very well for workloads that are:

* Event-driven
* Bursty
* Intermittent
* Idle for significant periods

For example:

```text
Few requests
    |
    v
Lambda runs only when required
    |
    v
You pay mainly for actual execution
```

This is one of Lambda's biggest advantages.

However, imagine a service where:

* Requests arrive continuously
* Functions execute almost all the time
* Each invocation performs CPU- or memory-heavy processing
* Many Lambda executions run concurrently

Then the architecture starts looking like:

```text
Request Request Request Request Request
   |       |       |       |       |
   v       v       v       v       v
Lambda  Lambda  Lambda  Lambda  Lambda
   |       |       |       |       |
 Heavy processing continuously
```

At that point, you may effectively be paying serverless execution charges throughout the day.

For a predictable workload running continuously, dedicated compute such as:

```text
EC2
ECS
EKS
```

may be significantly more economical because the compute capacity is already running and can process many requests without charging separately for every invocation-duration combination.

So a useful rule is:

> **Lambda is often cost-effective when the workload is intermittent or bursty. Dedicated compute often becomes more attractive when the workload is sustained and heavily utilized.**

Do not assume that **serverless automatically means cheaper**.

---

#### 2. Lambda executions are time-limited

A Lambda invocation cannot run forever.

AWS Lambda has a maximum execution duration per invocation, so very long-running workloads may be better suited to:

* ECS
* EKS
* EC2
* AWS Batch
* Step Functions combined with shorter-running tasks

For example:

```text
Image processing for 3 seconds
        -> Lambda can be a good fit

Background processing for several hours
        -> Lambda is usually not the right runtime
```

---

#### 3. Lambda follows a stateless execution model

Lambda functions should not depend on local memory or local disk surviving between invocations.

For example, this is a bad assumption:

```text
Invocation 1
    |
Store important data locally
    |
Invocation 2 expects the same data
```

The next invocation may run in a different execution environment.

Persistent state should normally be stored externally in services such as:

* DynamoDB
* RDS / Aurora
* S3
* ElastiCache
* EFS, where appropriate

A better design is:

```text
Lambda
   |
   +----> DynamoDB
   |
   +----> RDS
   |
   +----> S3
```

---

#### 4. Cold starts can introduce additional latency

When Lambda needs to create a new execution environment, initialization adds latency before the function starts processing the request.

This is commonly called a **cold start**.

Conceptually:

```text
Request
   |
   v
Create execution environment
   |
Initialize runtime
   |
Load application
   |
Execute function
```

For many applications this latency is acceptable.

For highly latency-sensitive applications, however, cold starts may require additional design considerations.

---

#### 5. Connection-heavy applications can create database problems

Consider an architecture such as:

```text
                 RDS
                  ^
                  |
       +----------+----------+
       |          |          |
    Lambda     Lambda     Lambda
       |          |          |
    Lambda     Lambda     Lambda
```

If hundreds or thousands of Lambda executions open independent database connections, the relational database can run out of connections.

This is particularly important because Lambda can scale quickly.

A common solution is:

```text
Lambda
   |
   v
RDS Proxy
   |
   v
RDS / Aurora
```

RDS Proxy maintains and reuses database connections instead of requiring every Lambda execution to create its own independent connection.

---

#### 6. Continuous workloads may be better suited to containers or EC2

Lambda is very attractive when the workload behaves like this:

```text
Traffic
  ^
  |
  |        /\       /\
  |       /  \     /  \
  |______ /   \___/    \______
  |
  +--------------------------> Time
```

There are periods with little or no activity.

Lambda runs only when needed.

But consider:

```text
Traffic
  ^
  |
  |  _________________________
  | |
  | |
  | |
  +--------------------------> Time
```

The application is continuously busy.

In this case, running a continuously available container or EC2 instance can often make more architectural and economic sense.

---

#### 7. Some workloads need capabilities Lambda is not designed to provide

Some applications require:

* Long-running processes
* Very large local storage
* Specific operating-system configuration
* Specialized networking
* GPUs or specialized hardware
* Background daemons
* Long-lived application processes
* Greater control over the runtime environment

For such workloads, services such as:

```text
EC2
ECS
EKS
AWS Batch
```

may be more suitable.

---

### A simple comparison

| Workload                                      | Lambda suitability             |
| --------------------------------------------- | ------------------------------ |
| API receiving occasional requests             | Excellent                      |
| File uploaded to S3 and needs processing      | Excellent                      |
| Event-driven automation                       | Excellent                      |
| Scheduled task running for a few seconds      | Excellent                      |
| Traffic is highly unpredictable               | Very good                      |
| Service receiving heavy traffic 24×7          | Evaluate carefully             |
| CPU-heavy processing running continuously     | Often better on containers/EC2 |
| Process running for several hours             | Poor fit                       |
| Application requiring OS-level control        | Poor fit                       |
| Thousands of direct relational DB connections | Requires careful design        |

---

### The cost intuition

A useful way to think about it is:

```text
Lambda
Pay when code executes
        +
Pay based on execution resources/duration
```

versus:

```text
EC2 / Containers
Pay for provisioned compute capacity
        |
        v
Use that capacity for many requests
```

When utilization is low:

```text
Lambda often wins
```

because you are not paying for idle servers.

When utilization becomes consistently high:

```text
Lambda cost
   ↑
   ↑
   ↑

Eventually dedicated compute
may become more economical.
```

The exact crossover point depends on the workload, instance/container sizing, concurrency, execution duration, memory requirements, discounts and architecture.

Therefore, there is no universal rule such as:

> Lambda is always cheaper than EC2.

or:

> EC2 is always cheaper than Lambda.

The workload pattern matters.

---

### Practical rule

Do not ask:

> Can this application run on Lambda?

Most applications can technically be broken into functions somehow.

Instead ask:

> Is Lambda the most appropriate runtime for this workload's traffic pattern, execution duration, latency requirement, state model and cost profile?

A useful mental model is:

```text
Bursty + Event-driven + Short-lived
                |
                v
             Lambda


Continuous + Predictable + Compute-heavy
                |
                v
        ECS / EKS / EC2
```

---

## 4. Canary vs Blue-Green vs Rolling Deployment

These are different ways of releasing a new application version.

Assume:

```text
Version 1 = Current application
Version 2 = New application
```

### Rolling deployment

Instances are upgraded gradually.

Example:

```text
Start:
V1  V1  V1  V1

Step 1:
V2  V1  V1  V1

Step 2:
V2  V2  V1  V1

Step 3:
V2  V2  V2  V1

Finish:
V2  V2  V2  V2
```

#### Advantages

- Requires fewer duplicate resources.
- Gradual rollout.
- Common in Kubernetes and Auto Scaling environments.

#### Disadvantages

- Old and new versions run simultaneously during deployment.
- Rollback can be slower than blue-green.

---

### Blue-green deployment

Two complete environments exist.

```text
Blue  = Version 1
Green = Version 2
```

Before switch:

```text
Users ---> Blue V1

Green V2 is tested separately
```

After switch:

```text
Users ---> Green V2

Blue V1 remains available temporarily for rollback
```

#### Advantages

- Very fast rollback.
- New environment can be tested before production traffic moves.
- Clean separation between versions.

#### Disadvantages

- Requires duplicate capacity during deployment.
- Database changes must be carefully designed to remain compatible.

---

### Canary deployment

A small percentage of real traffic is first sent to the new version.

Example:

```text
95% traffic ---> V1
 5% traffic ---> V2
```

If V2 behaves correctly:

```text
80% ---> V1
20% ---> V2

50% ---> V1
50% ---> V2

0% ---> V1
100% -> V2
```

#### Advantages

- Limits the impact of a bad release.
- New code is tested with real production traffic.
- Useful for high-risk releases.

#### Disadvantages

- More complex traffic management.
- Monitoring must clearly compare old and new versions.

### Quick comparison

| Strategy | How release happens | Rollback | Extra capacity | Risk exposure |
|---|---|---|---|---|
| Rolling | Replace instances gradually | Medium | Low | Gradual |
| Blue-green | Switch from one full environment to another | Very fast | High | Low after testing |
| Canary | Send a small percentage to the new version first | Fast | Usually moderate | Very low initially |

---

## 5. Lambda has to communicate with RDS. How does it work?

A Lambda function can connect to an RDS database using normal database networking and database credentials.

Typical architecture:

```text
API Gateway
    |
    v
 Lambda
    |
    v
RDS MySQL / PostgreSQL
```

Because RDS databases are commonly deployed inside a VPC, Lambda normally needs network access to that VPC.

### Recommended architecture

```text
VPC

Private subnets

Lambda ENIs
    |
    v
RDS Proxy   (optional but recommended for many Lambda workloads)
    |
    v
RDS Database
```

### Security groups

A common design is:

```text
Lambda Security Group
        |
        | TCP 3306 for MySQL
        | TCP 5432 for PostgreSQL
        v
RDS Security Group
```

Instead of allowing database access from an IP range, the RDS security group can allow inbound traffic from the Lambda security group.

### Credentials

Database passwords should normally not be hardcoded inside Lambda source code.

Use a secrets service such as:

- AWS Secrets Manager
- AWS Systems Manager Parameter Store where appropriate

### Why RDS Proxy is useful

Lambda can scale rapidly.

For example:

```text
1 Lambda execution
     becomes
500 Lambda executions
```

If every invocation opens a separate database connection, the database can become overloaded.

RDS Proxy maintains and reuses database connections.

```text
Many Lambda invocations
          |
          v
      RDS Proxy
          |
          v
     Smaller pool of
   database connections
          |
          v
         RDS
```

---

## 6. Where does Lambda sit — inside the VPC or outside the VPC?

This is an important AWS concept.

Lambda is an AWS managed service. You do not create or manage a Lambda server inside one of your subnets.

### Default Lambda behavior

By default, a Lambda function is **not attached to your VPC**.

It can access public endpoints through AWS-managed networking.

Conceptually:

```text
AWS Lambda service
      |
      +--> Internet-accessible API
      +--> S3 public service endpoint
      +--> DynamoDB service endpoint
```

### Lambda connected to your VPC

If Lambda must reach private resources such as:

- RDS in a private subnet
- ElastiCache
- Internal EC2 services
- Private load balancers

you configure the Lambda function with:

- VPC
- Subnets
- Security groups

AWS then provides network interfaces that allow the function to communicate with resources in those subnets.

Conceptually:

```text
Lambda service
     |
     v
VPC networking attachment
     |
     v
Private subnet resources
     |
     +--> RDS
     +--> Redis
     +--> Internal services
```

### Important beginner point

It is common to say:

> Lambda is inside the VPC.

But technically it is more accurate to say:

> The Lambda function is configured for VPC access.

AWS still operates the Lambda compute infrastructure.

---

## 7. Can you put an S3 bucket inside a VPC?

No.

An Amazon S3 bucket does **not** sit inside your VPC or inside one of your subnets.

S3 is a regional AWS managed service.

Conceptually:

```text
Your VPC
-----------------------
| EC2                |
| Lambda VPC access  |
| RDS                 |
-----------------------

        | over the internet
        v

Amazon S3 service
```

### Then how can private resources access S3?

Use an **S3 VPC endpoint**.

For S3, a Gateway VPC Endpoint is commonly used.

```text
Private EC2 / Lambda
        |
        v
S3 Gateway Endpoint
        |
        v
Amazon S3
```

This allows traffic to S3 without requiring the traffic to traverse a NAT Gateway or the public internet path.

### Important distinction

The **VPC endpoint is associated with your VPC**.

The **S3 bucket itself is not inside the VPC**.

You can also use bucket policies to restrict access so that requests are accepted only through a particular VPC endpoint.

---

## 8. Putting everything together

Consider a serverless API application:

```text
User
 |
 v
API Gateway
 |
 v
Lambda
 |
 +----------------------+
 |                      |
 v                      v
RDS Proxy              S3
 |
 v
RDS
```

A more network-aware view is:

```text
Internet
   |
   v
API Gateway
   |
   v
Lambda
   |
   | VPC access
   v
+----------------------------+
|            VPC             |
|                            |
| Lambda network interfaces  |
|           |                |
|           v                |
|       RDS Proxy            |
|           |                |
|           v                |
|          RDS               |
|                            |
| S3 Gateway Endpoint -------+------> Amazon S3
+----------------------------+
```

Remember:

- API Gateway manages APIs.
- ALB distributes application traffic.
- Lambda is excellent for event-driven and short-lived compute, but it is not the answer for every workload.
- RDS usually sits inside a VPC.
- Lambda can be configured for VPC access when it needs private resources.
- S3 does not sit inside your VPC.
- A VPC endpoint provides private connectivity from your VPC to S3.
- Rolling, blue-green, and canary deployments control how new application versions are released.

---

## 9. Interview / Revision Questions

### Q1. What is API Gateway?

A managed AWS service used to expose, secure, control, monitor, and route APIs to backend services.

### Q2. What is the biggest difference between API Gateway and ALB?

API Gateway focuses on **API management**, while ALB focuses on **HTTP/HTTPS load balancing**.

### Q3. Can Lambda access RDS?

Yes. Lambda can be configured with VPC access and security groups that allow connectivity to RDS.

### Q4. Should Lambda connect directly to RDS?

It can, but RDS Proxy is often useful for workloads where Lambda concurrency could create a large number of database connections.

### Q5. Is Lambda inside a subnet?

Not in the same sense as EC2. Lambda is an AWS-managed service. When configured for VPC access, AWS provides networking that lets Lambda reach resources through selected VPC subnets and security groups.

### Q6. Can S3 be deployed in a private subnet?

No. S3 is not deployed into your subnets. Use an S3 VPC endpoint for private connectivity.

### Q7. Which deployment is easiest to roll back?

Blue-green usually provides the simplest and fastest rollback because the previous environment remains available.

### Q8. Which deployment sends only a small percentage of users to the new version?

Canary deployment.

### Q9. Which deployment gradually replaces old instances?

Rolling deployment.

