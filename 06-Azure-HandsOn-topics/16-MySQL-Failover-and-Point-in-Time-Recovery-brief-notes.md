# 16 - MySQL Failover and Point-in-Time Recovery: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values. The database client runs through the documented SSH session because SQL, dump/import and data-validation operations execute against MySQL, not in a resource-creation form.

**Read before:** [Lab 16 - MySQL failover and PITR](16-MySQL-Failover-and-Point-in-Time-Recovery.md)  
**Reading time:** 5–7 minutes. Review [MySQL fundamentals](05-MySQL-Flexible-Server-and-High-Availability-brief-notes.md) before this recovery exercise.

## Two different failures, two different responses

If the primary database's infrastructure fails, a healthy standby may take over. If an application commits a wrong DELETE, that data change can be faithfully replicated to the standby. A standby is not a time machine.

The lab therefore demonstrates **failover** first, then **historical recovery** separately.

## Terms before beginning

| Term | Meaning |
|---|---|
| Primary | The active database role handling the workload |
| Standby | A maintained alternate used for supported HA failover |
| Replication | Keeping data changes synchronized according to the service's replication design |
| Zone-redundant HA | Primary/standby infrastructure separated across zones |
| Forced failover | A deliberate lab action causing a role transition to test behavior |
| Commit | Make a database transaction's changes durable under its guarantees |
| PITR | Point-in-time recovery: reconstruct database state at a selected historical time |
| Restore target | The timestamp you want the recovered database to represent |
| Recovery window | The supported time range from which the service can restore |
| UTC | A standard time reference avoiding ambiguity between local timezones |

The client should keep using the service hostname rather than pinning an IP. Existing connections can fail during a role transition; applications need appropriate reconnect/retry behavior.

## The failover test checks availability behavior

The watch program repeatedly opens a connection and reads known rows. You record successful reads, failures, recovery, and the service's failover events/role changes. Sampling every few seconds cannot measure an exact interruption smaller than the sample interval. A missed failed sample is not evidence to invent an outage duration.

After failover, the three records should still exist. This checks resilience to that tested transition; it is not a guarantee against every failure mode or an application-wide availability certification.

## The restore test checks historical data

```text
Seed and commit three rows
       ↓
Choose valid restore time AFTER commit
       ↓
Wait, then DELETE and commit
       ↓
Restore selected earlier time into NEW server
       ↓
Compare exact restored rows with recorded originals
```

The target must be clearly **after the correct data existed** and **before deletion**. Selecting “latest” after the deletion can restore the empty table successfully—and still fail your recovery objective.

Configured retention does not mean the initial backup/recovery window is already ready. Verify the target is supported before performing the destructive lab step. The restore does not overwrite the source; it produces another billable server with its own hostname. See [MySQL restore behavior](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concepts-backup-restore).

## Data validation is stronger than server status

**Ready** means the managed resource is available for use. It does not mean you chose the right historical time. Validate IDs, customer names, amounts, row count and total. In this exercise the correct result is three original rows totaling 600; the damaged source should still be empty.

Also inspect restored networking and HA settings. A restored MySQL Flexible Server is not automatically restored with HA enabled. A real replacement needs its availability, monitoring and access requirements rechecked.

## Recovery objectives and cutover

**RPO** is the acceptable data-loss window; **RTO** is the acceptable service-restoration time. Record restore-start, server-ready and data-validation times. The last is more meaningful than provisioning completion alone, though a full application's recovery can involve still more dependencies.

Changing the test client's hostname rehearses **cutover**. It does not update all clients or DNS. If legitimate writes happened after the restore target, reconcile them before a real switch. Running source and restored systems as independent writers can create conflicting histories.

## AWS comparison

The conceptual distinction matches RDS Multi-AZ versus PITR: HA handles supported infrastructure disruption; historical restore recovers earlier data into another resource. Azure's HA tiers, restoration defaults, DNS/network configuration and timing must be verified on their own terms.

## Check your understanding

1. Should failover restore rows removed by a committed DELETE?
2. Which restore timestamp is appropriate: before the insert, between insert and delete, or after delete?
3. Is a restored server automatically ready for production because its data matches?

**Answers:** (1) No. (2) Between the committed insert and deletion, inside the valid recovery window. (3) No; verify access, HA, monitoring, dependencies and any newer writes.

**Ready for the lab:** You can identify a safe recovery target before deletion and explain what evidence will prove success afterward.

Further reading: [Configure MySQL HA](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/how-to-configure-high-availability), [portal PITR](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/how-to-restore-server-portal).
