# Lab 05 - Private Azure Database for MySQL Flexible Server

**Read first:** [Brief notes - concepts for this lab](05-MySQL-Flexible-Server-and-High-Availability-brief-notes.md)

**How to work:** Use Azure portal for infrastructure, networking and recovery actions. The documented SSH session is used only for MySQL clients, SQL and data-validation tools; no Azure CLI commands are required.

## Outcome

Create a private managed MySQL server, connect from a VM, create/query data, and compare a low-cost non-HA deployment with zone-redundant HA. This guide creates the non-HA server; it includes an explicit optional HA conversion.

**Time:** 75–105 minutes. **Costs:** MySQL compute/storage/backups, one client VM/disk/public IP. HA requires a supported General Purpose or Memory Optimized tier and additional standby cost. A Burstable server is not an HA configuration.

## Prerequisites

- Contributor in a learning subscription; Compute, Network and DBforMySQL providers registered.
- A computer with an SSH client (`ssh` in Windows PowerShell, macOS Terminal or Linux).
- Choose **East US 2** or another Region with the required MySQL/VM capacity. All resources below use the same Region.
- Keep passwords in a password manager. Do not put them in commands, screenshots or worksheets.
- No prior network or VM is required. This guide uses a dedicated client VM; the database stays private.

## Lab 1 - Create the network

1. In the portal create resource group `azlab05-mysql`.
2. Create VNet `lab05-vnet`, address space `10.55.0.0/16`.
3. Create subnet `client`, `10.55.1.0/24`, and subnet `database`, `10.55.2.0/24`.
4. Open subnet `database`; set **Subnet delegation → Microsoft.DBforMySQL/flexibleServers**. Save.
5. Do not place VMs or private endpoints in this delegated subnet. Do not add a custom NSG/route table to it in this first exercise; the managed service requires its own internal traffic.
6. Create NSG `lab05-client-nsg`. Add inbound TCP 22 from **My IP** (your current computer's public IPv4 `/32`) with priority 100. Do not use Any/Internet as the source.
7. Associate the NSG with subnet `client`.

Azure's default VNet routes provide internal routing; no Internet Gateway is attached to a VNet.

## Lab 2 - Create the Linux client

1. **Virtual machines → Create Azure VM**; resource group `azlab05-mysql`, name `lab05-client`, same Region.
2. Image **Ubuntu Server 22.04 LTS**, x64; size `Standard_B2s` or another available small size.
3. Authentication **SSH public key**; username `azureuser`; generate new key pair `lab05-key` and download its `.pem` file when prompted.
4. On Basics, public inbound ports **None**. On Networking choose `lab05-vnet/client`, a new **Standard static public IP**, and NIC NSG **None** so the subnet NSG controls access.
5. OS disk Standard SSD; keep delete-with-VM enabled. Create and wait for Running.
6. Copy its public IP. From your computer run:

```text
ssh -i ~/Downloads/lab05-key.pem azureuser@YOUR-VM-PUBLIC-IP
```

On Windows, use the actual downloaded filename under `$HOME/Downloads`. On macOS/Linux, first run `chmod 600 ~/Downloads/lab05-key.pem`. If Windows reports an unprotected key, use file Properties → Security to restrict access to your own user rather than making the key public.

7. **Inside the VM**, run:

```bash
sudo apt-get update
sudo apt-get install -y mysql-client ca-certificates dnsutils netcat-openbsd
mysql --version
```

The VM public IP provides explicit outbound access for package installation. SSH is restricted to your computer. Record the VM's private address as well.

## Lab 3 - Create MySQL Flexible Server

1. Search **Azure Database for MySQL flexible servers → Create**.
2. Select the resource group and Region. Server name `lab05mysql-YOUR-UNIQUE-SUFFIX`.
3. Workload Development; MySQL **8.0**, or a supported version compatible with your client if 8.0 is unavailable.
4. Authentication **MySQL authentication**; administrator `labadmin`; strong password from your password manager.
5. Compute + storage: **Burstable**, smallest suitable offered SKU such as B1ms; storage **20 GiB** if the selected configuration allows it, otherwise use the displayed minimum. Backup retention **7 days**. Review the estimate.
6. High availability **Disabled**. Keep automatic storage growth according to the displayed default, but record that it can increase allocated storage/cost.
7. Networking: **Private access (VNet Integration)**; select `lab05-vnet`, delegated `database` subnet.
8. Create/select a private DNS zone offered by the wizard and ensure the VNet link is created. Record the zone name. Do not choose an unrelated existing shared zone.
9. Do not enable public network access. Review and create.
10. Wait for Ready. Record the full server hostname from Overview, ending in `mysql.database.azure.com`.

## Lab 4 - Verify DNS, TCP and TLS separately

**Inside the VM**:

```bash
DBHOST='YOUR-SERVER.mysql.database.azure.com'
getent hosts "$DBHOST"
nc -vz -w 5 "$DBHOST" 3306
mysql --host="$DBHOST" --user=labadmin --password \
  --ssl-mode=VERIFY_IDENTITY --ssl-ca=/etc/ssl/certs/ca-certificates.crt
```

Expected: hostname resolves to a private address; port 3306 is reachable; MySQL prompts for a password and opens a SQL prompt. Use `labadmin`, not the older Single Server `user@server` login convention.

If certificate verification fails, update `ca-certificates`, check the hostname and consult the linked TLS guide for the current trusted roots. Do not fix it by disabling TLS verification.

## Lab 5 - Create test data

At the **MySQL prompt**, paste:

```sql
CREATE DATABASE lab05db;
USE lab05db;
CREATE TABLE orders (
    id INT PRIMARY KEY,
    customer VARCHAR(40) NOT NULL,
    amount INT NOT NULL
);
INSERT INTO orders VALUES (1,'Asha',100),(2,'Ben',200),(3,'Chen',300);
SELECT * FROM orders ORDER BY id;
SELECT COUNT(*) AS row_count, SUM(amount) AS total FROM orders;
SHOW SESSION STATUS LIKE 'Ssl_cipher';
```

Expected: three rows, total 600, nonempty TLS cipher. Type `exit` to leave the SQL prompt. Reconnect using the previous command, then run `SELECT * FROM lab05db.orders;` to prove data persists across connections.

## Lab 6 - Inspect managed-service operations

1. Open server **Monitoring → Metrics**. Plot CPU percentage and active connections over the last hour.
2. Open **Backup and Restore**. Verify retention and available recovery information; a newly created server may need time before backup metadata appears.
3. Open **Server parameters**, locate `require_secure_transport` and confirm it is enabled. Do not disable it.
4. Open **High availability**. Record why the current Burstable deployment has no standby.
5. Complete:

| Question | Non-HA server | Zone-redundant HA |
|---|---|---|
| Standby in a separate zone | No | Yes |
| Burstable tier supported for HA | N/A | No |
| Protects against accidental SQL DELETE | Requires restore | Also requires restore |
| Additional standby cost | No | Yes |

## Lab 7 - Optional: enable HA

Only perform this if you want to pay for the HA demonstration. The core data-connection lab is complete without it.

1. Open **Compute + storage**, select **General Purpose** and a small supported SKU. Review the new estimate and save.
2. Wait for Ready; reconnect/query the three records.
3. Open **High availability**, enable **Zone-redundant**. If only same-zone HA is available, choose a suitable Region for a new lab deployment or record the limitation; do not label same-zone HA as zone resilience.
4. Save, wait for HA to become healthy, and record primary/standby zones.
5. Reconnect/query. The hostname remains the application entry point.

Guide 16 separately gives a complete forced-failover and PITR exercise, including actual deleted-data recovery.

## Troubleshooting

| Symptom | Correction |
|---|---|
| SSH timeout | Check current public client IP `/32`, subnet NSG, VM public IP and Running state. |
| DNS gives no private result | Verify private DNS zone and VNet link; use the server hostname from Overview. |
| TCP timeout | Confirm VM and server share the VNet and no custom route/NSG blocks service traffic. |
| Access denied | Check `labadmin` and password; do not append `@server`. |
| HA unavailable | Check compute tier, regional zone availability and quota. |
| No immediate metrics/backup | Allow collection/initial backup time and choose the right time range. |

## Cleanup

Exit the SSH session, then use the Azure portal:

1. Open **Resource groups → azlab05-mysql → Overview**. Review the complete resource list and confirm it contains only this exercise.
2. Select **Delete resource group**, type `azlab05-mysql` to confirm, and select **Delete**.
3. Watch **Notifications** for successful deletion. Return to **Resource groups**, refresh, and verify the group is absent; also check **All resources** with the same subscription filter. If deletion failed, inspect the reported dependency/lock and resolve it before considering cleanup complete.

Expected: the deleted resource group is absent after refreshing the portal list. Check whether the wizard placed the private DNS zone in another group; delete it only if it was exclusively created for this lab. Stopping MySQL/VMs is not permanent cleanup. Retained service recovery data follows Azure's service retention behavior.

## Completion checklist

- [ ] Private DNS/TCP/TLS validated independently.
- [ ] SQL returns three records and total 600.
- [ ] HA and backup explained as separate capabilities.
- [ ] Optional HA cost/zone configuration recorded if performed.
- [ ] Resource group and lab-only DNS resources removed.

## References

- [Private access in the portal](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/how-to-manage-virtual-network-portal)
- [TLS connectivity](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/how-to-connect-tls-ssl)
- [MySQL high availability](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concepts-high-availability)
