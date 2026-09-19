# Lab 07 - Scheduled VM Backup and Cross-Region Recovery

**Read first:** [Brief notes - concepts for this lab](07-Azure-Backup-and-Cross-Region-Recovery-brief-notes.md)

**How to work:** Use Azure portal for resource creation, settings, verification and cleanup. Follow the guest-script instructions only when a step needs software running inside a VM.

## Outcome

Back up a VM containing a known file, inspect a scheduled policy and recovery points, restore a new VM and validate its file. Configure and execute a paired-region restore when the secondary recovery point becomes available.

**Time:** 2–3 hours for setup and primary-region restore, plus asynchronous replication time. Secondary-region recovery points can take **up to 48 hours** to appear initially. Plan this as a two-session lab; record pending state honestly instead of treating configuration as a completed regional recovery.

**Costs:** VM/disks/public IP, protected-instance and backup storage charges, restored VM/disks, and NAT Gateway for restored-VM outbound management. GRS and retained/soft-deleted backup data have lifecycle implications. Read Cleanup before provisioning.

## Prerequisites

- Contributor and sufficient Backup permissions on a new dedicated Recovery Services vault; provider `Microsoft.RecoveryServices` registered.
- Access to [Azure portal](https://portal.azure.com) with your learning subscription selected. Keep a local worksheet of the resource names you choose.
- Use a supported region pair; this guide uses **East US 2 → Central US**. Verify the vault's actual secondary Region in the portal before building the recovery network.
- Never enable irreversible immutability or multi-user authorization just for this disposable lab. If subscription policy enforces protections, preserve them and record deferred cleanup.

## Lab 1 - Create the source VM and proof file

1. In [Azure portal](https://portal.azure.com), search **Resource groups → Create**. Select your learning subscription, name `azlab07-backup`, Region **East US 2** (or the supported Region chosen for this lab). Select **Review + create → Create**.
2. Open the group → **Tags**; add `Project=AzureHandsOn` and `Lab=07`; **Apply**. Keep all resources below in this subscription, group and Region. Record names in your lab worksheet.

1. Search **Virtual networks → Create**; select the lab group and Region, name `lab07-source-vnet`.
2. On **IP addresses**, replace the default address space with `10.57.0.0/16`. Remove the default subnet if it conflicts. Add these subnets (name → address range): `vm` → `10.57.1.0/24`. Leave optional security services disabled for this lab.
3. **Review + create → Create**; wait for deployment success. Reopen **Subnets** and check each range.

1. Search **Network security groups → Create**; use `lab07-nsg`, lab group and Region. Open it after deployment.
4. Open **Subnets → Associate**; select `lab07-source-vnet` and `vm`; **OK**. Retain default rules, including AzureLoadBalancer health probes. Do not add public SSH/RDP rules. Verify association before creating VMs.

1. Search **Virtual machines → Create → Azure virtual machine**. Select lab subscription/group/Region; name `lab07-source`; image **Ubuntu Server 22.04 LTS, x64**; size **Standard_B2s** (select an available small equivalent if necessary). Use no infrastructure redundancy requirement for this single test VM. Username `azureuser`, authentication **SSH public key**, generate a new key pair; public inbound ports **None**.
2. **Disks**: OS disk **Standard SSD LRS**. **Networking**: select `lab07-source-vnet`, subnet `vm`; public IP **Create new → Standard, static**; NIC network security group **None** because the subnet NSG already applies. Leave load balancing off.
3. Disable optional paid services such as Backup for this VM unless this lab asks for them. **Review + create → Create**; download the private key when prompted and store it securely.
4. Wait for deployment. Open **Overview** to record private IP and provisioning status. Use **Operations → Run command → RunShellScript** for the guest scripts in this lab; paste the entire specified block and select **Run**. These Linux commands execute inside the VM, not on your computer.

Portal VM → **Run command → RunShellScript**:

```bash
mkdir -p /srv/lab07
printf 'Backup proof version 1\n' > /srv/lab07/proof.txt
sha256sum /srv/lab07/proof.txt
sync
```

Record hash and UTC time. We use a static file, not a database requiring application-aware quiescing.

## Lab 2 - Create the vault before enabling protection

1. Portal **Recovery Services vaults → Create**, name `lab07-vault`, group `azlab07-backup`, Region East US 2.
2. Open **Properties → Backup Configuration**.
3. Storage replication **Geo-redundant (GRS)**. Enable **Cross Region Restore**. Save before protecting a workload.
4. Record secondary Region and settings. Some vault settings cannot be freely changed after protection/CRR is enabled; this is a dedicated lab vault.
5. Inspect **Security settings / Soft delete**. Record whether soft delete is enabled/always-on, its retention and any immutability or Resource Guard requirements. Do not disable enforced security controls.

This is a **Recovery Services vault for VM backup**. Azure Disk Backup and some other workloads use a different **Backup vault**; they do not share every feature. MySQL Flexible Server uses its own native backup/geo-restore features, as in guide 16.

## Lab 3 - Configure a scheduled backup policy

1. Vault → **Backup → Where is workload running? Azure → What to back up? Virtual machine**.
2. Select an **Enhanced** VM backup policy, which supports modern VM security configurations. Name `lab07-daily`.
3. Set backup frequency Daily at a time convenient for your next session. Record the timezone shown.
4. Set daily retention **7 days** where offered; leave required minimum instant-restore retention at its supported value. Avoid unnecessary weekly/monthly/yearly retention.
5. Choose `lab07-source`, enable backup and wait for configuration success.
6. Vault → **Backup items → Azure Virtual Machine → lab07-source → Backup now**.
7. Set a short supported retain-until date, start the job and open **Backup jobs**.
8. Wait for Completed. Then inspect the VM's recovery points and their available recovery tiers.

A manual backup does not prove that the schedule fired. During the next session, check for a separate scheduled job at the configured time and record its result.

## Lab 4 - Change the source after backup

After the backup is complete, run on the source VM:

```bash
printf 'Backup proof version 2 - after recovery point\n' > /srv/lab07/proof.txt
sha256sum /srv/lab07/proof.txt
sync
```

Record the different hash. The source stays available; restoring will create a separate VM.

## Lab 5 - Create an isolated primary-region restore network

The restored VM may not have a public IP. Give its subnet explicit outbound access for the VM agent and Run Command:

1. Search **Virtual networks → Create**; select the lab group and Region, name `lab07-restore-vnet`.
2. On **IP addresses**, replace the default address space with `10.157.0.0/16`. Remove the default subnet if it conflicts. Add these subnets (name → address range): `restore` → `10.157.1.0/24`. Leave optional security services disabled for this lab.
3. **Review + create → Create**; wait for deployment success. Reopen **Subnets** and check each range.

1. Search **NAT gateways → Create**; lab group/Region; name `lab07-restore-nat`, Standard SKU.
2. **Outbound IP → Create a new public IP address**: `lab07-restore-nat-ip`, Standard, static.
3. **Subnet**: VNet `lab07-restore-vnet`, select `restore`. **Review + create → Create**. Verify the subnet shows this NAT gateway. This supplies explicit outbound access for private VMs; it does not open inbound access.

## Lab 6 - Restore and validate in the primary Region

1. Vault → protected VM → **Restore VM**.
2. Select the completed pre-change recovery point. Choose **Create new VM**, name `lab07-restored-primary`.
3. Target group `azlab07-backup`; VNet `lab07-restore-vnet`, subnet `restore`.
4. If staging Storage is requested, create a Standard storage account in the same group/Region, unique name, and select it. Record it for cleanup.
5. Review size and restore. Monitor the **Restore job** until Completed, then wait for the new VM to be Running with a healthy agent.
6. On the **restored VM**, Run Command:

```bash
cat /srv/lab07/proof.txt
sha256sum /srv/lab07/proof.txt
```

Expected: Version 1 and the original hash. Verify the source still contains Version 2. Record restore-start and successful validation times.

## Lab 7 - Prepare the secondary Region only when a point is available

1. Vault **Backup items → Azure Virtual Machine**, switch to **Secondary Region / Cross Region Restore**.
2. Select the source and inspect available recovery points. Wait for a **vault-tier** secondary recovery point corresponding to the pre-change state.
3. If none exists, record `Pending secondary replication`, end the session and revisit later. Initial availability is not immediate; retain the source backup until validation is complete. Record ongoing resource costs.
4. Once available, create recovery group `azlab07-dr` in the verified secondary Region (example Central US).
5. Create VNet `lab07-dr-vnet`, CIDR `10.158.0.0/16`, subnet `restore` `10.158.1.0/24` in that Region.
6. Create a Standard static public IP and NAT Gateway in `azlab07-dr`; associate it with the restore subnet. Use portal **NAT gateways → Create → Outbound IP → Subnet association**.
7. Create a Standard staging Storage account in the secondary group/Region if the restore workflow requests it.

Do not confuse GRS replication being enabled with a completed application disaster-recovery test.

## Lab 8 - Execute the cross-region restore

1. In the vault's **Secondary Region** view select the pre-change recovery point → Restore.
2. Choose new VM restoration if offered. If only **Restore disks** is offered for this configuration, restore to `azlab07-dr`, wait for job completion and use the generated deployment template's **Deploy** action to create the VM from the restored disks.
3. VM name `lab07-restored-dr`; target group `azlab07-dr`; VNet `lab07-dr-vnet/restore`; choose an available compatible size.
4. Do not select **Replace existing VM/disks**.
5. Wait for restore/deployment completion and VM agent readiness.
6. Run the same file/hash commands on the DR VM. Expected Version 1 and matching hash.
7. Record recovery-point time, Region, restore duration, hash and network dependencies.

## Troubleshooting

| Symptom | Correction |
|---|---|
| VM absent from protection picker | Same source Region/vault, supported VM configuration, no protection in another vault. |
| Backup fails | Read job details, inspect VM agent/extension health and policy compatibility. |
| Secondary points absent | Check GRS/CRR, completed vault-tier backup and replication delay. |
| Restored Run Command fails | Check NAT association, outbound rules, VM agent and boot diagnostics. |
| Restore allocation fails | Regional quota/size availability; select a compatible available size. |
| Hash differs | Verify recovery-point timestamp and that you checked the restored VM, not the source. |

## Cleanup

1. Delete both restored VMs, disks, staging accounts and recovery NAT resources by deleting `azlab07-dr` and the primary restore resources (or the source group later).
2. Vault → protected source → **Stop backup → Delete backup data**, confirm the disposable resource. Do not choose retain-data unless intentional.
3. Inspect soft-deleted items. With always-on/enforced soft delete, deletion may remain pending until retention expires. Do not report the vault as deleted while data is retained.
4. Delete source VM and its disk/public IP/network resources so compute charges stop. If the vault blocks whole-group deletion, delete these resources individually through the group's resource list.
5. Record vault name, retained-item expiry and remaining cleanup action. After retention and all dependencies clear, delete the empty vault and `azlab07-backup` group.
6. Verify both groups are absent when final cleanup completes. Do not disable organization protections to accelerate this.

## Completion checklist

- [ ] Scheduled policy and on-demand job recorded separately.
- [ ] Primary restore matches original file/hash.
- [ ] Secondary restore matches original file/hash, or explicitly remains pending.
- [ ] Compute removed and any retained backup cleanup date recorded.

## References

- [Create/configure Recovery Services vault](https://learn.microsoft.com/en-us/azure/backup/backup-create-rs-vault)
- [Restore Azure VMs, including cross-region](https://learn.microsoft.com/en-us/azure/backup/backup-azure-arm-restore-vms)
- [VM backup support matrix](https://learn.microsoft.com/en-us/azure/backup/backup-support-matrix-iaas)
- [Backup soft delete](https://learn.microsoft.com/en-us/azure/backup/backup-azure-security-feature-cloud)
