# Hands-On Lab - AWS Migration Planning

## Lab outcome

Assess a small application portfolio, select migration strategies and AWS services, create migration waves, and prepare a cutover and rollback plan.

This lab plans a migration. It does not install replication agents or migrate a live production server.

## Sample application portfolio

| Application | Components | Dependencies | Criticality | Current concern |
|---|---|---|---|---|
| Internal wiki | Web VM and MySQL database | Corporate identity | Low | Old operating system |
| Order API | Four application VMs and Oracle database | Payment, inventory and DNS | High | Capacity and licensing |
| Reporting | Two VMs and a file share | Order database | Medium | Large nightly transfer |
| Legacy archive | One old VM | None | Low | Rarely accessed |

## Lab 1 - Build the discovery checklist

For each application, identify the missing information required before migration:

- CPU, memory, storage and network utilization.
- Operating system and database versions.
- Inbound and outbound connections.
- DNS names, ports and certificates.
- Authentication and secrets.
- Data size and daily change rate.
- Backup method, RPO and RTO.
- Licence restrictions.
- Business owner and maintenance window.
- Data classification and location requirements.

Add at least five discovery questions to the sample portfolio.

## Lab 2 - Select a migration strategy

Assign one of the 7 Rs to each application:

```text
Retire
Retain
Rehost
Relocate
Replatform
Repurchase
Refactor
```
| Reporting | Two VMs and a file share | Order database | Medium | Large nightly transfer |

Complete:

| Application | Selected strategy | Reason | Main risk |
|---|---|---|---|
| Internal wiki | Rehost + Replatform | VMs can be rehosted and Database ideally should run on AWS RDS service | NA |
| Order API | Refactor + Replatform | Order API should be refactored into microservices along with its other dependent services and database should be first migrated into postgresql using schema converter and then hosted into RDS | |
| Reporting | Rehost + Replatform | | |
| Legacy archive | | | |

Do not select `Rehost` for every application. Use business value, risk, time and technical constraints.

## Lab 3 - Select AWS migration services

Map each component to an appropriate current AWS capability.

| Component | AWS option |
|---|---|
| Physical, virtual or cloud server | AWS Transform MGN |
| Relational database | AWS Database Migration Service |
| Online file or object transfer | AWS DataSync |
| Very large offline dataset | AWS Snow Family where suitable |
| Assessment, planning and modernization workflow | AWS Transform |

Complete:

| Application component | Selected AWS service | Why it fits |
|---|---|---|
| Wiki web VM | | |
| Wiki database | | |
| Order application VMs | | |
| Order database | | |
| Reporting file share | | |

## Lab 4 - Inspect AWS Transform and MGN

1. Open **AWS Transform** in the AWS Console.
2. Identify where an assessment or migration workspace is created.
3. Open **AWS Transform MGN**.
4. Locate:
   - Source servers
   - Applications
   - Waves
   - Replication settings
   - Launch settings
   - Test and cutover actions
5. Record which steps require software or a connector in the source environment.

AWS Server Migration Service is legacy material. Use AWS Transform MGN for the current server rehosting workflow.

## Lab 5 - Create migration waves

Create two or three waves. A pilot should be low risk but still prove the process.

| Wave | Applications | Entry criteria | Success criteria |
|---|---|---|---|
| Pilot | | | |
| Wave 1 | | | |
| Wave 2 | | | |

Check that:

- Shared databases move with or before dependent applications.
- Connected applications are not split without a tested temporary integration.
- The pilot validates networking, IAM, monitoring, backup and support.
- High-criticality systems benefit from lessons learned in earlier waves.

## Lab 6 - Verify target readiness

Mark each item **Ready**, **Not ready** or **Not applicable**.

| Item | Status | Owner/action |
|---|---|---|
| AWS accounts and controls | | |
| VPC and non-overlapping CIDR | | |
| Hybrid routes and firewall rules | | |
| DNS resolution | | |
| IAM roles | | |
| Encryption keys and secrets | | |
| Logs, metrics and alarms | | |
| Backup and recovery | | |
| Service quotas | | |
| Target licences | | |

## Lab 7 - Write the cutover runbook

Choose one application and complete the runbook.

| Step | Owner | Evidence of completion |
|---|---|---|
| Go/no-go approval | | |
| User notification and change freeze | | |
| Final synchronization | | |
| Target launch | | |
| DNS or routing change | | |
| Technical smoke test | | |
| Business transaction test | | |
| Monitoring review | | |
| Success or rollback decision | | |
| Source retention/decommission decision | | |

## Lab 8 - Define rollback

Complete before the cutover is approved:

```text
Rollback trigger:
Latest safe rollback time:
Who decides:
How traffic returns to the source:
How target-side writes are handled:
How users are notified:
How the failed migration is investigated:
```

Turning the old server back on is not sufficient when the target database has accepted new writes.

## Lab 9 - Define validation

### Technical validation

- Required ports and dependencies are reachable.
- Services start automatically after restart.
- Logs, metrics and alarms are visible.
- Backup completes and the restore procedure is known.
- Performance and error rate meet the agreed threshold.
- Security checks pass.

### Business validation

- Users can authenticate.
- A representative transaction completes.
- Reports and integrations receive correct data.
- Data totals and critical records reconcile.
- The application owner signs off.

## Final deliverables

- Completed portfolio assessment.
- One 7-R decision per application.
- AWS service mapping.
- Migration wave plan.
- Target-readiness checklist.
- Cutover runbook.
- Rollback trigger and validation checklist.