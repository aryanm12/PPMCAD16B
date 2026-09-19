# 06 - Cost Optimization and Disk Recovery: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values. Supplied guest scripts run through the VM’s portal Run command page to install or test software inside the VM.

**Read before:** [Lab 06 - Cost optimization and disk recovery](06-Cost-Optimization-and-Disk-Recovery.md)  
**Reading time:** 5–7 minutes. Review [foundation notes](01-Lab-Preparation-and-Cost-Controls-brief-notes.md) for budgets and resource groups.

## Two questions this lab answers

“What am I paying for, and is it justified?” is an optimization question. “Can I recover the earlier contents?” is a recovery question. The exercise connects both to observable evidence rather than assuming that a small resource or a successful snapshot job is enough.

## Cost vocabulary

| Term | Meaning |
|---|---|
| Cost analysis | A view of recorded spend by dimensions such as service or resource group |
| Azure Advisor | Recommendations based on supported configuration/usage analysis |
| Utilization | How much of a resource's capacity the workload actually uses |
| Right-sizing | Choosing capacity that meets demand without unnecessary excess |
| Deallocate | Release a VM's allocated compute; disks and other resources can remain |
| Retention | How long a resource or recovery copy is kept |

A recommendation is an input to a decision, not permission to resize a shared server. Low average CPU can hide a short daily peak. A new training subscription may not have enough history for useful recommendations. A budget alerts; it does not cap spend.

## Disk vocabulary before you run Linux commands

| Term | Meaning in the exercise |
|---|---|
| OS disk | Contains the operating system; never format this as the lab data disk |
| Data disk | An additional persistent disk holding the test file |
| Temporary/resource disk | VM-local temporary storage; do not confuse it with the managed data disk |
| LUN | Logical Unit Number: the attachment slot used to identify the intended disk |
| Filesystem | The structure organizing files on a disk, here ext4 |
| Format / `mkfs` | Create a filesystem; overwrites existing filesystem structures |
| Mount | Make an existing filesystem accessible at a directory |
| Unmount | Disconnect that filesystem from the directory after writes are flushed |
| Snapshot | A point-in-time disk recovery copy |

`lsblk` inspects block devices; it does not format them. `/dev/disk/azure/scsi1/lun0` identifies the Azure attachment used by the guide. Raw names such as `/dev/sdb` can differ between VMs; never guess from an example name.

## Understand the sequence

```text
New empty disk → format → mount → write Version 1 → unmount → snapshot
Original disk → write Version 2
Snapshot → NEW disk → mount read-only → verify Version 1
```

The restored disk already has a filesystem. Formatting it would destroy the data you are trying to recover. The lab unmounts before taking the snapshot so the simple filesystem is in a clean state. A busy database requires an appropriate application-consistency strategy beyond this small file exercise.

An **incremental snapshot** stores changes efficiently relative to earlier state. You still select a recovery point, not manually assemble changed blocks. Restoring creates a new disk; it does not silently rewind the original.

## Why compare a hash?

A **SHA-256 hash** is a fingerprint of file bytes. If the restored file has the recorded pre-change hash, that strongly supports byte-for-byte recovery of this file. A matching filename or disk size would be weaker evidence. This one-file test does not prove a whole application can restart with every dependency.

## AWS connection

Managed data disks and snapshots serve roles familiar from EBS and EBS snapshots. Cost analysis/Advisor cover parts of the responsibilities you saw in Cost Explorer, Compute Optimizer and Trusted Advisor. Azure Disk Backup, manual snapshots and VM backup are different workflows; this lab specifically uses a manual disk snapshot, while guide 07 adds scheduled VM protection.

## Check your understanding

1. Should you run `mkfs` on the restored disk to make it readable?
2. Does stopping compute necessarily remove disk/snapshot charges?
3. Why record the hash before changing the original file?

**Answers:** (1) No; mount its existing filesystem. (2) No; inspect retained resources. (3) It establishes independent evidence of the desired earlier content.

**Ready for the lab:** You can distinguish inspection, formatting, mounting and restoration, and identify the exact disposable disk before a write operation.

Further reading: [Incremental snapshots](https://learn.microsoft.com/en-us/azure/virtual-machines/disks-incremental-snapshots), [Advisor cost recommendations](https://learn.microsoft.com/en-us/azure/advisor/advisor-cost-recommendations).
