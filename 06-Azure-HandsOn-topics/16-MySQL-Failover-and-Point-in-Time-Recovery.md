# Lab 16 - MySQL HA Failover and Recovery of Deleted Data

**Read first:** [Brief notes - concepts for this lab](16-MySQL-Failover-and-Point-in-Time-Recovery-brief-notes.md)

**How to work:** Use Azure portal for infrastructure, networking and recovery actions. The documented SSH session is used only for MySQL clients, SQL and data-validation tools; no Azure CLI commands are required.

## Outcome

Force a zone-redundant MySQL failover, verify data survives, deliberately delete three synthetic rows, restore a pre-deletion point into a new server and validate the exact recovered records.

**Time:** 2–3 hours plus provisioning/backup delays. **Cost:** General Purpose primary/standby, storage/backups, a restored server and one VM/disk/public IP. This is a higher-cost lab. Read the displayed estimate and clean up promptly.

No previous lab resources are required. HA protects availability; PITR recovers historical state. They are tested independently here.

## Prerequisites

- Contributor, registered Compute/Network/DBforMySQL providers and sufficient regional quota.
- A Region supporting **zone-redundant** MySQL HA, for example East US 2 where offered to your subscription.
- SSH client on your computer and password manager. Use only the lab database below.

## Lab 1 - Create the private database network and SSH client

1. Create resource group `azlab16-recovery` in your selected Region.
2. Create VNet `lab16-vnet`, `10.66.0.0/16`; subnets `client` `10.66.1.0/24` and `database` `10.66.2.0/24`.
3. Delegate `database` to **Microsoft.DBforMySQL/flexibleServers**; leave managed-service subnet routing/security defaults intact.
4. Create NSG `lab16-client-nsg`; add inbound TCP 22, source **My IP /32**, priority 100. Associate it with `client`.
5. Create VM `lab16-client`, Ubuntu Server 22.04 LTS, Standard_B2s, username `azureuser`, generated SSH key `lab16-key`.
6. Basics public inbound ports None; Networking VNet/client subnet, new Standard static public IP, NIC NSG None (subnet NSG applies). Standard SSD OS disk.
7. Download the private key. Connect from your computer:

```text
ssh -i ~/Downloads/lab16-key.pem azureuser@YOUR-VM-PUBLIC-IP
```

On macOS/Linux first `chmod 600` the key file. On Windows use its actual `$HOME/Downloads` path and keep the key accessible only to your user.

8. **Inside the VM**:

```bash
sudo apt-get update
sudo apt-get install -y python3-venv ca-certificates dnsutils netcat-openbsd
mkdir -p "$HOME/lab16"
python3 -m venv "$HOME/lab16/venv"
"$HOME/lab16/venv/bin/pip" install 'PyMySQL[rsa]'
```

## Lab 2 - Create a zone-redundant server

1. Portal **MySQL flexible servers → Create**; group `azlab16-recovery`; same Region; unique name `lab16mysql-SUFFIX`.
2. Supported MySQL version 8.0 (or supported compatible version offered); MySQL authentication, admin `labadmin`, password saved privately.
3. Select **General Purpose**, smallest supported HA-capable offered class (often 2 vCores). Do not select Burstable.
4. High availability **Zone-redundant**, distinct primary/standby zones. If unavailable, select a supported Region before continuing; same-zone HA is not this exercise.
5. Storage: minimum offered suitable size; backup retention **7 days**. Keep secure transport enabled.
6. Networking **Private access (VNet Integration)**, `lab16-vnet/database`; create a lab private DNS zone and VNet link in the wizard.
7. Review cost/create. Wait until server Ready and HA healthy.
8. Record server hostname, primary/standby zones and HA state.

## Lab 3 - Install the verification client

Inside the VM paste:

```bash
cat > "$HOME/lab16/check.py" <<'PY'
import argparse
import getpass
import time
from datetime import datetime, timezone
import pymysql

p = argparse.ArgumentParser()
p.add_argument('mode', choices=['seed','read','watch','delete'])
p.add_argument('--host', required=True)
a = p.parse_args()
password = getpass.getpass('Lab MySQL password: ')
def now(): return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
def connect():
    return pymysql.connect(host=a.host, user='labadmin', password=password,
        connect_timeout=5, read_timeout=5, write_timeout=5, autocommit=True,
        ssl_ca='/etc/ssl/certs/ca-certificates.crt', ssl_verify_cert=True, ssl_verify_identity=True)
def read():
    with connect() as c:
        with c.cursor() as q:
            q.execute('SELECT id, customer, amount FROM lab16db.orders ORDER BY id')
            return q.fetchall()
if a.mode == 'seed':
    with connect() as c:
        with c.cursor() as q:
            q.execute('CREATE DATABASE IF NOT EXISTS lab16db')
            q.execute('CREATE TABLE IF NOT EXISTS lab16db.orders (id INT PRIMARY KEY, customer VARCHAR(40), amount INT)')
            q.executemany('INSERT IGNORE INTO lab16db.orders VALUES (%s,%s,%s)',
                          [(1,'Asha',100),(2,'Ben',200),(3,'Chen',300)])
    print(now(), 'COMMITTED', read(), flush=True)
elif a.mode == 'read':
    print(now(), 'ROWS', read(), flush=True)
elif a.mode == 'delete':
    if input('Type DELETE-LAB16 to remove only the three lab rows: ') != 'DELETE-LAB16':
        raise SystemExit('Cancelled')
    with connect() as c:
        with c.cursor() as q: q.execute('DELETE FROM lab16db.orders WHERE id IN (1,2,3)')
    print(now(), 'DELETE COMMITTED', read(), flush=True)
else:
    end = time.monotonic() + 900
    try:
        while time.monotonic() < end:
            try: print(now(), 'OK', read(), flush=True)
            except pymysql.MySQLError as e: print(now(), 'UNAVAILABLE', type(e).__name__, flush=True)
            time.sleep(5)
    except KeyboardInterrupt: print('Watch stopped')
PY
ORIGINAL='YOUR-ORIGINAL-SERVER.mysql.database.azure.com'
getent hosts "$ORIGINAL"
nc -vz -w 5 "$ORIGINAL" 3306
"$HOME/lab16/venv/bin/python" "$HOME/lab16/check.py" seed --host "$ORIGINAL"
```

Enter the password only at the hidden prompt. Expected private DNS address, TCP success, and `((1, 'Asha', 100), (2, 'Ben', 200), (3, 'Chen', 300))`. Record all values, count 3 and total 600.

## Lab 4 - Force failover and observe reconnection

```bash
"$HOME/lab16/venv/bin/python" "$HOME/lab16/check.py" watch --host "$ORIGINAL"
```

1. After several successful reads, portal server → **High availability → Forced failover / Initiate failover**. Review and confirm only this lab server.
2. Record the operation time, any failed reads and the first recovered read.
3. Wait for Ready/healthy HA. Inspect Activity log and primary/standby roles/zones.
4. Stop the watch with Ctrl+C after recovery. The script also stops after 15 minutes.
5. Confirm all three records remain and the server hostname remains the connection endpoint.

If no failure lands inside a sample interval, record that rather than inventing an outage. Existing application connections can break; this client reconnects on every read. The measured sample gap is approximate, not a guaranteed failover SLA.

## Lab 5 - Choose a safe UTC restore target

1. Run `read` again; verify the three records.
2. Wait at least one minute after the successful committed-data check, then run:

```bash
date -u '+%Y-%m-%dT%H:%M:%SZ'
```

3. Record that as `RESTORE_TARGET_UTC`. Make no writes.
4. In server **Backup and Restore**, inspect the earliest restorable time and available restore timeline. Wait until this target is a valid selectable time after the initial backup.
5. Wait at least one more minute before the delete so the target is clearly before deletion.

If a valid restore point is not available, stop before deletion and wait or clean up. Do not interpret “backup retention 7 days” as evidence the first backup is already usable.

## Lab 6 - Delete synthetic data

```bash
"$HOME/lab16/venv/bin/python" "$HOME/lab16/check.py" delete --host "$ORIGINAL"
```

Type `DELETE-LAB16` at the confirmation. Expected empty tuple `()`. Record deletion UTC time and verify it is later than the restore target. Read again and confirm the original is empty.

The committed DELETE propagates through HA. Another failover cannot recover old row values.

## Lab 7 - Restore a new server

1. Portal source server → **Backup and Restore → Restore**.
2. Select **Custom restore point**, enter `RESTORE_TARGET_UTC`; inspect the displayed timezone carefully.
3. Name `lab16restored-UNIQUE-SUFFIX`; target group `azlab16-recovery`; same Region.
4. Check private VNet/subnet and private DNS linkage in the restore workflow. After creation verify private access remains configured and the client VNet can resolve its hostname.
5. Review compute/storage cost, then restore. Wait for Ready and record the **new hostname**.
6. Check HA state: a restored MySQL Flexible Server is not automatically restored with HA enabled. This validation copy can remain non-HA to limit cost.

This operation creates another server; it does not overwrite the damaged source.

## Lab 8 - Validate and switch the test client

On the VM:

```bash
RESTORED='YOUR-RESTORED-SERVER.mysql.database.azure.com'
getent hosts "$RESTORED"
"$HOME/lab16/venv/bin/python" "$HOME/lab16/check.py" read --host "$RESTORED"
"$HOME/lab16/venv/bin/python" "$HOME/lab16/check.py" read --host "$ORIGINAL"
ACTIVE_HOST="$RESTORED"
"$HOME/lab16/venv/bin/python" "$HOME/lab16/check.py" read --host "$ACTIVE_HOST"
```

Expected restored rows exactly match the three original records, total 600; original still empty. The same password applies because no password change occurred around the selected time.

Record restore-start, Ready and data-validation times. The variable switch rehearses an application configuration change; it does not change DNS or other clients. In a real project, reconcile legitimate writes after the restore time before a production cutover. This exercise deliberately has none.

## Troubleshooting

| Symptom | Correction |
|---|---|
| HA unavailable | Supported General Purpose/Memory Optimized tier, Region/zones and quota. |
| Private DNS failure | Check the server's DNS zone/VNet link, including restored server linkage. |
| TLS failure | Correct hostname, current system CA roots and system time; do not disable verification. |
| Restore time rejected | Check UTC, earliest available point and whether backup processing has caught up. |
| Restored result empty | Wrong time chosen after DELETE; restore another new copy using the recorded pre-delete time and then remove the incorrect copy. |
| Unexpected restored HA Disabled | Expected restore behavior; enable HA separately for a real replacement requiring it. |

## Cleanup

Exit SSH. Delete `azlab16-recovery`, including **both servers**, VM/disks/public IP and network. Verify deletion in the resource-group list. Remove lab-only private DNS zones if the wizard put them elsewhere. Record any service-retained recovery state; do not leave the restored server running after validating it.

## Completion checklist

- [ ] Forced failover/AZ-role change recorded and original data survives.
- [ ] Pre-delete UTC restore target validated.
- [ ] Source confirmed empty after deletion.
- [ ] Restored server contains exact original rows and total.
- [ ] Test-client switch and recovery duration recorded.
- [ ] Both servers and all supporting resources removed.

## References

- [Manage MySQL HA](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/how-to-configure-high-availability)
- [MySQL backup and restore](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concepts-backup-restore)
- [Point-in-time restore using portal](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/how-to-restore-server-portal)
