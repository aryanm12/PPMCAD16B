# Lab 10 - Migration Planning, MySQL Data Move and Cutover Rehearsal

**Read first:** [Brief notes - concepts for this lab](10-Migration-Planning-and-MySQL-Migration-brief-notes.md)

**How to work:** Use Azure portal for infrastructure, networking and recovery actions. The documented SSH session is used only for MySQL clients, SQL and data-validation tools; no Azure CLI commands are required.

## Outcome

Assess a small portfolio, create migration waves and execute a real **offline migration** of a synthetic MySQL database from a self-managed VM to private Azure Database for MySQL Flexible Server. Reconcile rows, switch a test client and rehearse rollback before accepting target writes.

**Time:** 2–3 hours. **Costs:** One source/client VM, disk/public IP, MySQL Flexible Server and backups. No actual on-premises server is required; an Azure VM stands in for the self-managed source. This does not demonstrate online CDC or Azure Migrate agent-based server replication.

## Prerequisites

- Contributor; Compute/Network/DBforMySQL providers registered.
- SSH client on your computer, password manager, learning subscription.
- Familiarity with basic SQL is helpful; exact commands are provided.
- No production data, active source writers or existing database are used.

## Lab 1 - Assess and sequence a portfolio

Create a worksheet:

| Application | Components | Dependency | Candidate decision |
|---|---|---|---|
| Internal wiki | Linux VM + MySQL | Corporate identity | Rehost VM; replatform DB if compatibility passes |
| Order API | Four VMs + database | Payment/inventory/DNS | Assess before selecting rehost/refactor |
| Reporting | VM + file share | Order data | Move after required data connectivity is proven |
| Archive | Rarely used old VM | None | Retain/retire based on business/legal need |

1. Add questions on versions, utilization, data volume/change rate, ports, identity, licensing, downtime, RPO/RTO and business owner.
2. Create Pilot, Wave 1, Wave 2 with entry/success/rollback criteria.
3. Map server discovery/assessment to **Azure Migrate**, DB migration to an appropriate supported MySQL migration method, and file transfer to tools such as AzCopy/Azure Storage migration options.
4. Use the wiki-sized database as the pilot below. Do not assume refactoring every application is necessary or low risk.

## Lab 2 - Build the source/client network

1. Create group `azlab10-migration`, Region East US 2 or another supported Region.
2. Create VNet `lab10-vnet`, `10.60.0.0/16`; subnet `source` `10.60.1.0/24`; subnet `database` `10.60.2.0/24`.
3. Delegate `database` to **Microsoft.DBforMySQL/flexibleServers**. Keep managed-service subnet network defaults.
4. Create NSG `lab10-source-nsg`, inbound SSH TCP 22 from **My IP /32**, priority 100; associate with `source`.
5. Create `lab10-source` VM, Ubuntu Server 22.04 LTS, Standard_B2s, username `azureuser`, generated SSH key `lab10-key`.
6. Basics inbound ports None; network source subnet, new Standard static public IP, NIC NSG None. Download key, wait for Running.
7. From your computer SSH with `ssh -i ~/Downloads/lab10-key.pem azureuser@YOUR-VM-IP`. On macOS/Linux restrict key permissions using `chmod 600`; on Windows use your downloaded file path and private user-only permissions.

## Lab 3 - Install MySQL and seed the source

**Inside the VM**:

```bash
sudo apt-get update
sudo apt-get install -y mysql-server mysql-client ca-certificates
sudo systemctl enable --now mysql
sudo mysql <<'SQL'
CREATE DATABASE lab10db;
CREATE TABLE lab10db.orders (id INT PRIMARY KEY, customer VARCHAR(40) NOT NULL, amount INT NOT NULL);
INSERT INTO lab10db.orders VALUES (1,'Asha',100),(2,'Ben',200),(3,'Chen',300);
SELECT VERSION();
SELECT * FROM lab10db.orders ORDER BY id;
SELECT COUNT(*) AS rows_found,SUM(amount) AS total FROM lab10db.orders;
SQL
```

Expected three rows, total 600. The source root login uses the local Unix socket via sudo. Do not open MySQL port 3306 to the internet.

Record source engine version, row values and data totals. This guide uses simple InnoDB tables without users, routines, triggers or DEFINER clauses; real migrations need explicit compatibility checks for those objects.

## Lab 4 - Create the managed target

1. Portal **MySQL flexible servers → Create**, same group/Region.
2. Unique name `lab10target-SUFFIX`; choose a supported MySQL 8.0 version compatible with the installed source/client. Do not migrate to an older incompatible major version.
3. MySQL authentication, admin `labadmin`, password stored in your password manager.
4. Burstable small suitable class, minimum offered storage, HA Disabled, backup retention 7 days. Review cost.
5. Private access (VNet Integration), `lab10-vnet/database`, create lab private DNS zone/VNet link.
6. Wait for Ready and record hostname.

Inside the source VM:

```bash
TARGET='YOUR-TARGET.mysql.database.azure.com'
getent hosts "$TARGET"
mysql --host="$TARGET" --user=labadmin --password \
  --ssl-mode=VERIFY_IDENTITY --ssl-ca=/etc/ssl/certs/ca-certificates.crt \
  --execute='SELECT VERSION(); CREATE DATABASE lab10db;'
```

Enter the target password at the prompt. Expected private address and a successful target connection/database creation.

## Lab 5 - Define the cutover gate and freeze writes

Write these gates before running the migration:

```text
Go: source/target reachable, compatibility checked, source data recorded, target empty
Success: exact rows match, count=3, total=600, target client query works
Rollback before target writes: point test client back to unchanged source
After target writes: stop and reconcile target changes before any rollback
Source retention: retain until validation/rollback rehearsal completes
```

There are no external applications writing to this synthetic source. Enforce read-only as an additional observable freeze:

```bash
sudo mysql --execute='SET GLOBAL read_only=ON; SET GLOBAL super_read_only=ON;'
sudo mysql --execute='SELECT @@global.read_only, @@global.super_read_only;'
```

Expected both 1. Keep the source running for reads and dump. Do not apply this administrative command to a shared server.

## Lab 6 - Export and import

Inside the VM:

```bash
umask 077
mkdir -p "$HOME/lab10"
cd "$HOME/lab10"
sudo mysqldump --single-transaction --set-gtid-purged=OFF --no-tablespaces \
  lab10db > lab10db.sql
test -s lab10db.sql && echo 'Dump file created'
sha256sum lab10db.sql
mysql --host="$TARGET" --user=labadmin --password \
  --ssl-mode=VERIFY_IDENTITY --ssl-ca=/etc/ssl/certs/ca-certificates.crt \
  lab10db < lab10db.sql
```

Enter the target password at the hidden prompt. The dump stays on the dedicated VM and contains only synthetic data. `--single-transaction` provides a consistent transactional snapshot for this InnoDB dataset; it is not a universal consistency guarantee for arbitrary nontransactional tables.

## Lab 7 - Reconcile exact data

```bash
sudo mysql --batch --skip-column-names \
  --execute='SELECT id,customer,amount FROM lab10db.orders ORDER BY id;' > source.tsv
mysql --host="$TARGET" --user=labadmin --password \
  --ssl-mode=VERIFY_IDENTITY --ssl-ca=/etc/ssl/certs/ca-certificates.crt \
  --batch --skip-column-names \
  --execute='SELECT id,customer,amount FROM lab10db.orders ORDER BY id;' > target.tsv
diff -u source.tsv target.tsv
sha256sum source.tsv target.tsv
mysql --host="$TARGET" --user=labadmin --password \
  --ssl-mode=VERIFY_IDENTITY --ssl-ca=/etc/ssl/certs/ca-certificates.crt \
  --execute='SELECT COUNT(*) AS rows_found,SUM(amount) AS total FROM lab10db.orders;'
```

Expected: no diff output, matching hashes, count 3/total 600. An import process exit without errors is not enough; these checks validate the resulting data.

## Lab 8 - Switch the test client and rehearse rollback

1. Treat the `TARGET` hostname as the new client connection setting. Run a read-only business check:

```bash
mysql --host="$TARGET" --user=labadmin --password \
  --ssl-mode=VERIFY_IDENTITY --ssl-ca=/etc/ssl/certs/ca-certificates.crt \
  --execute='SELECT customer,amount FROM lab10db.orders WHERE id=2;'
```

2. Expected Ben/200. Record cutover time. This is a test-client cutover, not a DNS change for a real website.
3. Before making any target writes, rehearse rollback by querying the original source:

```bash
sudo mysql --execute='SELECT customer,amount FROM lab10db.orders WHERE id=2;'
```

4. Expected the same result. Once you decide to resume the source in this rehearsal:

```bash
sudo mysql --execute='SET GLOBAL super_read_only=OFF; SET GLOBAL read_only=OFF;'
```

5. Do not write independently to both systems. For an actual successful migration, keep the old source frozen until the retention decision, and direct all writers to the chosen target.

## Lab 9 - Extend the runbook, not the downtime claim

Record measured export/import/validation time and explain how data volume, change rate, indexes and network would affect it.

For a real online migration, investigate a supported Azure MySQL migration/replication workflow with binlog prerequisites, lag monitoring, schema compatibility, final write freeze and reconciliation. This offline exercise does **not** demonstrate zero downtime or CDC.

## Troubleshooting

| Symptom | Correction |
|---|---|
| SSH fails | Current My IP rule, key path/permissions and VM public IP. |
| Target DNS/TCP failure | Private DNS link, VNet/delegated subnet, target Ready. |
| Dump privilege/GTID error | Use local sudo source account and provided flags; inspect exact error before editing data. |
| Import incompatible | Compare engine versions, schema/SQL modes and unsupported objects. |
| Data mismatch | Keep source frozen; inspect exact diff and import logs. Do not declare cutover successful. |
| Source write rejected after rehearsal | Check the intentionally enabled read_only/super_read_only settings. |

## Cleanup

Save only nonsecret worksheet/results. Exit SSH. Open **Resource groups → azlab10-migration**, review its resources, choose **Delete resource group**, type the group name and confirm. Wait for the deletion notification, refresh the group list and verify VM/disks/public IP and managed DB are removed. Remove lab-only DNS zone if placed elsewhere. The dump is removed with the VM disk; do not keep sensitive real migration dumps in unsecured local folders or source control.

## Completion checklist

- [ ] Portfolio/discovery questions and waves completed.
- [ ] Source write freeze and target readiness verified.
- [ ] Actual dump/import completed with exact row reconciliation.
- [ ] Test-client cutover and safe pre-write rollback demonstrated.
- [ ] Downtime limits and post-write rollback risk explained.
- [ ] All resources removed.

## References

- [Azure Migrate overview](https://learn.microsoft.com/en-us/azure/migrate/migrate-services-overview)
- [MySQL dump and restore](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concepts-migrate-dump-restore)
- [MySQL private networking](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concepts-networking-vnet)
