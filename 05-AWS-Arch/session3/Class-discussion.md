# High Availability, Disaster Recovery, RPO/RTO and AWS Backup

> **Headline:** High Availability keeps an application running through component or Availability Zone failures, while Disaster Recovery defines how the business restores service after a larger disaster, commonly including the loss of an AWS Region.

---

## 1. High Availability (HA) vs Disaster Recovery (DR)

A useful beginner mental model is:

```text
HA  -> How do I keep the application running when something fails?
DR  -> How do I recover the application when a major disaster takes out the primary environment?
```

```text
HA = Zonal redundancy
DR = Regional redundancy
```

AWS guidance commonly uses **Multi-AZ** design for high availability within a Region, while **Multi-Region** patterns are used when the requirement includes protection from loss of an entire Region. A DR plan can also protect against smaller disasters depending on how the business defines a disaster.  

### Practical difference

| Area | High Availability | Disaster Recovery |
|---|---|---|
| Main objective | Keep the service available during failures | Recover the service after a major disruption |
| Typical AWS scope | Multiple AZs inside one Region | Often multiple Regions |
| Typical failures | Instance failure, database failure, AZ disruption | Regional disruption, destructive cyber incident, major operational disaster |
| Mechanism | Redundancy + health checks + failover | Backup/replication + recovery environment + failover process |
| Business focus | Continuous service | RPO and RTO |
| Cost | More than a single-instance design | Increases as recovery objectives become more aggressive |


---

# 2. High Availability

High Availability means designing the workload so that the failure of one important component does not automatically make the entire application unavailable.

A common pattern is:

```text
                        Internet
                           |
                           v
                    +-------------+
                    |     ALB     |
                    +-------------+
                       /       \
                      /         \
                     v           v
             +-------------+ +-------------+
             | EC2 / App 1 | | EC2 / App 2 |
             |    AZ-A     | |    AZ-B     |
             +-------------+ +-------------+
                      \         /
                       \       /
                        v     v
                     +---------+
                     |   RDS   |
                     |Multi-AZ |
                     +---------+
```

Amazon RDS Multi-AZ DB instance deployments maintain a synchronous standby in another Availability Zone for high availability.  


---

# 3. Voting Website Example

Assume a voting application is hosted in:

```text
AWS Region: Asia Pacific (Mumbai)
Region code: ap-south-1
```

AWS currently lists three Availability Zone IDs for `ap-south-1`: `aps1-az1`, `aps1-az2`, and `aps1-az3`. Availability Zone names such as `ap-south-1a` are account-facing labels; AZ IDs are the stable identifiers across accounts.  


> **Availability target: 98%** - this number comes from the example and is **unverified as a real business requirement**. A real availability target should come from an SLA, SLO, BIA or business requirement.

## Beginner design: one large EC2 instance

A beginner might design:

```text
Internet
   |
   v
 ALB
   |
   v
One very large EC2 instance
```

The main problem is not the size of the instance. The problem is the **single compute failure point**.

If that one EC2 instance fails, the application becomes unavailable until it is recovered or replaced.

A better architecture spreads capacity across multiple instances and Availability Zones.  



## Better design

```text
                         ALB
                          |
               +----------+----------+
               |          |          |
               v          v          v
            EC2-1      EC2-2      EC2-3
             AZ-A       AZ-B       AZ-C
```

If one server fails:

```text
EC2-1   -> DOWN
EC2-2   -> HEALTHY
EC2-3   -> HEALTHY
```

traffic can continue to healthy targets if the workload has enough surviving capacity.

If one Availability Zone fails, the instances in the remaining AZs can continue serving traffic if the application is correctly distributed and sized.



---

# 4. HA Is More Than Multiple Servers

A highly available architecture normally considers every important layer:

```text
                       Route 53 / DNS
                              |
                              v
                            ALB
                              |
                 +------------+------------+
                 |                         |
                 v                         v
              EC2/ECS                   EC2/ECS
                AZ-A                      AZ-B
                 \                         /
                  \                       /
                   +----------+----------+
                              |
                              v
                         RDS Multi-AZ
```

Think about:

- Compute redundancy
- Load balancing
- Database availability

---

# 5. RDS Single-AZ vs Multi-AZ

## Single-AZ

```text
Application
    |
    v
 RDS Primary
    |
   AZ-A
```

If the DB instance or its AZ has a failure, you do not have the same standby failover design provided by a Multi-AZ deployment.

## Multi-AZ DB instance

```text
                  Application
                       |
                       v
                RDS Endpoint
                       |
              +--------+--------+
              |                 |
              v                 v
          Primary           Standby
            AZ-A              AZ-B
              |                 ^
              +----sync---------+
```

For an RDS Multi-AZ DB instance deployment, AWS provisions and maintains a **synchronous standby replica in a different Availability Zone**. The standby is used for high availability and does not serve normal read traffic.  


### Important

```text
Multi-AZ != read scaling
```

For the traditional Multi-AZ DB instance model:

```text
Primary -> application traffic
Standby -> HA / failover
```

For read scaling, use an appropriate read-scaling architecture such as read replicas or an RDS Multi-AZ DB cluster where suitable.  


---

# 6. IaaS vs PaaS

## IaaS - Infrastructure as a Service

IaaS provides fundamental resources such as compute, networking and storage while the customer retains significant control of the operating system and software stack.

### MySQL on EC2

```text
AWS manages:
-------------
Physical infrastructure
Virtualization layer
Underlying data-center facilities

You manage:
-----------
Operating system
OS patching
MySQL installation
MySQL patching
Database configuration
Backups
Replication
HA design
Application
```

This is an **IaaS-style** database deployment.

## PaaS - Platform as a Service

PaaS removes more of the responsibility for managing the underlying infrastructure and operating system, allowing the customer to focus more on the application or data platform.  


## Is RDS PaaS?

For beginner teaching, it is reasonable to call RDS **PaaS-like**, but AWS normally describes Amazon RDS as a **managed relational database service** rather than simply labeling it PaaS.

With RDS, AWS manages activities such as:

- Infrastructure provisioning
- Operating-system maintenance
- Database software patching
- Automated backups
- Failure detection
- Many recovery operations

You still manage:

- Schema
- SQL
- Indexes
- Users and permissions
- Query tuning
- Application connectivity
- Capacity and configuration choices



### Responsibility comparison

| Responsibility | MySQL on EC2 | Amazon RDS |
|---|---|---|
| Physical infrastructure | AWS | AWS |
| Operating system | You | AWS |
| DB installation | You | AWS |
| DB software patching | You | Mostly AWS-managed |
| Backups | You design/manage | RDS can automate |
| Schema / SQL / indexes | You | You |
| Application | You | You |
| Root OS access | Yes | No normal root/OS access |



---

# 7. Cost Implications of HA

HA costs more because you deliberately maintain redundant capacity.

```text
Non-HA
------
1 application instance
Single-AZ DB

HA
--
Multiple application instances
Multiple AZs
Multi-AZ database
Additional resilience-related resources as required
```

There is **no universal HA cost multiplier**. The exact cost depends on the services and capacity used.  

## Should HA only be used in production?

A better rule is:

> **Use HA where the business impact justifies the cost.**

Production environments normally have the strongest HA requirements, but HA can also make sense for critical shared test environments, release-certification environments, performance platforms or any non-production environment whose outage creates significant business impact.



---

# 8. What If a Single-AZ Non-Prod RDS Database Fails?

Assume:

```text
RDS
 |
 +-- Single-AZ
 |
 +-- AZ-A
```

If the database becomes unavailable and you do not have a Multi-AZ standby, recovery mechanisms become important.

Possible recovery sources include:

- Automated RDS backups
- Manual DB snapshots
- AWS Backup recovery points
- Cross-Region backup copies if configured

Amazon RDS supports automated backups and snapshots that can be used to restore a database.  

## Important correction: "put the RDS backup in my S3 bucket"

From a normal RDS-user perspective, automated RDS backups are **not typically managed as a SQL backup file that you manually copy into your own S3 bucket**.

Conceptually:

```text
RDS
 |
 v
Automated backup / snapshot
 |
 v
AWS-managed backup storage
 |
 v
Restore
 |
 v
New RDS DB instance
```

AWS Backup can also centrally manage supported recovery points.  

---

# 9. HA vs Backup

These solve different problems.

```text
HA
 |
 +--> Keep the application available through certain failures
```

```text
Backup
 |
 +--> Recover historical data/state
```

Examples:

```text
AZ failure
   |
   +--> Multi-AZ helps availability
```

```text
Accidental deletion
Data corruption
Destructive incident
   |
   +--> Backup / PITR may be required
```

Even active-active systems still need backups because replication can propagate corrupted or deleted data.  


---

# 10. Disaster Recovery

Now consider a more severe event:

```text
Primary Region: Mumbai (ap-south-1)

                 X
          Primary Region unavailable
```

DR is about recovering the workload when the primary environment cannot run it according to the organization's recovery objectives.  


Possible causes can include:

- Severe infrastructure disruption
- Cyber incidents
- Human error
- Natural disasters
- Major service disruption

The exact event matters less than the business outcome: **the primary environment cannot deliver the required service**.

---

# 11. Business Continuity vs Disaster Recovery

## Business Continuity (BC)

Business Continuity asks:

> How will the organization continue delivering critical business services during a major disruption?

BC is broader than IT and may include people, facilities, communications, suppliers, business processes and technology.

## Disaster Recovery (DR)

DR is the technology-focused capability for recovering applications, systems and data.

```text
Business Continuity
       |
       +--- People
       +--- Process
       +--- Facilities
       +--- Vendors
       +--- Technology
                |
                +--- Disaster Recovery
```



---

# 12. Mission-Critical Payment Example

Imagine a payment company serving a very large number of merchants and hosting its entire payment stack in one AWS Region.

If that Region becomes unusable:

```text
Merchant
   |
   v
Payment API
   |
   X  Primary Region unavailable
```

then a single-Region design cannot satisfy a requirement to continue processing from another Region.

When the requirement explicitly includes protection from Region loss, AWS recommends considering Multi-Region DR strategies. 

---

# 13. Four Common AWS DR Strategies

AWS commonly discusses four approaches:

```text
Lower cost / longer recovery
          |
          v
Backup & Restore
          |
          v
Pilot Light
          |
          v
Warm Standby
          |
          v
Multi-Site Active/Active
          |
Higher cost / shorter recovery
```

---

# 14. Backup and Restore

```text
Primary Region
--------------
Application
EC2
RDS
  |
  v
Backups
  |
  +----------------------+
                         |
                         v
                  Recovery Region
                  ---------------
                  Backup copies
                  Infrastructure may
                  not be running yet
```

During disaster:

```text
Restore data
    |
Deploy infrastructure
    |
Deploy application
    |
Validate
    |
Redirect traffic
```

AWS describes Backup and Restore as the least complex and lowest-cost of the four common approaches, but it generally has the highest recovery time and data-loss window. AWS Well-Architected gives a typical pattern of **RPO in hours and RTO up to 24 hours or less**, while some backup technologies can achieve lower RPOs.  

### Cost


```text
Relative cost: LOW
```

---

# 15. Pilot Light

Pilot Light keeps the critical core of the workload ready in the recovery Region, especially the data layer, while some application infrastructure is not yet running.

```text
Primary Region                   Recovery Region
--------------                   ---------------
Full application                 Data replicated
Full compute      ---------->    Core services
Database                         Minimal infrastructure
                                 Compute may need deployment/start
```

During disaster:

```text
Deploy/start missing resources
        |
Scale environment
        |
Promote/reconfigure data if required
        |
Redirect traffic
```

AWS describes typical Pilot Light objectives as **RPO in minutes and RTO in tens of minutes**.  

### Cost

```text
Relative cost: MEDIUM
```

---

# 16. Warm Standby

Warm Standby keeps a **fully functional but scaled-down** version of the production environment running in another Region.

```text
Primary Region                    Recovery Region
--------------                    ---------------
Full-size application             Smaller running application
Full-size compute                 Reduced compute
Live database       ---------->   Live replicated data
Serving traffic                   Ready to take traffic
```

During disaster:

```text
Scale recovery environment
        |
Redirect traffic
```

Unlike Pilot Light, Warm Standby is already capable of processing traffic at reduced capacity before failover.

AWS describes Warm Standby as typically targeting **RPO in seconds and RTO in minutes**.  

### Cost

```text
Relative cost: HIGH
```

---

# 17. Pilot Light vs Warm Standby

```text
PILOT LIGHT
-----------
Core/data services exist
Application cannot necessarily serve normal traffic yet
Additional resources must be deployed or started
```

```text
WARM STANDBY
------------
Complete application exists
Runs at reduced capacity
Can already process some traffic
Needs scaling during failover
```

---

# 18. Multi-Site Active/Active

Both Regions actively run the workload.

```text
                         Users
                           |
                    Route 53 /
                 Global Accelerator
                      /         \
                     /           \
                    v             v
             Mumbai Region   Hyderabad Region
                ACTIVE           ACTIVE
                   \              /
                    \            /
                     Data synchronization
```

Traffic is served from multiple Regions during normal operation.

AWS describes Multi-Site Active/Active as the most operationally complex of these strategies, with **RPO near zero and RTO potentially zero** when correctly designed for the relevant failure mode.  

Possible AWS data technologies for Multi-Region systems include services such as DynamoDB Global Tables and Aurora Global Database, depending on application requirements. The actual consistency and failover behavior is service-specific.

### Cost

```text
Relative cost: VERY HIGH
```

because there is no universal AWS multiplier.

---

# 19. DR Strategy Comparison

| Strategy | Recovery Environment | Typical AWS RPO guidance | Typical AWS RTO guidance | Relative cost |
|---|---|---:|---:|---|
| Backup & Restore | Mostly backups | Hours | Up to 24h or less | Low |
| Pilot Light | Core/data services ready | Minutes | Tens of minutes | Medium |
| Warm Standby | Full but scaled-down stack running | Seconds | Minutes | High |
| Active/Active | Full stack serving in multiple Regions | Near zero | Potentially zero | Very high |

---

# 20. Business Impact Analysis (BIA)

Before choosing a DR architecture, ask:

```text
What happens if this application is unavailable for 5 minutes?

What happens after 30 minutes?

What happens after 2 hours?

How many customers are affected?

How much revenue is affected?

How many teams are blocked?

Are there regulatory or contractual consequences?

Is there a manual workaround?
```

The business impact helps determine the acceptable downtime and data-loss targets that drive RTO and RPO.  

---

# 21. RPO - Recovery Point Objective

RPO answers:

> **How much data can the business afford to lose, measured in time?**

## Example

Assume:

```text
Backup frequency: every 30 minutes

10:30 PM -> Backup
11:00 PM -> Backup
11:29 PM -> Disaster
```

If the latest usable recovery point is 11:00 PM:

```text
11:00 ---------------- 11:29
        data at risk
```

The actual data-loss window in this particular incident is:

```text
29 minutes
```

The configured target may have been:

```text
RPO = 30 minutes
```

Remember:

```text
RPO              = target / acceptable data-loss window
Actual data loss = what was really lost in a specific incident
```

**29-minute figure:** calculated from the example timestamps.

---

# 22. Mission-Critical RPO

A critical workload may require:

```text
RPO < 5 minutes
```

or:

```text
RPO near zero
```

This generally requires more continuous replication/data-protection mechanisms than infrequent backups.

AWS associates more aggressive RPOs with strategies such as Warm Standby and Multi-Site Active/Active. 

---

# 23. RTO - Recovery Time Objective

RTO answers:

> **How long can the service remain unavailable after the interruption?**

AWS defines RTO as the maximum acceptable delay between interruption and restoration of service. 

## Example

```text
11:15 PM -> Disaster
11:20 PM -> Service restored
```

Recovery time:

```text
5 minutes
```

If the business requirement is restoration within five minutes:

```text
RTO = 5 minutes
```

---

# 24. RPO vs RTO

```text
             Last Recovery Point       Disaster          Service Restored
                    |                     |                     |
--------------------|---------------------|---------------------|---------
                    <------ RPO ---------><------- RTO -------->
```

Think:

```text
RPO = DATA LOSS tolerance
RTO = DOWNTIME tolerance
```



---

# 25. Does Active/Active Mean RTO = 0 and RPO = 0?

Do not treat zero as guaranteed.

AWS describes Multi-Site Active/Active as:

```text
RPO -> near zero
RTO -> potentially zero
```

because the actual outcome depends on data replication, routing, failure mode and implementation.

Data corruption is a good example: replication can propagate corruption to another Region, so backup/PITR can still be required.  


---

# 26. Backups and Recovery - EC2 Scenario

Suppose you have:

```text
Mumbai Region
-------------
5 production EC2 instances

US East (N. Virginia)
---------------------
5 production EC2 instances
```

Requirement:

```text
Take backups daily
Retain only 7 days
```

AWS Backup can centrally define:

- Backup schedules
- Backup vaults
- Resource assignments
- Lifecycle/retention
- Cross-Region copies for supported resource types

---

# 27. What Does "Backup an EC2 Instance" Mean?

An EC2 instance commonly has:

```text
EC2 instance
   |
   +-- Root EBS volume
   |
   +-- Additional EBS volumes
   |
   +-- Instance configuration
```

When AWS Backup restores an EC2 recovery point, it can create:

- An AMI
- The EC2 instance
- The root EBS volume
- Additional EBS data volumes
- EBS snapshots

---

# 28. AMI vs EBS Snapshot

## EBS Snapshot

Conceptually:

```text
EBS Volume
    |
    v
Snapshot
```

A snapshot protects EBS volume data.

## AMI

Conceptually:

```text
AMI
 |
 +-- Root-volume mapping
 +-- Block-device mappings
 +-- Launch information
```

An AMI is used to launch EC2 instances. AWS Backup uses EC2/EBS recovery mechanisms when restoring protected EC2 resources. 

---