# Hands-On Lab - Create Amazon RDS for Non-Production and Production

## Lab outcome

Create an Amazon RDS for MySQL database and understand the architectural difference between:

```text
Non-Production
     |
     v
Single-AZ RDS
```

and:

```text
Production
     |
     v
Multi-AZ RDS
```

By the end of the lab, you will:

- Create an RDS MySQL database.
- Create or select a DB subnet group.
- Configure database security groups.
- Keep the database private.
- Choose **Single-AZ** for a lower-cost non-production design.
- Choose **Multi-AZ DB instance** for a production-style HA design.
- Connect to the database from an EC2 instance.
- Create a test database and table.
- Understand the difference between HA and backup.

> **Key idea:** Single-AZ and Multi-AZ are deployment choices based on availability requirements. Multi-AZ maintains a standby DB instance in another Availability Zone and supports automatic failover for certain failures; it is not the same as a backup.

---

# Architecture

## Option A - Non-Production

```text
                     VPC
        +----------------------------+

        Application Subnet
        +------------------+
        |       EC2        |
        |    App / Client  |
        +--------+---------+
                 |
                 | TCP 3306
                 v
        Private DB Subnet
        +------------------+
        |       RDS        |
        |      MySQL       |
        |    Single-AZ     |
        +------------------+

        +----------------------------+
```

This is suitable for a lab, development, test, or another environment where the business accepts the recovery impact of losing the DB instance or its AZ.

The decision should still be based on the workload requirement rather than assuming all non-production environments can tolerate downtime.

---

## Option B - Production-Style HA

```text
                             VPC
              +--------------------------------+

                        Application
                            EC2
                             |
                             | TCP 3306
                             v
                      RDS DB Endpoint
                             |
                  +----------+----------+
                  |                     |
                  v                     v
             RDS Primary           RDS Standby
                AZ-A                  AZ-B
                  |                     ^
                  +---- synchronous ----+

              +--------------------------------+
```

For an RDS **Multi-AZ DB instance deployment**, AWS maintains a synchronous standby replica in another Availability Zone and can automatically fail over for supported failure conditions.

> The standby in the traditional Multi-AZ DB instance deployment is for availability. It does not normally serve application read traffic.

---

# Prerequisites

- Access to the AWS Management Console.
- Permission to manage:
  - Amazon VPC
  - Subnets
  - Security groups
  - Amazon EC2
  - Amazon RDS
- One VPC.
- At least two subnets in different Availability Zones for the DB subnet group.
- One EC2 instance that can be used as a MySQL client.
- Select one AWS Region and use it throughout the lab.

Example:

```text
Region: Asia Pacific (Mumbai)
Region code: ap-south-1
```

> Amazon RDS DB subnet groups for DB instances must cover at least two Availability Zones.

---

# Lab 1 - Review the VPC

Open:

```text
VPC → Your VPCs
```

Select the VPC that will contain the application and database.

Record:

```text
VPC ID:
IPv4 CIDR:
Region:
```

Example:

```text
VPC CIDR = 10.20.0.0/16
```

The exact CIDR depends on your lab environment.

---

# Lab 2 - Verify the DB subnets

Open:

```text
VPC → Subnets
```

Ensure you have at least two subnets in different Availability Zones.

Example:

| Subnet | Example CIDR | Availability Zone | Purpose |
|---|---|---|---|
| `db-subnet-a` | `10.20.11.0/24` | AZ-A | RDS |
| `db-subnet-b` | `10.20.12.0/24` | AZ-B | RDS |

The specific subnet ranges and AZ labels are lab values rather than AWS requirements.

Conceptually:

```text
VPC
 |
 +-- db-subnet-a -> AZ-A
 |
 +-- db-subnet-b -> AZ-B
```

---

# Lab 3 - Create an RDS DB subnet group

Open:

```text
RDS
 |
 v
Subnet groups
 |
 v
Create DB subnet group
```

Configure:

| Setting | Value |
|---|---|
| Name | `architecture-lab-db-subnet-group` |
| Description | `Private DB subnets for RDS lab` |
| VPC | Select the lab VPC |

Under **Add subnets**:

1. Select at least two Availability Zones.
2. Select the two DB subnets.
3. Choose **Create**.

Validate:

```text
architecture-lab-db-subnet-group
 |
 +-- subnet in AZ-A
 |
 +-- subnet in AZ-B
```

---

# Lab 4 - Create the application security group

If an EC2 security group already exists for the application, you can reuse it.

Otherwise open:

```text
EC2 → Security Groups → Create security group
```

Configure:

```text
Name:
architecture-lab-app-sg

VPC:
<lab-vpc>
```

For this database exercise, the important point is that RDS will allow MySQL traffic **from this security group**, not from the whole internet.

---

# Lab 5 - Create the RDS security group

Create another security group:

```text
Name:
architecture-lab-rds-sg
```

Add inbound rule:

| Type | Protocol | Port | Source |
|---|---|---:|---|
| MySQL/Aurora | TCP | 3306 | `architecture-lab-app-sg` |

Conceptually:

```text
EC2
 |
 | application security group
 |
 v
architecture-lab-app-sg
 |
 | TCP 3306
 v
architecture-lab-rds-sg
 |
 v
RDS
```

Do not use this for the lab:

```text
MySQL
Port: 3306
Source: 0.0.0.0/0
```

A private application database should not normally be opened to the entire internet.

---

# Lab 6 - Start RDS creation

Open:

```text
AWS Console
   |
   v
RDS
   |
   v
Databases
   |
   v
Create database
```

Choose:

```text
Standard create
```

This exposes the settings needed to understand the architecture.

---

# Lab 7 - Select the database engine

Choose:

```text
Engine type:
MySQL
```

Select an engine version supported by the current console and your lab requirements.

Do not hard-code an old engine version in training notes because supported versions change over time.

---

# Lab 8 - Choose the deployment model

This is the key learning step.

## Option A - Non-Production

Choose:

```text
Availability & durability
        |
        v
Single DB instance
```

Conceptually:

```text
RDS MySQL
   |
   v
One DB instance
   |
   v
One AZ
```

Use this path if the lab represents a development/test environment and the additional downtime risk is acceptable.

---

## Option B - Production

Choose:

```text
Availability & durability
        |
        v
Multi-AZ DB instance
```

Conceptually:

```text
             RDS Endpoint
                  |
        +---------+---------+
        |                   |
        v                   v
     Primary             Standby
      AZ-A                AZ-B
        |                   ^
        +---- sync ----------+
```

AWS handles the standby and failover relationship.

> This lab uses **Multi-AZ DB instance**, not **Multi-AZ DB cluster**. A Multi-AZ DB cluster is a different RDS deployment architecture.

---

# Lab 9 - Configure database settings

Example:

| Setting | Value |
|---|---|
| DB instance identifier | `architecture-lab-mysql` |
| Master username | `admin` |
| Credentials management | Choose an approved lab option |
| Initial database name | Optional |

If using a manually entered password:

```text
Use a strong lab password.
Do not place the password in source code.
```

For production environments, consider managed secret storage rather than distributing static credentials.

---

# Lab 10 - Choose the DB instance class

For a lab, choose a small supported DB instance class that fits the account budget.

Do not select a large instance just because production traffic may eventually be high.

Sizing should come from:

```text
CPU requirement
Memory requirement
Connections
IOPS
Storage throughput
Query workload
Observed utilization
Growth
Failover requirement
Cost
```

The exact DB class is intentionally not fixed because supported classes and Free Tier eligibility can change.

---

# Lab 11 - Configure storage

Choose storage appropriate for the lab.

Example:

```text
Storage type:
General Purpose SSD

Allocated storage:
Small lab-appropriate value
```

Review whether storage autoscaling is enabled.

For production, storage sizing should be driven by workload, IOPS, throughput, growth and operational requirements.

---

# Lab 12 - Configure connectivity

Configure:

```text
Compute resource:
Do not connect automatically / choose existing EC2 integration as appropriate

VPC:
<lab-vpc>

DB subnet group:
architecture-lab-db-subnet-group

Public access:
No

VPC security group:
architecture-lab-rds-sg
```

Keep:

```text
Port = 3306
```

for MySQL unless the lab intentionally uses another port.

---

# Lab 13 - Review authentication options

The console may expose database authentication choices depending on the engine and version.

For the beginner lab, standard password authentication is sufficient.

Record:

```text
Master username:
Credential-management option:
```

Do not write the actual password into the lab worksheet.

---

# Lab 14 - Configure backup settings

RDS has its own automated-backup capability.

Review:

```text
Backup retention period
Backup window
Copy tags to snapshots
```

The exact values should follow the lab requirement.

> RDS automated backup is separate from Multi-AZ. Multi-AZ provides availability; backup provides recoverability.

---

# Lab 15 - Review deletion protection

For a disposable training database:

```text
Deletion protection:
Optional according to instructor policy
```

For important production databases, deletion protection is commonly considered as an additional safeguard.

Do not enable settings that prevent lab cleanup unless you understand how to remove them later.

---

# Lab 16 - Create the database

Review the estimated monthly cost displayed by the console.

Then choose:

```text
Create database
```

Open:

```text
RDS → Databases → architecture-lab-mysql
```

Wait until status becomes:

```text
Available
```

---

# Lab 17 - Find the database endpoint

Open the database details.

Locate:

```text
Connectivity & security
```

Record:

```text
Endpoint:
Port:
VPC:
Availability configuration:
Security group:
```

The endpoint will look conceptually like:

```text
architecture-lab-mysql.xxxxxxxxxxxx.ap-south-1.rds.amazonaws.com
```

Use the endpoint displayed by your account rather than copying this example.

---

# Lab 18 - Prepare the EC2 client

Connect to the EC2 instance that uses:

```text
architecture-lab-app-sg
```

Install a MySQL client appropriate for the operating system.

For Amazon Linux, package names vary by release.

Verify:

```bash
mysql --version
```

If the command is not available, install the MySQL-compatible client package appropriate for the OS.

---

# Lab 19 - Test network connectivity

From the EC2 instance:

```bash
nc -zv <RDS-ENDPOINT> 3306
```

or use another approved TCP connectivity test.

Expected:

```text
EC2
 |
 | TCP 3306
 v
RDS endpoint
```

If it fails, inspect:

```text
EC2 security group
RDS security group
VPC
Subnet routing
DB status
DB endpoint
Port
```

---

# Lab 20 - Connect to MySQL

Run:

```bash
mysql -h <RDS-ENDPOINT> -P 3306 -u admin -p
```

Enter the password when prompted.

Do not put the password directly on the command line.

---

# Lab 21 - Create test data

Inside MySQL:

```sql
CREATE DATABASE voting;

USE voting;

CREATE TABLE candidates (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL
);

INSERT INTO candidates (name)
VALUES ('Candidate-A'), ('Candidate-B');

SELECT * FROM candidates;
```

Expected conceptual result:

```text
+----+-------------+
| id | name        |
+----+-------------+
| 1  | Candidate-A |
| 2  | Candidate-B |
+----+-------------+
```

---

# Lab 22 - Compare Single-AZ and Multi-AZ

Complete:

| Question | Single-AZ | Multi-AZ DB instance |
|---|---|---|
| Number of DB instances for HA | One | Primary + standby |
| Cross-AZ standby | No | Yes |
| Synchronous standby | No | Yes |
| Automatic RDS failover for supported DB/AZ failures | No equivalent standby | Yes |
| Normal reads from standby | N/A | No |
| Cost | Lower | Higher |
| Typical teaching use | Dev/Test | Production HA |

The actual choice must be based on workload requirements, not the environment name alone.

---

# Lab 23 - Optional: convert Single-AZ to Multi-AZ

If the lab account permits modification:

```text
RDS
 |
 v
Databases
 |
 v
Select DB
 |
 v
Modify
```

Find:

```text
Availability & durability
```

Change the deployment to:

```text
Multi-AZ DB instance
```

Review whether the change applies:

```text
Immediately
```

or during the:

```text
Maintenance window
```

Do not modify a shared environment without instructor approval.

---

# Lab 24 - Understand failure behavior

## Single-AZ

```text
DB / AZ failure
      |
      v
Database unavailable
      |
      v
Recover / restore / replace
```

## Multi-AZ

```text
Primary failure
      |
      v
RDS detects supported failure
      |
      v
Failover
      |
      v
Standby becomes primary
      |
      v
Application reconnects through DB endpoint
```

The actual failover time is not fixed in this lab and should be measured for the workload rather than assumed.

---

# Lab 25 - HA is not Backup

Even a Multi-AZ database still needs backup.

Consider:

```text
Accidental DELETE FROM important_table;
```

The standby receives database changes as part of replication.

Multi-AZ therefore does not provide a historical recovery point for every logical mistake.

Think:

```text
Multi-AZ
   |
   +--> Availability

Backup / PITR
   |
   +--> Recovery
```

---

# Lab 26 - Cleanup

If the database is disposable:

1. Open **RDS → Databases**.
2. Select `architecture-lab-mysql`.
3. Choose **Delete**.
4. Decide whether a final snapshot is required by the instructor.
5. Remove deletion protection first if it was enabled.
6. Delete lab-only security groups after dependencies are removed.
7. Delete the DB subnet group only if it was created exclusively for the lab.

Do not delete shared VPC resources.

---