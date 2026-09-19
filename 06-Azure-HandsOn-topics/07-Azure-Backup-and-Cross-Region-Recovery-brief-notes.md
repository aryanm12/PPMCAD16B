# 07 - Azure Backup and Regional Recovery: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values. Supplied guest scripts run through the VM’s portal Run command page to install or test software inside the VM.

**Read before:** [Lab 07 - Backup and cross-region recovery](07-Azure-Backup-and-Cross-Region-Recovery.md)  
**Reading time:** 6–8 minutes. Review [foundation notes](01-Lab-Preparation-and-Cost-Controls-brief-notes.md) for Region and lifecycle basics.

## What you will prove

A policy and a completed backup job show that protection is configured and a recovery copy exists. A restored VM containing the correct file proves more. A second-region restore additionally tests whether the copied data and regional infrastructure can support recovery.

```text
VM + known file → backup policy/job → recovery point
                                  → new VM → check file/hash
                                  → secondary-region copy → new regional VM → check again
```

## Vocabulary before creating a vault

| Term | Meaning |
|---|---|
| Recovery Services vault | The Azure resource used here to organize VM backup protection and recovery data |
| Backup vault | A different Azure vault type used by other supported backup workloads; not an interchangeable name |
| Backup policy | Schedule and retention instructions |
| Protected item | The resource registered for protection, here the source VM |
| Backup job | One attempt to create a backup |
| Recovery point | A particular recoverable state/time |
| Restore job | Work that reconstructs resources from a recovery point |
| Retention | The period during which recovery data is kept |
| Staging storage | Temporary/intermediate storage used by some restore workflows |

The vault is not a VM disk you attach manually. Its settings and retained items can outlive the source VM. MySQL Flexible Server's native backups are also not automatically managed by this VM policy.

## Primary, secondary and redundancy

The **primary Region** runs the source. A **secondary Region** is used for regional recovery. **GRS**, geo-redundant storage, replicates the relevant backup storage to a secondary Region. **Cross Region Restore (CRR)** enables supported restore operations there without simply treating all backup services as freely copyable to any Region.

This lab follows the vault's supported paired-region behavior. Not every Azure Region/service has the same pairing/capability. Replication is asynchronous: a just-created primary recovery point may not yet be usable in the secondary Region. Initial secondary availability can take up to 48 hours, which is why the guide plans two sessions. See [vault configuration](https://learn.microsoft.com/en-us/azure/backup/backup-create-recovery-services-vault).

## RPO and RTO in everyday language

**Recovery Point Objective (RPO)**: how much recent data the business can afford to lose. **Recovery Time Objective (RTO)**: how long restoration of the required service may take.

If failure occurs at 10:00 and the latest usable backup is from 09:00, the recovery data may be an hour old. If a VM is restored by 10:30 but DNS, credentials or the database are still missing, the application may not yet be recovered. Measure service readiness, not just the restore-job status.

## Why the lab checks actual files

You record a Version 1 hash, change the source to Version 2, and restore the earlier point into a new VM. Correct recovery returns Version 1 while the source can still contain Version 2. This prevents accidentally mistaking the current source for the restored result.

Backup consistency also matters: a static file is simpler than a running transactional application. **Application-consistent** recovery needs the appropriate application-aware protection and validation.

## Cleanup is part of the lifecycle

**Soft delete** retains deleted backup items for recovery. **Immutability** restricts changes/deletion according to configured protections. Deleting a source VM does not necessarily erase its backups, and retained items can prevent immediate vault/group deletion.

Record both “compute removed” and “backup retention pending” when applicable. Do not turn off organization protection merely to make a lab checklist show an empty resource group.

## AWS connection

AWS Backup vaults/policies are a useful responsibility-level comparison, but Azure's Recovery Services vault, Backup vault, workload support and regional-copy behavior differ. Azure Site Recovery is a separate replication/disaster-recovery service; it is not another name for this backup exercise.

## Check your understanding

1. Does an on-demand backup prove tomorrow's schedule ran?
2. Does enabling CRR prove the application recovered in another Region?
3. Why might cleanup remain pending after deleting the VM?

**Answers:** (1) No; inspect the separate scheduled job. (2) No; restore and validate there. (3) Retention/soft-deleted backup items can remain.

**Ready for the lab:** You can distinguish policy, job, recovery point and verified service recovery.

Further reading: [VM restore options](https://learn.microsoft.com/en-us/azure/backup/backup-azure-arm-restore-vms), [backup soft delete](https://learn.microsoft.com/en-us/azure/backup/backup-azure-security-feature-cloud).
