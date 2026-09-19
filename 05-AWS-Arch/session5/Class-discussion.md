# Cloud Migration - Class Notes

> **Headline:** Cloud migration is not simply "move servers to cloud"; it is a structured process of discovering workloads, choosing the right migration strategy for each workload, building the cloud foundation, migrating in controlled waves, validating, cutting over, and then continuously optimizing.

---

# 1. What is Migration?

Migration means moving or transforming an existing workload, platform, application, database, or infrastructure component from one environment or technology to another.

Common migration examples include:

- On-premises data center → AWS / Azure / GCP
- Physical servers → virtual machines
- VMware → cloud infrastructure
- One operating system version → another
- One application runtime → another
- Self-managed database → managed database
- Proprietary database → open-source database
- One cloud provider → another cloud provider
- Legacy application → cloud-native architecture

Examples:

```text
Physical HPE Server
        |
        v
VMware VM
```

```text
VMware VM
    |
    v
Amazon EC2
```

```text
SQL Server
    |
    v
PostgreSQL
```

```text
Self-managed MySQL
        |
        v
Amazon RDS for MySQL
```

```text
Monolith
   |
   v
Containers + Managed Services + Serverless
```

AWS formally groups cloud workload migration strategies into the **7Rs**: Retire, Retain, Rehost, Relocate, Repurchase, Replatform, and Refactor/Re-architect.  
**Source:** AWS Prescriptive Guidance - Migration strategies.

---

# 2. Why Organizations Migrate to Cloud

Cloud migration can be driven by technical, financial, operational, or business reasons.

Typical drivers include:

- Data-center exit
- Hardware or software end-of-life
- Need for faster provisioning
- Elastic scaling requirements
- Reduced infrastructure-management responsibility
- Need for managed services
- Business continuity and disaster recovery requirements
- Global expansion
- Modernization
- Licensing pressure
- Skill availability
- Security and governance improvements
- Faster experimentation and product delivery

Cloud services can provide pay-as-you-go pricing models, managed infrastructure, elastic services, and automation capabilities, but cloud is **not automatically cheaper**. A cost case should be validated using workload utilization, licensing, migration cost, operations cost, support, resilience requirements, and target architecture.

AWS MAP specifically positions migration around reducing migration risk, building cloud foundations, and accelerating cloud adoption through a structured migration program.

**Source:** AWS Migration Acceleration Program (MAP).

---

# 3. AWS Migration Acceleration Program - MAP

**MAP** stands for:

```text
Migration Acceleration Program
```

AWS describes MAP as a migration and modernization program that combines methodology, tooling, training, AWS and partner expertise, and eligible financial incentives.

The MAP framework has three main phases:

```text
Assess
   |
   v
Mobilize
   |
   v
Migrate & Modernize
```

**Source:** AWS Migration Acceleration Program.

For operational purposes, many migration programs also explicitly include a post-migration activity such as:

```text
Operate & Optimize
```

---

# 4. Migration Lifecycle

A practical migration lifecycle can be thought of as:

```text
Assess
   |
   v
Mobilize
   |
   v
Migrate & Modernize
   |
   v
Operate & Optimize
```

---

# 5. Phase 1 - Assess

The Assess phase answers:

> What do we have, what should move, why should it move, what will it cost, and how should we approach it?

AWS states that the Assess phase is used to build the migration business case and understand migration readiness.  
**Source:** AWS Prescriptive Guidance - Phases of a large migration.

## 5.1 Discovery

First, discover the existing environment.

Inventory can include:

```text
Applications
Servers
Virtual machines
Databases
Load balancers
Firewalls
Storage
Network devices
DNS
Certificates
Middleware
Queues
Caches
File systems
Monitoring tools
Backup systems
External integrations
```

Do not assume that every discovered component will be recreated one-for-one in cloud.

For example:

```text
On-prem physical load balancer
```

might later become:

```text
Application Load Balancer
```

but the migration strategy is decided at the **application/workload level**, not simply by saying that every router or load balancer is "Retired."

## 5.2 Capture workload specifications

For each server or workload, collect information such as:

```text
Hostname
Operating system
CPU
Memory
Storage
Disk utilization
Network throughput
Applications installed
Database engine
Database size
Ports
Dependencies
Backup method
Monitoring
Availability requirement
RPO
RTO
Licenses
Owners
Support contacts
```

This information is used for rightsizing, target-service selection, migration planning, cost estimation, and risk analysis.

---

# 6. Dependency Mapping

Dependency mapping identifies how applications communicate with other systems.

Example:

```text
Web Application
      |
      +----> MySQL
      |
      +----> Redis
      |
      +----> Payment API
      |
      +----> LDAP
      |
      +----> File Share
```

If only the web server is migrated but the application still depends on an on-premises database, authentication service, or file share, the migration team must plan connectivity and latency.

Dependency information also helps determine which systems should move together in the same migration wave.

---

# 7. TCO - Total Cost of Ownership

TCO analysis compares the cost of the current environment with the proposed target state.

A useful model is:

```text
Current-state cost
------------------
Hardware
Virtualization
Data-center cost
Power
Cooling
Network
Licensing
Support
Operations
Backup
DR
Staff effort
```

versus:

```text
Cloud-state cost
----------------
Compute
Storage
Database
Network
Data transfer
Backup
Monitoring
Support
Licensing
Managed services
Cloud operations
Security
DR
```

Do not compare only:

```text
On-prem server cost
vs
EC2 instance cost
```

because that is not a complete TCO comparison.

AWS states that the Assess phase should establish the migration business case and TCO view.  
**Source:** AWS Prescriptive Guidance - Assess phase.

---

# 8. Wave Planning

Large migrations are normally executed in waves rather than moving every workload at once.

Example:

```text
Wave 1
------
Low-risk internal applications

Wave 2
------
Medium-criticality applications

Wave 3
------
Customer-facing applications

Wave 4
------
Critical applications and tightly coupled databases
```

A wave should include required dependencies.

Example:

```text
Application A
   |
   +----> Database A
   |
   +----> Redis A
```

If these components are tightly coupled, planning them separately may create unnecessary network, latency, or cutover risk.

AWS guidance for large migrations emphasizes migration strategy assignment and wave planning based on portfolio information and workload dependencies.  
**Source:** AWS Prescriptive Guidance - Large migration guidance.

---

# 9. Phase 2 - Mobilize

Mobilize prepares the organization and target cloud environment before migration at scale.

AWS states that Mobilize commonly includes creating the cloud foundation, performing deeper portfolio assessment, establishing security and operating models, and preparing teams for migration.  
**Source:** AWS Prescriptive Guidance - Mobilize phase.

Typical activities include:

```text
Landing zone
Account/subscription structure
IAM / identity
Network design
Security baseline
Logging
Monitoring
Backup
DNS
Connectivity
Cloud operations
Migration tooling
Automation
Governance
```

---

# 10. AWS Landing Zone / Control Tower

For an AWS migration, the foundation may include:

```text
AWS Organizations
AWS accounts
AWS Control Tower
IAM / IAM Identity Center
Service Control Policies
VPCs
Transit Gateway
VPN / Direct Connect
CloudTrail
AWS Config
Security services
Centralized logging
Backup
Tagging standards
```

Example governance objective:

```text
S3 buckets must not become publicly accessible unless explicitly approved.
```

This can be implemented using multiple governance and security controls. An SCP is one possible preventive control, but the exact policy design should be validated rather than assuming one universal SCP.

---

# 11. Phase 3 - Migrate & Modernize

This is where the migration waves are executed.

Typical activities include:

```text
Build target environment
Replicate / move data
Migrate servers
Migrate databases
Configure networking
Deploy applications
Test
Validate
Cut over
Monitor
Decommission old environment
```

AWS describes this as the phase in which the migration strategy and plan are used to migrate and modernize workloads.  
**Source:** AWS Prescriptive Guidance - Migrate and Modernize phase.

---

# 12. Operate & Optimize

After migration, the work continues.

Typical activities:

```text
Rightsizing
Autoscaling
Reserved pricing / Savings Plans analysis
Database optimization
Security hardening
Backup validation
DR testing
Monitoring
Observability
Cost optimization
Performance tuning
Automation
Managed-service adoption
Modernization
```

Migration is often the beginning of optimization rather than the end.

---

# 13. The 7Rs of Cloud Migration

AWS defines seven common migration strategies:

```text
1. Retire
2. Retain
3. Rehost
4. Relocate
5. Repurchase
6. Replatform
7. Refactor / Re-architect
```

**Source:** AWS Prescriptive Guidance - Migration strategies.

---

# 14. Retire

Retire means:

> The application or workload is no longer required, so it is decommissioned instead of migrated.

Examples:

```text
Unused legacy reporting application
Old application replaced by another system
Duplicate service
Server with no remaining business use
```

Important:

```text
Retire != replace every router or load balancer
```

A physical load balancer that is replaced by an AWS ALB as part of a migrated application is not automatically a "Retire strategy" for the workload.

AWS defines Retire as decommissioning applications or resources that are no longer needed.  
**Source:** AWS Prescriptive Guidance - Migration strategies.

---

# 15. Retain

Retain means:

> Keep the workload in the current environment for now.

Reasons may include:

```text
No current business justification
Migration risk is too high
Technical dependency
Contract or licensing requirement
Hardware dependency
Application is scheduled to be replaced later
Migration must be postponed
```

Example:

```text
Most applications move to AWS.

A licensed SQL Server environment remains on-premises temporarily
because the organization has operational or licensing reasons
to postpone its migration.
```

Retain does not mean the application can never migrate.

It means:

```text
Not now.
```

**Source:** AWS Prescriptive Guidance - Migration strategies.

---

# 16. Rehost

Rehost is commonly called:

```text
Lift and Shift
```

The application is moved with minimal architectural change.

Example:

```text
On-prem VM
    |
    v
Amazon EC2
```

or:

```text
VMware VM
    |
    v
EC2
```

AWS Application Migration Service can be used to rehost supported physical, virtual, or cloud-hosted servers into AWS.  
**Source:** AWS Prescriptive Guidance - Rehost strategy.

Example:

```text
Before:
Windows Server + IIS + .NET Framework

After:
EC2 Windows Server + IIS + .NET Framework
```

---

# 17. Relocate

Relocate means moving the workload to another environment **without materially changing its architecture or platform**.

Think:

```text
Same platform
Same architecture
Different location
```

A common pattern is relocating an existing VMware-based environment into a compatible cloud-hosted VMware platform.

Do **not** use this as a Relocate example:

```text
On-prem Kubernetes
        |
        v
Amazon EKS
```

That changes the platform to a managed AWS Kubernetes service and is better described as **Replatform**.

Similarly:

```text
Self-managed Kafka
        |
        v
Amazon MSK
```

is a Replatform-style move because the target operating model changes to a managed service.

**Source:** AWS Prescriptive Guidance - Migration strategies.

---

# 18. Repurchase

Repurchase means replacing the existing application/product with another product, often SaaS.

Think:

```text
Drop and Shop
```

Examples:

```text
Legacy CRM
   |
   v
SaaS CRM
```

```text
Self-managed collaboration platform
   |
   v
Microsoft 365 / another SaaS platform
```

AWS describes common Repurchase cases as moving from traditional licensing to SaaS or replacing an application with another commercial product.  
**Source:** AWS Prescriptive Guidance - Migration strategies.

---

# 19. Replatform

Replatform means:

> Move the application to cloud while making limited changes that improve the platform without completely redesigning the application.

Also called:

```text
Lift, Tinker and Shift
```

Examples:

```text
MySQL on VM
    |
    v
Amazon RDS for MySQL
```

```text
SQL Server on VM
      |
      v
Amazon RDS for SQL Server
```

```text
Self-managed Kafka
      |
      v
Amazon MSK
```

```text
On-prem Kubernetes
      |
      v
Amazon EKS
```

The application architecture remains broadly recognizable, but responsibility for part of the platform moves to a managed service.

AWS describes Replatform as introducing cloud optimization without performing a full application re-architecture.  
**Source:** AWS Prescriptive Guidance - Replatform guidance.

---

# 20. Refactor / Re-architect

Refactor means changing the architecture to take greater advantage of cloud-native capabilities.

Example:

```text
Before
------
Monolith
   |
   v
VM
   |
   v
Database
```

```text
After
-----
API Gateway
     |
     +----> Lambda
     |
     +----> EKS / ECS Services
     |
     +----> Managed database
     |
     +----> Queue / Event service
```

Possible drivers include scalability, release independence, resilience, operational simplification, managed services, and cloud-native integration.

Important:

> Refactoring is not automatically cheaper.

For a specific workload, the redesigned architecture **may** reduce cost, or it may cost more while improving scalability, reliability, agility, or operations.

So this statement:

```text
Refactored design costs 1/2 of the monolith
```

should only be used when a workload-specific cost analysis proves it.

AWS describes Refactor/Re-architect as modifying the application architecture to use cloud-native capabilities.  
**Source:** AWS Prescriptive Guidance - Migration strategies.

---

# 21. 7Rs Quick Reference

| Strategy | Simple meaning | Example |
|---|---|---|
| Retire | Remove it | Decommission unused application |
| Retain | Keep it where it is | Leave legacy DB on-prem temporarily |
| Rehost | Move mostly as-is | VM → EC2 |
| Relocate | Move same platform/location | VMware environment → compatible cloud-hosted VMware platform |
| Repurchase | Replace product | Legacy software → SaaS |
| Replatform | Move + limited platform optimization | MySQL VM → RDS MySQL |
| Refactor | Redesign architecture | Monolith → services/serverless |

**Source:** AWS Prescriptive Guidance - Migration strategies.

---

# 22. Database Migration

Application-server migration is often comparatively straightforward when the application can simply be rebuilt or replicated.

Database migration is frequently more sensitive because the database contains changing transactional state.

Challenges can include:

```text
Large database size
Downtime
Data consistency
Schema conversion
Stored procedures
Functions
Triggers
Character sets
Replication lag
Network bandwidth
Application cutover
Rollback
```

---

# 23. Offline Database Migration

Simplified approach:

```text
Stop application writes
       |
       v
Take backup / export
       |
       v
Transfer
       |
       v
Restore to target
       |
       v
Validate
       |
       v
Point application to target
```

This is useful when the business can accept the required downtime.

AWS describes offline migration as an approach in which the source is taken offline for migration and validation before the application is cut over.  
**Source:** AWS Prescriptive Guidance - SQL Server migration strategies.

---

# 24. CDC - Change Data Capture

CDC means:

```text
Change Data Capture
```

A common migration pattern is:

```text
Source Database
      |
      | Full Load
      v
Target Database
```

while simultaneously capturing ongoing changes:

```text
INSERT
UPDATE
DELETE
```

Conceptually:

```text
Source DB
   |
   +---- Full Load ----------> Target DB
   |
   +---- Ongoing Changes ----> Target DB
             CDC
```

AWS DMS supports full-load migration and ongoing replication using CDC for supported source and target engines. AWS notes that CDC latency is not guaranteed to be real time and depends on workload, network, replication capacity, target performance, and other factors.  
**Source:** AWS Database Migration Service documentation.

---

# 25. Database Cutover Using CDC

Typical sequence:

```text
1. Create target database.

2. Start full load.

3. Keep source application running.

4. CDC continuously replicates changes.

5. Wait until replication lag is sufficiently small.

6. Enter change freeze / brief maintenance window.

7. Stop application writes.

8. Wait for remaining changes to reach target.

9. Validate source vs target.

10. Update application DB connection.

11. Start application against target.

12. Monitor.

13. Keep rollback plan until migration is accepted.
```

This can significantly reduce migration downtime compared with a backup/restore-only approach.

**Source:** AWS DMS full-load and CDC documentation.

---

# 26. Homogeneous vs Heterogeneous Database Migration

## Homogeneous

Same database engine.

Example:

```text
SQL Server
    |
    v
SQL Server
```

or:

```text
MySQL
  |
  v
RDS MySQL
```

## Heterogeneous

Different database engines.

Example:

```text
SQL Server
    |
    v
PostgreSQL
```

```text
Oracle
  |
  v
PostgreSQL
```

Heterogeneous migrations can require:

```text
Schema conversion
Data-type conversion
Stored procedure conversion
Function conversion
Application SQL changes
Testing
```

AWS DMS supports both homogeneous and heterogeneous database migration paths, and DMS Schema Conversion supports conversion for several source/target engine combinations including SQL Server or Oracle to PostgreSQL targets.  
**Source:** AWS DMS and DMS Schema Conversion documentation.

---

# 27. Example - SQL Server / Oracle to PostgreSQL

This is not simply:

```text
Copy data
```

It may require:

```text
Assess source schema
      |
      v
Identify incompatible objects
      |
      v
Convert schema
      |
      v
Fix unsupported objects
      |
      v
Create PostgreSQL target
      |
      v
Migrate data
      |
      v
CDC
      |
      v
Application testing
      |
      v
Cutover
```

AWS DMS Schema Conversion can assess migration complexity and convert supported schema/code objects for supported paths such as SQL Server → RDS/Aurora PostgreSQL and Oracle → RDS/Aurora PostgreSQL.  
**Source:** AWS DMS Schema Conversion documentation.

---

# 28. Example - E-Commerce Application Migration

Assume an e-commerce application currently runs on-premises.

Demo scenario:

```text
Application tier:
10 VMs

Database:
MySQL running across 5 VMs

Cache:
Redis

Load balancer:
On-premises load balancer
```

The quantities in this scenario are **example values provided for demo and are unverified as a real production architecture**.

## Step 1 - Discovery

Collect information about:

```text
10 application VMs
5 database VMs
Redis
Load balancer
DNS
TLS certificates
Storage
Backups
Monitoring
External integrations
Network connectivity
Peak traffic
RPO
RTO
```

Build dependency mapping:

```text
                  Users
                    |
                    v
              Load Balancer
                    |
          +---------+---------+
          |                   |
          v                   v
      App VMs             App VMs
          |
          +----------+
          |          |
          v          v
       MySQL       Redis
```

## Step 2 - Select the migration strategy

One possible target design could be:

```text
On-prem Load Balancer
        |
        v
Application Load Balancer
```

```text
Application VMs
      |
      v
Amazon EC2 / ECS / EKS
```

```text
Self-managed MySQL
      |
      v
Amazon RDS / Aurora MySQL
```

```text
Self-managed Redis
      |
      v
Amazon ElastiCache
```

This would include Replatform decisions if self-managed components are being moved to managed AWS services.

The correct target must be chosen after assessing compatibility, operational requirements, performance, cost, licensing, and availability.

## Step 3 - Build the cloud foundation

Before migration:

```text
AWS accounts
IAM
VPC
Subnets
Route tables
Security groups
VPN / Direct Connect if needed
DNS
Certificates
Logging
Monitoring
Backup
Security controls
```

## Step 4 - Build the target environment

Provision:

```text
Load balancer
Compute
Database
Cache
Security
Monitoring
Backup
```

Do not switch production DNS yet.

## Step 5 - Migrate the application tier

For Rehost, AWS Application Migration Service may be used for supported server migrations into EC2.

Alternatively:

```text
Create EC2
Install runtime
Deploy application
Configure dependencies
```

For Replatform:

```text
VM application
    |
    v
ECS / EKS
```

may require containerization and additional testing.

## Step 6 - Migrate the database

For a large database:

```text
Initial full load
      |
      v
CDC
      |
      v
Continuous synchronization
```

Before cutover:

```text
Source DB
   |
   | CDC
   v
Target DB

Lag -> sufficiently low
```

Then perform a controlled cutover.

## Step 7 - Test

Testing should include:

```text
Application functionality
Database validation
Performance
Security
Load balancer
Caching
Connectivity
Monitoring
Backup
Authentication
External integrations
```

## Step 8 - Cutover

A simple cutover can look like:

```text
Freeze application changes
        |
        v
Stop / control writes
        |
        v
Apply final DB changes
        |
        v
Validate target
        |
        v
Update DNS
        |
        v
Users reach cloud environment
```

Cutover is more than only changing DNS. It can include database endpoint changes, secrets, certificates, firewall rules, scheduled jobs, and integration endpoints.

## Step 9 - Rollback plan

Before cutover, define:

```text
When do we declare migration failure?

How do we redirect users back?

Can source database accept writes again?

How will data written to target be handled?

Who makes rollback decision?

What is the maximum rollback window?
```

---

# 29. Common Migration Execution Flow

A useful class model is:

```text
Planning
   |
   v
Pre-Discovery
   |
   v
Discovery
   |
   v
Assessment
   |
   v
Wave Planning
   |
   v
Build
   |
   v
Replicate / Migrate
   |
   v
Test
   |
   v
Cutover
   |
   v
Hypercare
   |
   v
Optimize
```

This is a practical program model; it is not intended to replace AWS's official three-phase MAP terminology.

---

# 30. Scenario - AWS EC2 to Azure VM

Assume the following demo scenario:

```text
Source: AWS EC2
Target: Azure
Criticality: Medium
Web server: IIS
Operating system: Windows Server 2022
CPU: 16 vCPU
Memory: 32 GB
Storage: 100 GB
Application: .NET Framework
Object storage dependency: Amazon S3
Database: Local MySQL
Database size: 2 GB
Domain: xyz.com
DNS: GoDaddy
TLS certificate: GoDaddy
Monitoring: None
```

All values above are **scenario inputs**, not externally verified facts.

## Step 1 - Assess before copying the source size

Do not immediately provision:

```text
16-vCPU Azure VM
32 GB RAM
100 GB disk
```

just because that is the source configuration.

First assess:

```text
Actual CPU utilization
Peak CPU
Memory utilization
Storage IOPS
Storage throughput
Network
Growth
Availability
Licensing
Application compatibility
```

The target Azure VM should be selected from actual workload requirements.

## Step 2 - Rehost the web server

A straightforward path:

```text
AWS EC2
Windows Server 2022
IIS
.NET Framework
        |
        v
Azure VM
Windows Server
IIS
.NET Framework
```

Microsoft documents Azure Migrate as supporting discovery, assessment, and migration of AWS EC2 instances to Azure VMs; AWS VMs are handled through the physical-server migration workflow.  
**Source:** Microsoft Learn - Migrate AWS EC2 instances to Azure.

## Step 3 - Choose the database target

### Option A - Keep MySQL on the Azure VM

The scenario database is:

```text
2 GB
```

This is an **example scenario value**.

Keeping it on the VM might be technically possible, but database size alone should not decide the architecture.

Consider:

```text
Availability
Backup
Patching
Security
Recovery
Operations
Performance
RPO
RTO
```

### Option B - Replatform to Azure Database for MySQL

A managed-database target could look like:

```text
Azure VM
 |
 +-- IIS
 +-- .NET Application
 |
 +----> Azure Database for MySQL
```

This separates application-server operations from database-platform operations.

## Step 4 - Migrate S3 data to Azure storage

Current dependency:

```text
Application
    |
    v
Amazon S3
```

Potential target:

```text
Application
    |
    v
Azure Blob Storage
```

Before migration, inspect:

```text
S3 API usage
SDK usage
Object metadata
Versioning
Lifecycle rules
Encryption
Access policy
Event notifications
Presigned URLs
Object volume
Data size
```

Application code may require changes because S3 and Azure Blob Storage have different APIs and access models.

## Step 5 - Design the public endpoint

Do not automatically attach a public IP directly to the VM in every production design.

Depending on requirements, the target might use components such as:

```text
Azure Application Gateway
Azure Load Balancer
Azure Front Door
WAF
```

The exact choice is outside the supplied scenario and should be assessed rather than assumed.

## Step 6 - TLS and DNS

The source scenario says TLS and DNS are managed through GoDaddy.

Before cutover, determine:

```text
Where is TLS terminated today?

IIS?
Load balancer?
CDN?
```

Do not update DNS until:

```text
TLS works
Application works
Database works
Storage works
Monitoring works
Rollback is ready
```

Once validated:

```text
xyz.com
   |
   | old DNS
   v
AWS endpoint
```

changes to:

```text
xyz.com
   |
   | new DNS
   v
Azure endpoint
```

## Step 7 - Final migration sequence

```text
1. Discover EC2 workload.
2. Measure actual utilization.
3. Map dependencies.
4. Assess Azure target sizing.
5. Build Azure networking/security.
6. Provision target compute.
7. Migrate/redeploy IIS + .NET application.
8. Migrate MySQL to VM or managed Azure MySQL.
9. Migrate S3 objects to Azure Blob if required.
10. Change application configuration.
11. Configure TLS.
12. Configure monitoring.
13. Test application.
14. Test performance.
15. Test database.
16. Validate object storage.
17. Prepare rollback.
18. Freeze changes if required.
19. Perform final data synchronization.
20. Update DNS.
21. Monitor closely.
22. Decommission AWS resources only after acceptance.
```

Microsoft documents Azure Migrate as the supported service for discovery, assessment, and migration of AWS EC2 instances into Azure VMs.  
**Source:** Microsoft Learn - Azure Migrate AWS EC2 tutorial.

---

# 31. Migration Decision Examples

## VM to EC2

```text
Minimal change
=
Rehost
```

## MySQL VM to RDS MySQL

```text
Same engine
Managed platform
=
Replatform
```

## SQL Server to PostgreSQL

```text
Database engine changes
Application/schema changes likely
=
Usually Refactor / Re-architect
```

AWS describes SQL Server → PostgreSQL as a heterogeneous database migration and associates engine changes that require application/database restructuring with re-architecture/refactoring.  
**Source:** AWS Prescriptive Guidance - SQL Server database migration strategies.

## Legacy product to SaaS

```text
Repurchase
```

## Keep workload on-premises

```text
Retain
```

## Remove unused workload

```text
Retire
```

---

# 32. Final Mental Model

```text
              MIGRATION

                 |
                 v
              ASSESS
        What do we have?
        Why are we moving?
        What depends on what?
        What will it cost?
                 |
                 v
             MOBILIZE
        Build cloud foundation
        Security
        Networking
        IAM
        Operations
                 |
                 v
        MIGRATE & MODERNIZE
        Execute waves
        Replicate
        Test
        Cut over
                 |
                 v
        OPERATE & OPTIMIZE
        Cost
        Security
        Reliability
        Automation
        Modernization
```

For every workload, ask:

```text
Retire?
Retain?
Rehost?
Relocate?
Repurchase?
Replatform?
Refactor / Re-architect?
```

Then build the migration plan around the chosen strategy, dependencies, downtime tolerance, RPO/RTO, and business priority.

---