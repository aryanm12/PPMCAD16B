# Hands-On Lab - Automated Backups with AWS Backup

## Lab outcome

Create a centralized AWS Backup policy that protects AWS resources automatically, retains recovery points for a defined period, and optionally copies backups to another AWS Region.

The lab covers the practical backup choices for:

```text
Amazon EBS
Amazon EC2
Amazon RDS
Amazon S3
```

and explains where terms such as:

```text
Snapshot
AMI
Recovery point
Continuous backup
Cross-Region copy
```

fit into the architecture.

By the end of the lab, you will:

- Create AWS Backup vaults.
- Create a scheduled backup plan.
- Set retention.
- Assign resources explicitly or by tags.
- Protect EBS volumes.
- Protect full EC2 instances.
- Protect RDS.
- Protect S3.
- Configure cross-Region copies.
- Monitor backup and copy jobs.
- Locate recovery points.
- Review restore workflows.
- Understand which resource creates which type of recovery point.

> **Key idea:** AWS Backup is a policy and orchestration service. You normally select the AWS resource to protect; AWS Backup then uses the backup mechanism appropriate for that service.

---

# Architecture

```text
                    AWS Resources
                         |
       +-----------------+-----------------+
       |                 |                 |
       v                 v                 v
      EC2               RDS               S3
       |                 |                 |
       +-----------------+-----------------+
                         |
                         v
                    AWS Backup
                         |
                         v
                   Backup Plan
                         |
          +--------------+--------------+
          |                             |
          v                             v
    Primary-Region Vault        Cross-Region Copy
                                      |
                                      v
                               DR-Region Vault
```

---

# Important terminology before the lab

## EBS backup

For Amazon EBS, AWS Backup protects the volume using snapshot-based recovery points.

Conceptually:

```text
EBS Volume
    |
    v
AWS Backup
    |
    v
EBS recovery point / snapshot-based backup
```

---

## EC2 backup

When you select:

```text
Resource type = EC2
```

AWS Backup protects the EC2 instance as an EC2 recovery point.

During restore, AWS Backup can recreate:

```text
AMI
EC2 instance
Root EBS volume
Data EBS volumes
EBS snapshots
```

This is different from manually creating only an AMI.

Think:

```text
AWS Backup EC2 recovery point
          |
          v
      Restore EC2
          |
          +-- AMI
          +-- EC2 instance
          +-- Root volume
          +-- Data volumes
          +-- EBS snapshots
```

---

## RDS backup

AWS Backup supports Amazon RDS DB instances, including Single-AZ and Multi-AZ DB instances.

Depending on the backup configuration and resource support, RDS protection can include:

```text
Periodic/snapshot backup
```

and:

```text
Continuous backup / PITR
```

Cross-Region copies of continuous backups become snapshot-style copies and do not retain PITR capability in the copied recovery point.

---

## S3 backup

AWS Backup supports:

```text
Periodic S3 backup
```

and:

```text
Continuous S3 backup with PITR
```

S3 Versioning must be enabled for AWS Backup for Amazon S3.

The first S3 backup is full; subsequent backups can be incremental at object level.

---

# Resource comparison

| Resource selected in AWS Backup | Practical backup model | Cross-Region copy supported |
|---|---|---|
| EBS | Snapshot-based recovery point | Yes |
| EC2 | EC2 recovery point protecting instance and attached EBS data | Yes |
| RDS DB instance | Snapshot and supported continuous/PITR protection | Yes, with service-specific rules |
| S3 | Periodic snapshot-style or continuous/PITR | Yes |

Feature availability can vary by resource and Region, so verify the current AWS Backup feature-availability matrix before using a production design.

---

# Prerequisites

- Access to the AWS Management Console.
- Permission to use:
  - AWS Backup
  - IAM
  - Amazon EC2
  - Amazon EBS
  - Amazon RDS
  - Amazon S3
  - AWS KMS where required
- At least one resource to protect.
- A primary AWS Region.
- A second AWS Region for the cross-Region exercise.
- S3 Versioning enabled if S3 backup will be performed.

Example:

```text
Primary Region:
ap-south-1

Recovery Region:
ap-south-2
```

These example Regions represent Mumbai and Hyderabad. Use Regions approved for your environment.

---

# Part 1 - Prepare sample resources

# Lab 1 - Identify resources to protect

Record available lab resources:

```text
EC2 instance ID:
EBS volume ID:
RDS DB identifier:
S3 bucket:
Primary Region:
Recovery Region:
```

You do not need all four resource types to complete the core lab.

---

# Lab 2 - Add backup tags

A scalable backup design often assigns backup policies using tags.

For the lab, add:

```text
Backup = Daily
Environment = Training
```

to resources that should be protected.

Possible resources:

```text
EC2
EBS
RDS
```

S3 resource assignment and supported tag-selection behavior should be verified in the current console before relying on tags for a production backup design.

---

# Lab 3 - Prepare S3 if required

If backing up S3:

1. Open **S3**.
2. Select or create a training bucket.
3. Open **Properties**.
4. Locate **Bucket Versioning**.
5. Enable versioning.

AWS Backup requires S3 Versioning for S3 backup.

Add a simple test object such as:

```text
backup-test.txt
```

with contents:

```text
Version 1
```

Upload it.

---

# Part 2 - Create backup vaults

# Lab 4 - Create the primary backup vault

Open:

```text
AWS Backup
   |
   v
Backup vaults
   |
   v
Create backup vault
```

Configure:

| Setting | Value |
|---|---|
| Backup vault name | `production-primary-vault` |
| Encryption | Approved/default KMS option for lab |

Choose:

```text
Create backup vault
```

---

# Lab 5 - Create the destination vault in the DR Region

Change the console Region to the chosen recovery Region.

Open:

```text
AWS Backup → Backup vaults
```

Create:

```text
production-dr-vault
```

Return to the primary Region after the vault has been created.

Conceptually:

```text
Primary Region                    DR Region
--------------                    ---------
production-primary-vault  --->   production-dr-vault
```

---

# Part 3 - Create the automated backup plan

# Lab 6 - Create a backup plan

Open:

```text
AWS Backup
   |
   v
Backup plans
   |
   v
Create backup plan
```

Choose:

```text
Build a new plan
```

Configure:

```text
Backup plan name:
production-daily-backup
```

---

# Lab 7 - Create the daily backup rule

Configure:

| Setting | Example |
|---|---|
| Backup rule name | `daily-backup` |
| Backup vault | `production-primary-vault` |
| Backup frequency | Daily |
| Backup window | Approved lab window |
| Lifecycle | Delete after 7 days |

The `7 days` value is a lab requirement, not a universal production recommendation.

Conceptually:

```text
Every day
    |
    v
AWS Backup
    |
    v
Recovery point
    |
    v
Keep 7 days
    |
    v
Expire according to lifecycle
```

---

# Lab 8 - Understand backup windows

A scheduled backup rule includes:

```text
Schedule
Start window
Completion window
```

Do not confuse:

```text
Backup frequency
```

with:

```text
How long AWS Backup is allowed to start or complete the job
```

For the lab, keep the default/approved backup windows unless the instructor wants them changed.

---

# Lab 9 - Add a cross-Region copy action

Inside the backup rule locate:

```text
Copy to destination
```

Choose the recovery Region.

Select:

```text
Destination vault:
production-dr-vault
```

Configure destination lifecycle according to the exercise.

Example:

```text
Primary recovery point retention = 7 days
DR copy retention               = 7 days
```

These values are training choices.

Conceptually:

```text
Resource
   |
   v
Primary backup
   |
   v
production-primary-vault
   |
   | Copy action
   v
production-dr-vault
```

AWS Backup supports cross-Region copying for many supported resource types, but exact feature support must be checked for the resource and Region.

---

# Lab 10 - Save the backup rule

Review:

```text
Rule name
Frequency
Backup vault
Retention
Cross-Region destination
Destination retention
```

Choose:

```text
Save backup rule
```

---

# Part 4 - Assign protected resources

# Lab 11 - Create resource assignment

Inside the backup plan choose:

```text
Assign resources
```

Example:

```text
Resource assignment name:
production-resources
```

Select the IAM role approved for AWS Backup.

If the AWS Backup default service role is already configured, use it according to the training-account policy.

---

# Lab 12 - Option A: assign resources explicitly

Select specific resource types and resource IDs.

For example:

```text
EC2
 |
 +-- i-xxxxxxxx

EBS
 |
 +-- vol-xxxxxxxx

RDS
 |
 +-- architecture-lab-mysql

S3
 |
 +-- training-backup-bucket
```

This works well when the resource set is small and fixed.

---

# Lab 13 - Option B: assign using tags

Instead of selecting every resource manually, use tag-based selection where supported.

Example:

```text
Backup = Daily
```

Conceptually:

```text
New resource
    |
    +-- tag Backup=Daily
              |
              v
       Backup assignment
              |
              v
        Protected resource
```

This is generally easier to operate at scale than maintaining a long static list.

Always validate that the intended resource types support the assignment method used by your plan.

---

# Part 5 - Protect EBS

# Lab 14 - Understand the EBS path

When the selected resource is:

```text
EBS volume
```

the recovery mechanism is snapshot-based.

```text
EBS Volume
    |
    v
AWS Backup
    |
    v
Recovery Point
    |
    v
Restore
    |
    v
New EBS Volume
```

---

# Lab 15 - Create an optional on-demand EBS backup

To observe the workflow immediately:

```text
AWS Backup
   |
   v
Protected resources / Create on-demand backup
```

Configure:

```text
Resource type:
EBS

Resource:
<volume-id>

Backup vault:
production-primary-vault

Backup:
Create now
```

Start the job.

---

# Part 6 - Protect an EC2 instance

# Lab 16 - Understand EC2 protection

If the requirement is:

> "Back up the server, not only one disk"

select:

```text
Resource type = EC2
```

rather than protecting only one EBS volume.

Conceptually:

```text
EC2
 |
 +-- Instance configuration
 +-- Root EBS
 +-- Data EBS
 |
 v
AWS Backup EC2 recovery point
```

---

# Lab 17 - Why this is not simply "take an AMI"

AWS Backup protects the EC2 resource through its managed recovery-point workflow.

When an EC2 recovery point is restored, AWS Backup can create:

```text
AMI
EC2 instance
Root volume
Data volumes
EBS snapshots
```

AWS Backup does **not** restore every possible external dependency of the application.

Examples that still need architecture-level recovery planning include:

```text
External database
DNS
Load balancer
Secrets
IAM dependencies
Application configuration outside the instance
Other network resources
```

---

# Lab 18 - Optional on-demand EC2 backup

Open:

```text
AWS Backup → Create on-demand backup
```

Choose:

```text
Resource type:
EC2

Instance:
<training-instance>

Backup vault:
production-primary-vault

Create backup now
```

Start the backup.

---

# Part 7 - Protect Amazon RDS

# Lab 19 - Understand RDS protection choices

AWS Backup supports RDS DB instances.

A scheduled rule can create periodic recovery points.

For supported RDS configurations, AWS Backup can also provide continuous backup / point-in-time recovery.

Think:

```text
RDS
 |
 +---- Periodic backup
 |        |
 |        v
 |     Snapshot-style recovery point
 |
 +---- Continuous backup
          |
          v
       PITR window
```

---

# Lab 20 - Protect the RDS database

In the resource assignment, include:

```text
Resource type:
RDS
```

Select:

```text
architecture-lab-mysql
```

or the lab DB identifier.

The same backup plan can centrally manage the RDS protection schedule.

---

# Lab 21 - Optional continuous RDS backup

If the training account and selected RDS resource support it, create a separate rule or configure an appropriate rule with:

```text
Enable continuous backups
```

Continuous backup enables point-in-time restore for supported resources.

Do not create multiple unnecessary continuous-backup rules for the same resource.

---

# Lab 22 - Cross-Region RDS consideration

When a continuous backup is copied across Regions, the destination copy is not itself a continuous PITR recovery point.

Conceptually:

```text
Primary Region
RDS continuous backup
        |
        | Cross-Region copy
        v
DR Region
Snapshot-style copy
```

The copied recovery point is useful for regional recovery but does not preserve continuous PITR behavior.

---

# Part 8 - Protect Amazon S3

# Lab 23 - Understand S3 backup choices

AWS Backup offers two useful S3 protection models.

## Periodic backup

```text
S3
 |
 v
Scheduled backup
 |
 v
Point-in-time snapshot-style recovery point
```

Use when you want scheduled retained recovery points.

---

## Continuous backup

```text
S3
 |
 v
Continuous change tracking
 |
 v
PITR
```

AWS Backup can provide S3 point-in-time recovery from continuous backups within the supported retention window.

S3 Versioning must be enabled.

---

# Lab 24 - Add the S3 bucket to protection

Add:

```text
Resource type:
S3
```

Select:

```text
<training-bucket>
```

Confirm that S3 Versioning is enabled before relying on AWS Backup for S3.

---

# Lab 25 - Optional continuous S3 backup

Configure:

```text
Enable continuous backups
```

for the S3 rule where supported and intended.

AWS Backup for S3 depends on S3 events delivered through Amazon EventBridge for continuous protection.

Do not disable the required EventBridge integration when using continuous S3 backup.

---

# Lab 26 - Cross-Region S3 behavior

AWS Backup supports cross-Region copy for S3.

However:

```text
Continuous source backup
          |
          | Copy
          v
Destination copy
          |
          v
Snapshot-style recovery point
```

The copied backup does not retain PITR capability.

---

# Part 9 - Monitor jobs

# Lab 27 - Monitor scheduled or on-demand backups

Open:

```text
AWS Backup
   |
   v
Jobs
   |
   v
Backup jobs
```

Inspect:

```text
Resource
Resource type
Status
Creation time
Backup vault
Recovery point
Status message
```

Wait for:

```text
Completed
```

before treating a recovery point as successfully created.

---

# Lab 28 - Monitor cross-Region copy jobs

Open:

```text
AWS Backup
   |
   v
Jobs
   |
   v
Copy jobs
```

Inspect:

```text
Source Region
Destination Region
Source recovery point
Destination vault
Status
```

Wait for:

```text
Completed
```

---

# Lab 29 - Verify the primary recovery point

Open:

```text
AWS Backup
   |
   v
Backup vaults
   |
   v
production-primary-vault
```

Locate recovery points for the protected resources.

Record:

```text
Resource type:
Resource ID:
Recovery point:
Creation time:
Status:
Expiry:
```

---

# Lab 30 - Verify the DR copy

Change to the recovery Region.

Open:

```text
AWS Backup
   |
   v
Backup vaults
   |
   v
production-dr-vault
```

Confirm that the copied recovery point appears.

Record:

```text
Source resource:
Destination recovery point:
Creation time:
Status:
Expiry:
```

This validates the copy workflow.

It does **not** yet prove that the application can be recovered.

---

# Part 10 - Review restore workflows

# Lab 31 - EBS restore

Select an EBS recovery point.

Choose:

```text
Restore
```

Conceptually:

```text
Original EBS
    |
    v
Recovery point
    |
    v
Restore
    |
    v
New EBS volume
```

The restored volume is a new resource rather than an overwrite of the original volume.

---

# Lab 32 - EC2 restore

Select an EC2 recovery point.

Choose:

```text
Restore
```

Review the settings.

AWS Backup can restore the EC2 instance and associated EBS resources from the recovery point.

Conceptually:

```text
EC2 recovery point
       |
       v
      AMI
       |
       +--> EC2 instance
       +--> Root volume
       +--> Data volumes
       +--> EBS snapshots
```

---

# Lab 33 - RDS restore

Select the RDS recovery point.

Choose:

```text
Restore
```

AWS Backup restores to a database resource according to the supported RDS restore workflow.

Do not assume the restore overwrites the original production database.

Review all restored DB settings before connecting an application.

---

# Lab 34 - S3 restore

Select the S3 recovery point.

Choose:

```text
Restore
```

Depending on the recovery-point type, review the available destination and restore options.

For continuous backups, select the required restore point in time where supported.

Validate restored objects after the restore completes.

---

# Part 11 - Validate recovery rather than only backup

A successful backup means:

```text
Recovery point exists
```

It does not automatically prove:

```text
Restore works
Application starts
Data is correct
Dependencies are available
RTO is met
```

A mature test is:

```text
Backup
   |
   v
Recovery point
   |
   v
Restore
   |
   v
Data validation
   |
   v
Application validation
   |
   v
Measure recovery duration
```

---

# Part 12 - Example policy for 10 production EC2 instances

Requirement:

```text
5 EC2 instances in Mumbai
5 EC2 instances in another Region
Daily backup
Keep 7 days
Maintain DR copy where required
```

A scalable design can use:

```text
Backup = Daily
Environment = Production
```

tags.

Then:

```text
Production EC2
     |
     v
Tag-based backup assignment
     |
     v
Daily backup rule
     |
     +---- Primary vault: retain 7 days
     |
     +---- Cross-Region vault: retain according to DR policy
```

Because AWS Backup is regional in operation, configure and verify protection for resources in each source Region.

---

# Part 13 - Snapshot vs AMI vs AWS Backup

A common beginner confusion is:

> Should I take a snapshot, an AMI, or use AWS Backup?

Use this mental model:

```text
EBS Snapshot
------------
Protects an EBS volume.
```

```text
AMI
---
Machine image used to launch EC2 instances.
```

```text
AWS Backup
----------
Central policy/orchestration service that protects supported
AWS resources and manages recovery points, schedules,
retention and supported copies.
```

For EC2:

```text
AWS Backup EC2 recovery point
           |
           v
        Restore
           |
           +-- AMI
           +-- EC2
           +-- EBS volumes
           +-- EBS snapshots
```

So AWS Backup is not simply a fourth disk-backup format.

---

# Part 14 - Suggested production policy discussion

Before creating a real backup policy, answer:

```text
What is the application's RPO?

What is its RTO?

How often should backups run?

How long should backups be retained?

Should recovery points be copied to another Region?

Should backups also be copied to another AWS account?

Should the destination vault use a different KMS key?

Do we need continuous PITR or only periodic backups?

How often will restore testing run?

Who can delete recovery points?

Do we require immutability / vault controls?
```

Do not choose retention and cross-Region design only because they are easy to configure.

---