# Azure Architecture - Independent Hands-On Learning Path

This collection maps the **16 AWS architecture guides in `05-AWS-Arch`** to Azure scenarios. It includes executable exercises, design work and migration practice. Each guide gives its own setup; resource groups are isolated so you can clean up one exercise without breaking another.

## Start here

Read [01 - Azure foundations: brief notes](01-Lab-Preparation-and-Cost-Controls-brief-notes.md) before creating your first resource. Then complete lab 01. For every later topic, read its matching **brief notes** before the hands-on guide. The notes explain terms, relate them to familiar AWS concepts, describe why the steps matter, and include self-check questions with answers. Each hands-on guide states its own setup requirements. Use a learning subscription with permission to create the resources described. An administrator is needed only if your organization's policy blocks the required permissions or services; the exercises do not require a trainer.

**Portal-first:** Create, configure, inspect and delete Azure resources in the [Azure portal](https://portal.azure.com). No Azure CLI setup or commands are required. Follow each guide's click paths and field values; keep your chosen resource names in a worksheet.

Linux scripts remain only for guest software, diagnostics and controlled failures, using the specified VM **Run command** page or SSH session. SQL and database tools remain where the exercise needs real data operations. Do not paste these scripts into arbitrary portal fields or Windows PowerShell. Labs **04 and 15** use Visual Studio Code's graphical Azure Functions extension to publish Python application code, with full setup instructions; the resource administration and tests remain portal-based. Replace uppercase placeholders before using code.

## Guides and AWS coverage

| Hands-on guide | Read first: brief notes | Practical outcome | AWS guide counterpart |
|---|---|---|---|
| [01 - Preparation and cost controls](01-Lab-Preparation-and-Cost-Controls.md) | [Concept notes](01-Lab-Preparation-and-Cost-Controls-brief-notes.md) | Subscription selection, RBAC, budget, tagging and deletion | Additional 01 |
| [02 - Application Gateway and two web VMs](02-Application-Gateway-and-Web-Architecture.md) | [Concept notes](02-Application-Gateway-and-Web-Architecture-brief-notes.md) | Network, health probes and failure routing | Session 1 basic architecture |
| [03 - Private application and database tiers](03-Secure-Three-Tier-Architecture.md) | [Concept notes](03-Secure-Three-Tier-Architecture-brief-notes.md) | Public gateway, private VMs/MySQL, working DB-backed page | Session 1 production-grade architecture |
| [04 - Functions, API Management and releases](04-Functions-API-Management-and-Deployment.md) | [Concept notes](04-Functions-API-Management-and-Deployment-brief-notes.md) | HTTP API, logs, staging, canary policy and rollback | Session 2 API Gateway/Lambda |
| [05 - MySQL Flexible Server fundamentals](05-MySQL-Flexible-Server-and-High-Availability.md) | [Concept notes](05-MySQL-Flexible-Server-and-High-Availability-brief-notes.md) | SQL data, restricted access, HA choices | Session 3 RDS Single-AZ/Multi-AZ |
| [06 - Optimization and disk recovery](06-Cost-Optimization-and-Disk-Recovery.md) | [Concept notes](06-Cost-Optimization-and-Disk-Recovery-brief-notes.md) | Cost analysis, Advisor, data-bearing disk snapshot/restore | Session 3 optimization/recovery |
| [07 - Scheduled backup and regional recovery](07-Azure-Backup-and-Cross-Region-Recovery.md) | [Concept notes](07-Azure-Backup-and-Cross-Region-Recovery-brief-notes.md) | VM backup policy, recovery points, restored data | Session 3 automated/cross-Region backup |
| [08 - Front Door and Storage](08-Front-Door-and-Storage-Static-Website.md) | [Concept notes](08-Front-Door-and-Storage-Static-Website-brief-notes.md) | HTTPS static site, private origin, cache refresh | Session 4 CloudFront/S3 |
| [09 - Architecture design workshop](09-Architecture-Design-Workshop.md) | [Concept notes](09-Architecture-Design-Workshop-brief-notes.md) | Requirements, decisions, failure analysis, reference solution | Session 4 architecture design |
| [10 - Migration planning and execution](10-Migration-Planning-and-MySQL-Migration.md) | [Concept notes](10-Migration-Planning-and-MySQL-Migration-brief-notes.md) | Portfolio/waves plus a real sample database migration | Session 5 migration |
| [11 - Managed identity and RBAC](11-Managed-Identity-RBAC-and-VM-Operations.md) | [Concept notes](11-Managed-Identity-RBAC-and-VM-Operations-brief-notes.md) | VM identity, scoped blob reads and denied writes | Additional 02 |
| [12 - VM Scale Sets](12-VM-Scale-Sets-Autoscaling-and-Repair.md) | [Concept notes](12-VM-Scale-Sets-Autoscaling-and-Repair-brief-notes.md) | Load balancing, scaling and automatic application repair | Additional 03 |
| [13 - Private endpoints and DNS](13-Private-Endpoints-DNS-and-Troubleshooting.md) | [Concept notes](13-Private-Endpoints-DNS-and-Troubleshooting-brief-notes.md) | Private blob access and DNS/firewall diagnosis | Additional 04 |
| [14 - Key Vault application integration](14-Key-Vault-Application-Integration.md) | [Concept notes](14-Key-Vault-Application-Integration-brief-notes.md) | Managed identity reads a secret; permission failure/recovery | Additional 05 |
| [15 - Service Bus and Functions](15-Service-Bus-Functions-and-Dead-Letter-Recovery.md) | [Concept notes](15-Service-Bus-Functions-and-Dead-Letter-Recovery-brief-notes.md) | Queue processing, duplicate protection, DLQ/replay | Additional 06 |
| [16 - MySQL failover and PITR](16-MySQL-Failover-and-Point-in-Time-Recovery.md) | [Concept notes](16-MySQL-Failover-and-Point-in-Time-Recovery-brief-notes.md) | Forced failover and recovery of deleted records | Additional 07 |

Suggested sequence: **01 → 11 → 02 → 05 → 14 → 03 → 12 → 13 → 04 → 15 → 06 → 07 → 16 → 08 → 09 → 10**. Advanced guides repeat setup intentionally so previously deleted resources are not prerequisites.

## Important Azure distinctions

- A **tenant** contains identities; a **subscription** is a resource/billing boundary; a **resource group** groups resources for lifecycle management. A resource group's location does not force all its resources into that location.
- Azure **RBAC management-plane permissions** and service **data-plane roles** are different. Contributor does not automatically grant blob/secret data access or permission to assign roles.
- A managed identity obtains temporary tokens. It does not automatically have permission to access another service.
- A VNet subnet is not made public by attaching an AWS-style Internet Gateway. These labs explicitly configure public IPs or NAT Gateway for outbound connectivity where needed.
- Availability zones, load balancing, backups and disaster recovery solve different failure cases.
- Azure Backup uses different vaults/features for different workloads. MySQL Flexible Server's native backups are not an Azure VM backup policy. An S3-style cross-region copy option does not exist uniformly across all Azure storage/backup services.

## Cost and cleanup discipline

Read the cost section before each lab. Application Gateway, Front Door Premium, Functions Premium, NAT Gateway, Bastion, Service Bus Standard, backup storage and HA databases can incur charges while idle. No guide promises Free Tier coverage.

Set a spending notification in guide 01. A budget is not a hard cap. Delete completed lab resource groups, then verify deletion. Backup soft-delete retention and Key Vault recovery protection can leave retained items after normal cleanup; the relevant guides explain these explicitly. Do not weaken organization-wide protection to finish a lab.

## Evidence of competence

For each guide keep a worksheet with resource IDs, successful validation output, the deliberate failure symptom, root cause, recovery evidence and cleanup result. Do not save keys/passwords in that worksheet.

After completing the set, use guide 09's rubric to explain and defend a design, and guide 10's runbook to execute a controlled cutover. Completing instructions is a starting point: repeat selected failure exercises without looking at the recovery steps to build independent operational confidence.

## Validation boundary

These notes were authored against Microsoft Learn documentation. Embedded examples are intended for the stated SKUs and tools; regional availability, permissions and portal labels can differ. They have not been executed in a live Azure subscription as part of authoring. Each guide contains checkpoints so learners verify actual results before proceeding.

Portal conversion checks: all 16 hands-on guides and 16 companion notes reviewed; no Azure CLI command examples remain. Internal links and embedded Bash/Python/JSON/XML syntax were checked locally. These checks do not replace executing the labs in a learning subscription.
