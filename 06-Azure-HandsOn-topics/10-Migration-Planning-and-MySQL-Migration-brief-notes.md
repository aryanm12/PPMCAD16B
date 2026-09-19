# 10 - Migration Planning and Execution: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values. The database client runs through the documented SSH session because SQL, dump/import and data-validation operations execute against MySQL, not in a resource-creation form.

**Read before:** [Lab 10 - Migration planning and MySQL migration](10-Migration-Planning-and-MySQL-Migration.md)  
**Reading time:** 6–8 minutes. Review [database notes](05-MySQL-Flexible-Server-and-High-Availability-brief-notes.md) for SQL/client terminology.

## What is actually being migrated?

The lab moves a small database from a self-managed MySQL server on a VM to managed MySQL Flexible Server. The source VM is already in Azure, but stands in for an existing self-managed/on-premises workload. This isolates database migration mechanics without requiring an external datacenter.

It does not replicate an entire server through Azure Migrate, and it does not demonstrate a no-downtime database migration.

## Planning vocabulary

| Term | Meaning |
|---|---|
| Portfolio | The collection of applications under consideration |
| Discovery | Finding the existing components, versions, dependencies and usage |
| Assessment | Evaluating readiness, compatibility, sizing, cost and risk |
| Dependency | Something another component needs, such as identity, DNS or a database |
| Pilot | A small migration used to prove the process before more critical work |
| Wave | A planned group of migrations executed together/in sequence |
| Cutover | Move clients/writers to the new target |
| Rollback | Return to an earlier working arrangement under defined conditions |
| Reconciliation | Compare source/target results and resolve differences |
| Decommission | Retire the old resources after acceptance and retention requirements are met |

Migration strategies such as **rehost**, **replatform**, **refactor**, **retain** and **retire** are choices based on the workload. Replatforming a database changes its operational platform without automatically rewriting the whole application. Refactoring usually changes application design and carries additional scope.

## Data-move vocabulary

**Source** holds the original data; **target** receives it. A **logical dump** represents database structure/data as SQL rather than copying raw disk blocks. An **import** executes that SQL to reconstruct the data. **Schema** describes objects such as tables, columns and constraints.

**Offline migration** includes a write-stop window. **CDC**, change data capture, tracks ongoing changes for supported online migration workflows. Even an online approach needs carefully planned final synchronization and cutover; it is not automatically zero-risk.

MySQL's **binlog** records relevant database changes for replication/recovery workflows. **GTID** identifies transactions in MySQL replication. The lab turns off GTID statements in its simple dump because it is importing application data, not transferring the source server's replication identity. Do not reuse those flags blindly for every production migration.

## Understand the runbook's order

```text
Assess compatibility → prepare target → freeze source writes → dump/import
→ reconcile → switch client → validate → retain or retire source
```

The source is made **read-only** so the dataset stops changing during the exercise. If users could continue writing after the dump, the target could already be behind before cutover.

`--single-transaction` supports a consistent dump of the transactional InnoDB data used here. It is not a blanket guarantee for every storage engine or concurrent schema change. The lab uses a tiny, deliberately uncomplicated schema.

## Why “import succeeded” is not the finish line

The lab compares ordered rows, row count, total amount and file hashes of the query output. These checks catch missing or different records. Real projects must also validate users/permissions, routines, integrations, performance and business behavior.

A **smoke test** is a quick basic operation proving the new path works. It is not a full performance or business acceptance test. Querying the target proves the test client can use it; it does not update a real application's DNS automatically.

## Rollback changes after target writes begin

Before target writes, returning a read-only client to the unchanged source is straightforward. After new target writes, the old source may be stale. “Switch back” can then lose accepted changes or split the system into conflicting histories. Define write handling and reconciliation before approving a real cutover.

## AWS comparison

Azure Migrate covers discovery/assessment and supported migration workflows; native MySQL tools or supported Azure database migration capabilities move database data. These responsibilities overlap with AWS migration tools, but no single Azure button is an exact substitute for every MGN/DMS scenario. This lab intentionally teaches native offline dump/restore.

## Check your understanding

1. Why stop source writes before the final dump in this exercise?
2. Is a target containing the correct number of rows necessarily identical?
3. When does returning to the original server become more complicated?

**Answers:** (1) Prevent the source moving beyond the exported state. (2) No; compare values too. (3) Once the target accepts new writes that the source lacks.

**Ready for the lab:** You can explain the source, target, freeze, validation gate and safe rollback boundary.

Further reading: [Azure Migrate overview](https://learn.microsoft.com/en-us/azure/migrate/migrate-services-overview), [MySQL dump/restore](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concepts-migrate-dump-restore).
