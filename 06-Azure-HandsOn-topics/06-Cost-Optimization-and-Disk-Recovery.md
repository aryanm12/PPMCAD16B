# Lab 06 - Cost Analysis, Advisor and File-Verified Disk Recovery

**Read first:** [Brief notes - concepts for this lab](06-Cost-Optimization-and-Disk-Recovery-brief-notes.md)

**How to work:** Use Azure portal for resource creation, settings, verification and cleanup. Follow the guest-script instructions only when a step needs software running inside a VM.

## Outcome

Inspect costs/recommendations, attach a disposable data disk, write a known file, take a snapshot, change the file and restore the earlier contents on a new disk.

**Time:** 60–90 minutes. **Costs:** One VM/disk/public IP, a 4-GiB data disk, snapshot and restored disk. A snapshot protects a disk; scheduled whole-VM protection is covered separately in guide 07.

## Prerequisites

- Contributor plus Cost Management Reader access; Compute/Network providers registered.
- Access to [Azure portal](https://portal.azure.com) with your learning subscription selected. Keep a local worksheet of the resource names you choose.
- Never run filesystem formatting commands against an existing/shared disk. This guide attaches a new empty disk at a specific LUN and verifies it before formatting.

## Lab 1 - Inspect costs without making blind changes

1. Portal **Cost Management → Cost analysis**, subscription scope, current month, group by Service name.
2. Change grouping to Resource group and Location. Record the largest contributors, or `No billing data yet`.
3. Open **Advisor → Cost**. Inspect one available recommendation, including impacted resource, utilization basis and expected savings.
4. Do not resize/delete a shared resource. If no recommendation exists in this new account, use this worksheet instead:

```text
Workload: training VM used two hours per day
Current pattern: left running overnight
Candidate action: deallocate between sessions; delete after course
What remains billable: managed disks and some allocated networking resources
Risk: unsaved local state / losing connectivity
Evidence needed: resource inventory and expected next use
```

5. Under **Budgets**, create a subscription monthly cost budget with actual alerts at 80%/100% and your email if one does not already exist. Choose an amount appropriate to your account. Alerts are not real-time shutdown controls.

## Lab 2 - Create a client and data disk

1. In [Azure portal](https://portal.azure.com), search **Resource groups → Create**. Select your learning subscription, name `azlab06-recovery`, Region **East US 2** (or the supported Region chosen for this lab). Select **Review + create → Create**.
2. Open the group → **Tags**; add `Project=AzureHandsOn` and `Lab=06`; **Apply**. Keep all resources below in this subscription, group and Region. Record names in your lab worksheet.

1. Search **Virtual networks → Create**; select the lab group and Region, name `lab06-vnet`.
2. On **IP addresses**, replace the default address space with `10.56.0.0/16`. Remove the default subnet if it conflicts. Add these subnets (name → address range): `client` → `10.56.1.0/24`. Leave optional security services disabled for this lab.
3. **Review + create → Create**; wait for deployment success. Reopen **Subnets** and check each range.

1. Search **Network security groups → Create**; use `lab06-nsg`, lab group and Region. Open it after deployment.
4. Open **Subnets → Associate**; select `lab06-vnet` and `client`; **OK**. Retain default rules, including AzureLoadBalancer health probes. Do not add public SSH/RDP rules. Verify association before creating VMs.

1. Search **Virtual machines → Create → Azure virtual machine**. Select lab subscription/group/Region; name `lab06-vm`; image **Ubuntu Server 22.04 LTS, x64**; size **Standard_B2s** (select an available small equivalent if necessary). Use no infrastructure redundancy requirement for this single test VM. Username `azureuser`, authentication **SSH public key**, generate a new key pair; public inbound ports **None**.
2. **Disks**: OS disk **Standard SSD LRS**. **Networking**: select `lab06-vnet`, subnet `client`; public IP **Create new → Standard, static**; NIC network security group **None** because the subnet NSG already applies. Leave load balancing off.
3. Disable optional paid services such as Backup for this VM unless this lab asks for them. **Review + create → Create**; download the private key when prompted and store it securely.
4. Wait for deployment. Open **Overview** to record private IP and provisioning status. Use **Operations → Run command → RunShellScript** for the guest scripts in this lab; paste the entire specified block and select **Run**. These Linux commands execute inside the VM, not on your computer.

Open **lab06-vm → Disks → Create and attach a new disk**. Name `lab06-data`, size `4 GiB`, Standard SSD LRS, source None. Set **LUN 0**, host caching None; **Save**. Wait for attachment before continuing.

No Internet inbound rule is opened. Use portal **VM → Run command → RunShellScript** for all Linux blocks below.

## Lab 3 - Identify the empty disk before formatting

Run only this inspection first:

```bash
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
readlink -f /dev/disk/azure/scsi1/lun0
lsblk -f /dev/disk/azure/scsi1/lun0
```

Expected: LUN 0 identifies a 4-GiB disk with no filesystem and no mountpoint. It must not be the OS disk or temporary resource disk. If the Azure disk symlink is absent, inspect the VM disk attachment/LUN and stop until you identify it; never guess `/dev/sdb`.

Now run:

```bash
set -eu
DISK=/dev/disk/azure/scsi1/lun0
test -b "$DISK"
test -z "$(lsblk -n -o FSTYPE "$DISK" | tr -d '[:space:]')"
mkfs.ext4 "$DISK"
mkdir -p /mnt/lab06-original
mount "$DISK" /mnt/lab06-original
printf 'Version 1 - recover this content\n' > /mnt/lab06-original/proof.txt
sha256sum /mnt/lab06-original/proof.txt
sync
umount /mnt/lab06-original
```

Record the SHA-256 value. The explicit unmount makes this small filesystem quiescent before the snapshot. We deliberately do not add an fstab entry for this temporary lab.

## Lab 4 - Snapshot the data-bearing disk

In the Azure portal:

1. Search **Disks → lab06-data → Create snapshot**. Group `azlab06-recovery`, name `lab06-before-change`, same Region, snapshot type **Incremental**, storage **Standard LRS**.
2. **Review + create → Create**; open the snapshot and verify provisioning succeeded and source disk is `lab06-data`.

Expected: Succeeded. Record snapshot ID/time. An empty disk snapshot would not prove data recovery; this one contains your known file.

## Lab 5 - Change the original file

Through VM Run Command:

```bash
set -eu
mount /dev/disk/azure/scsi1/lun0 /mnt/lab06-original
printf 'Version 2 - original changed after snapshot\n' > /mnt/lab06-original/proof.txt
cat /mnt/lab06-original/proof.txt
sha256sum /mnt/lab06-original/proof.txt
sync
umount /mnt/lab06-original
```

Expected: Version 2 and a different hash. The snapshot retains its earlier state; it is not a live mirror.

## Lab 6 - Restore into a new disk

Azure portal:

1. Open **Snapshots → lab06-before-change → Create disk**. Lab group/Region, name `lab06-restored`, Standard SSD LRS, compatible zone with the VM; keep source snapshot and size unchanged. **Review + create → Create**.
2. Open **lab06-vm → Disks → Attach existing disks**; select `lab06-restored`, **LUN 1**, host caching None; **Save**. Keep the original disk attached at LUN 0.

On VM Run Command:

```bash
set -eu
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
readlink -f /dev/disk/azure/scsi1/lun1
mkdir -p /mnt/lab06-restored
mount -o ro,noload /dev/disk/azure/scsi1/lun1 /mnt/lab06-restored
cat /mnt/lab06-restored/proof.txt
sha256sum /mnt/lab06-restored/proof.txt
umount /mnt/lab06-restored
```

**Do not format the restored disk.** Expected Version 1 and the exact original hash. `ro,noload` mounts this cleanly unmounted ext4 snapshot read-only without replaying its journal. Mount by LUN, not duplicate filesystem UUID.

## Lab 7 - Record recovery evidence

```text
Snapshot time:
Original version-1 hash:
Changed version-2 hash:
Restore start / data verification time:
Restored hash:
Match result:
What happens to changes after the snapshot?
```

A successful restore creates a new disk. Recovery is proven by the file/hash check, not merely the new disk's existence. A production database needs application-consistent backup procedures beyond this filesystem demonstration.

## Troubleshooting

| Symptom | Correction |
|---|---|
| LUN symlink absent | Check VM Disks blade and actual LUN; wait for attachment. Do not format a guessed disk. |
| Filesystem already exists | Stop formatting. Confirm whether the disk is an earlier lab disk or the restored copy. |
| Snapshot operation fails | Check resource location, disk ID and provisioning state. |
| Restored file shows Version 2 | Verify snapshot was taken before modification and source snapshot ID is correct. |
| Mount complains | Verify ext4 and correct LUN; never run mkfs on a restored copy as a fix. |
| Advisor empty | Normal for a new subscription; use the provided optimization worksheet. |

## Cleanup

Ensure both mounts are unmounted, then inspect/delete `azlab06-recovery` in **Resource groups**: open the group, review resources, choose **Delete resource group**, type its name and confirm. Wait for success and refresh the resource-group list to verify absence. Check both data disks and the snapshot, not just the VM. Keep the subscription budget intentionally or delete it when training ends.

## Completion checklist

- [ ] Cost/recommendation evidence or new-account fallback recorded.
- [ ] Empty disposable disk identified before formatting.
- [ ] Snapshot contains Version 1; original changed to Version 2.
- [ ] Restored hash equals the pre-change hash.
- [ ] All lab storage/compute deleted.

## References

- [Azure Advisor cost recommendations](https://learn.microsoft.com/en-us/azure/advisor/advisor-cost-recommendations)
- [Incremental managed-disk snapshots](https://learn.microsoft.com/en-us/azure/virtual-machines/disks-incremental-snapshots)
- [Attach a Linux data disk](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/attach-disk-portal)
