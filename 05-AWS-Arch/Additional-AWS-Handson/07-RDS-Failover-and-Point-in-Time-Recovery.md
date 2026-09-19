# Hands-On Lab 07 - RDS Failover and Recovery from Accidental Deletion

## Outcome

Create a private Multi-AZ MySQL database, insert known data, observe a forced failover and then recover deliberately deleted data into a **new** database using point-in-time recovery (PITR).

**Time:** 2–3 hours, including provisioning, initial backup and restore delays. Some accounts need longer before a usable PITR window appears.

**Costs:** A Multi-AZ RDS instance (primary plus standby), storage/backups, a second restored DB, one EC2 client, its EBS disk and public IPv4. This is the most expensive guide in this set. Review the console estimate before creating RDS and perform cleanup in the same sitting.

No previous lab is required. Use only the synthetic data created here. The intentional DELETE is limited to the lab database/table.

```text
EC2 client → RDS endpoint → primary AZ-A ⇄ standby AZ-B
                              |
                              +→ automated backups/logs → NEW restored database
```

## Prerequisites

- Sandbox permissions for VPC, EC2, SSM, IAM/PassRole and RDS creation, reboot/failover, restore and deletion.
- A Region supporting MySQL Multi-AZ **DB instance** deployment and a small compatible class; example `ap-south-1`.
- Quota for the original Multi-AZ DB plus a restored DB.
- Record all identifiers/endpoints and timestamps in a worksheet. Use UTC throughout recovery decisions.
- Store the DB password in a password manager. The Python client below prompts without echoing it; never place it in a command argument.
- Commands run in **EC2 Session Manager**, except commands explicitly marked **CloudShell**.

## Lab 1 - Create the network

1. Create **VPC only** `lab07-vpc`, CIDR `10.47.0.0/16`, no IPv6.
2. Enable DNS resolution and DNS hostnames in VPC settings.
3. Create:

| Subnet | AZ | CIDR |
|---|---|---|
| lab07-client-a | AZ-A | 10.47.1.0/24 |
| lab07-db-a | AZ-A | 10.47.11.0/24 |
| lab07-db-b | Different AZ-B | 10.47.12.0/24 |

4. Enable auto-assign public IPv4 only on the client subnet.
5. Create/attach Internet Gateway `lab07-igw`.
6. Create `lab07-public-rt`, add `0.0.0.0/0 → lab07-igw`, associate the client subnet only.
7. Create `lab07-db-rt`, retain local route only, associate both DB subnets.
8. Create `lab07-client-sg`: no inbound, default outbound allow-all.
9. Create `lab07-db-sg`: MySQL/TCP 3306 inbound from **lab07-client-sg**, default outbound allow-all.
10. Create an RDS subnet group `lab07-db-subnets` containing both DB subnets in their two AZs.

## Lab 2 - Create the Multi-AZ DB instance

1. **RDS → Databases → Create database → Standard create**.
2. Engine **MySQL**, a supported 8.4 version where available; choose a currently supported non-extended-support version if 8.4 is unavailable.
3. Choose a template exposing **Multi-AZ DB instance deployment**. Select this explicitly: one primary and one standby. Do not select **Multi-AZ DB cluster**, which has a different topology.
4. Identifier `lab07-mysql`; username `labadmin`; self-managed password from your password manager.
5. Select a small offered compatible burstable class such as `db.t3.micro` or `db.t4g.micro`. If neither is offered for your engine/deployment, review the smallest offered class and its cost before continuing.
6. Storage: gp3, 20 GiB where offered; disable storage autoscaling for this bounded dataset; default encryption enabled.
7. Connectivity: do not automatically connect an EC2 resource. Select `lab07-vpc`, `lab07-db-subnets`, **Public access: No**, and only `lab07-db-sg`, port 3306.
8. Additional configuration: initial database `lab07db`; **automated backup retention 1 day**. PITR requires enabled automated backups.
9. Use an automatic backup window. Disable deletion protection for this disposable lab. Disable optional paid enhanced monitoring/advanced Database Insights if offered.
10. Review the estimated cost and create. Wait until **Available**.
11. Record endpoint, primary AZ, secondary AZ and confirmation that Multi-AZ is enabled.

**Checkpoint:** Private MySQL Multi-AZ DB instance Available, backup retention nonzero. Having two DB subnets alone does not mean Multi-AZ is enabled.

## Lab 3 - Prepare the EC2 client

1. In IAM create `lab07-ec2-role`, trusted service EC2, with `AmazonSSMManagedInstanceCore`.
2. Launch `lab07-client`, standard Amazon Linux 2023 x86_64, `t3.micro`, no key pair.
3. Select `lab07-client-a`, public IP enabled, only `lab07-client-sg`.
4. Root disk 8 GiB gp3, delete-on-termination enabled; advanced instance profile `lab07-ec2-role`, IMDSv2 required, no user data.
5. Wait for status checks and connect through **Session Manager**.
6. Run:

```bash
sudo dnf install -y python3 python3-pip
mkdir -p "$HOME/lab07"
cd "$HOME/lab07"
python3 -m venv .venv
.venv/bin/pip install 'PyMySQL[rsa]'
curl --fail --show-error --location \
  https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
  --output rds-ca.pem
```

## Lab 4 - Create a repeatable data-checking client

The program supports four modes: `seed`, `read`, `watch` and `delete`. It verifies the lab database name in code and never prints the password.

```bash
cat > "$HOME/lab07/db_check.py" <<'PY'
import argparse
import getpass
import time
from datetime import datetime, timezone
from pathlib import Path

import pymysql

parser = argparse.ArgumentParser()
parser.add_argument('mode', choices=['seed', 'read', 'watch', 'delete'])
parser.add_argument('--host', required=True)
args = parser.parse_args()
password = getpass.getpass('Lab RDS password: ')

def stamp():
    return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

def connect():
    return pymysql.connect(
        host=args.host, user='labadmin', password=password, database='lab07db',
        connect_timeout=5, read_timeout=5, write_timeout=5, autocommit=True,
        ssl_ca=str(Path(__file__).with_name('rds-ca.pem')),
        ssl_verify_cert=True, ssl_verify_identity=True,
    )

def read_rows():
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute('SELECT id, customer, amount FROM orders ORDER BY id')
            return cursor.fetchall()

if args.mode == 'seed':
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute('CREATE TABLE IF NOT EXISTS orders (id INT PRIMARY KEY, customer VARCHAR(40), amount INT)')
            cursor.executemany('INSERT IGNORE INTO orders VALUES (%s,%s,%s)',
                               [(1, 'Asha', 100), (2, 'Ben', 200), (3, 'Chen', 300)])
    print(stamp(), 'COMMITTED', read_rows(), flush=True)
elif args.mode == 'read':
    print(stamp(), 'ROWS', read_rows(), flush=True)
elif args.mode == 'delete':
    answer = input('Type DELETE-LAB07-ORDERS to delete the three lab rows: ')
    if answer != 'DELETE-LAB07-ORDERS':
        raise SystemExit('Cancelled')
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute('DELETE FROM orders WHERE id IN (1,2,3)')
    print(stamp(), 'DELETE COMMITTED', read_rows(), flush=True)
else:
    print('Watching for 15 minutes; Ctrl+C stops early.', flush=True)
    end = time.monotonic() + 900
    try:
        while time.monotonic() < end:
            try:
                print(stamp(), 'OK', read_rows(), flush=True)
            except pymysql.MySQLError as error:
                print(stamp(), 'UNAVAILABLE', type(error).__name__, flush=True)
            time.sleep(5)
    except KeyboardInterrupt:
        print('Watch stopped.', flush=True)
PY
ORIGINAL_HOST='YOUR-ORIGINAL-RDS-ENDPOINT'
"$HOME/lab07/.venv/bin/python" "$HOME/lab07/db_check.py" seed --host "$ORIGINAL_HOST"
```

Replace the hostname before running. Enter the password at the hidden prompt.

Expected data:

```text
((1, 'Asha', 100), (2, 'Ben', 200), (3, 'Chen', 300))
```

Record the three rows, row count **3**, amount total **600**, and commit timestamp. The program uses autocommit, so a successful seed output follows committed writes.

## Lab 5 - Measure a forced failover

1. On EC2 run:

```bash
"$HOME/lab07/.venv/bin/python" "$HOME/lab07/db_check.py" watch --host "$ORIGINAL_HOST"
```

2. After several `OK` lines, open RDS in another browser tab.
3. Select only `lab07-mysql` → **Actions → Reboot**.
4. Check **Reboot with failover** and confirm. If this option is absent, recheck that this is a Multi-AZ DB instance and that no modification is pending.
5. Watch the terminal. Record the last successful read, any `UNAVAILABLE` lines, and the first successful read after failover.
6. In RDS **Logs & events / Events**, record failover events. After recovery, record the new primary AZ and compare it with the original.
7. Stop the watch with Ctrl+C after recovery.

Expected: the endpoint name stays the same, the primary AZ changes, and all three rows remain. The client reconnects for each read. Existing application connections may break during failover and need retry/reconnect logic.

If the outage falls between samples, record that no failed sample was observed; RDS events and changed primary AZ are still evidence. Sample intervals and connection timeouts mean this is an approximate observed interruption, not a precise service-wide RTO measurement.

**Do not continue until the original DB is Available and all three rows are readable.**

## Lab 6 - Establish a safe restore timestamp

PITR needs a timestamp **after the inserts committed and before deletion**. Use a comfortable gap rather than guessing at a boundary second.

1. On EC2, run `read` again and verify the three original rows:

```bash
"$HOME/lab07/.venv/bin/python" "$HOME/lab07/db_check.py" read --host "$ORIGINAL_HOST"
date -u '+%Y-%m-%dT%H:%M:%SZ'
```

2. Wait at least **one minute** after the successful read. Run the `date -u` command again. Record that output as **RESTORE_TARGET_UTC**.
3. Wait at least another **one minute** before the next lab. Make no other writes.
4. Open **RDS → lab07-mysql → Maintenance & backups** and inspect the earliest/latest restorable times. The exact tab label may vary.
5. For an unambiguous UTC check, open **CloudShell** in the same Region and run:

```bash
aws rds describe-db-instance-automated-backups --db-instance-identifier lab07-mysql \
  --region ap-south-1 \
  --query 'DBInstanceAutomatedBackups[0].{Earliest:RestoreWindow.EarliestTime,Latest:RestoreWindow.LatestTime,Retention:BackupRetentionPeriod}'
```

6. Wait until the target is within the supported window: **Earliest ≤ target < Latest**. If the output is null or the latest time has not passed the target, check again after a few minutes. Initial backup/log availability is not immediate.

If no usable PITR window appears during your available time, stop before the destructive exercise, record the limitation and clean up. Do not delete the rows without a supported recovery target.

## Lab 7 - Simulate accidental deletion

1. Record the current UTC time as the beginning of the recovery exercise.
2. On EC2 run:

```bash
"$HOME/lab07/.venv/bin/python" "$HOME/lab07/db_check.py" delete --host "$ORIGINAL_HOST"
```

3. At the confirmation prompt, type `DELETE-LAB07-ORDERS`.
4. Expected: `DELETE COMMITTED ()`—the table exists but contains no rows.
5. Record the deletion commit timestamp. Verify it is later than `RESTORE_TARGET_UTC`.
6. Run `read` against the original DB and verify it still returns no rows.

**Explanation:** Multi-AZ replicates committed changes, including this deletion. Failing over again will not bring the rows back. We need historical recovery.

## Lab 8 - Restore a new database

1. In RDS select `lab07-mysql` → **Actions → Restore to point in time**.
2. Select **Custom date and time** and enter the recorded `RESTORE_TARGET_UTC`. Check the console timezone selector carefully; choose UTC or convert explicitly. Do not choose “latest” after the deletion.
3. New DB identifier: `lab07-mysql-restored`.
4. Select the same engine-compatible small class. Choose **Single-AZ** for this validation copy where the restore workflow permits it; otherwise inspect the inherited Multi-AZ setting and its extra cost.
5. Set/verify VPC `lab07-vpc`, subnet group `lab07-db-subnets`, **Public access: No**, only `lab07-db-sg`, port 3306.
6. Keep encryption compatible with the source, deletion protection disabled, and optional paid monitoring disabled.
7. Restore and record the start time. This creates a new instance; it does not overwrite the source.
8. Wait for Available, inspect its connectivity/security again, and copy the **new endpoint**.

Do not assume restore settings such as security groups are copied exactly. Verify them before connection testing.

## Lab 9 - Validate data and rehearse a connection switch

On EC2:

```bash
RESTORED_HOST='YOUR-RESTORED-RDS-ENDPOINT'
"$HOME/lab07/.venv/bin/python" "$HOME/lab07/db_check.py" read --host "$RESTORED_HOST"
"$HOME/lab07/.venv/bin/python" "$HOME/lab07/db_check.py" read --host "$ORIGINAL_HOST"
```

Enter the same lab password at each prompt; the selected restore time predates no password change in this exercise.

Expected:

| Target | Expected rows |
|---|---|
| Restored DB | Original three rows; total amount 600 |
| Original DB | Empty result |

1. Verify the **exact IDs, customer names and amounts**, not just DB Available status.
2. Record the time when successful data validation completes.
3. Calculate elapsed time from the beginning of the recovery exercise to successful validation. This includes your manual restore and checking time.
4. Rehearse an application endpoint switch:

```bash
ACTIVE_HOST="$RESTORED_HOST"
"$HOME/lab07/.venv/bin/python" "$HOME/lab07/db_check.py" read --host "$ACTIVE_HOST"
```

5. Confirm all three rows. This switches only this test client's connection variable. It does not update DNS or any other application.

In a real recovery, reconcile writes after the selected restore time before a production cutover. This lab intentionally makes no legitimate writes after that time. Retaining the source lets you compare both databases without destroying evidence.

## Lab 10 - Complete the recovery worksheet

```text
Original DB identifier / endpoint:
Original primary AZ / new primary AZ:
Forced failover event time:
Last successful read / first failure / first recovered read:
Restore target (UTC):
Deletion committed (UTC):
Restore started / DB Available / data validated:
Restored DB identifier / endpoint:
Expected row count / actual row count:
Expected total / actual total:
Observed recovery exercise duration:
What writes would be lost if there had been writes after the restore target?
```

**Key distinction:** Multi-AZ addresses infrastructure availability. PITR recovers an earlier database state. Neither the configured retention nor the existence of a standby proves that a complete application meets its RPO/RTO.

## Troubleshooting

| Symptom | Action |
|---|---|
| Connection timeout | Check DB Available, actual endpoint, client route/VPC and DB SG permitting client SG on 3306. |
| Access denied by MySQL | Verify `labadmin` and password. This is DB authentication, separate from IAM. |
| Unknown database | Initial database name must be `lab07db`. Correct the setup before running destructive steps. |
| Failover option missing | Confirm traditional Multi-AZ DB instance, Available status and no pending changes. |
| PITR option missing | Check automated-backup retention >0, initial backup completed, permissions and restorable window. |
| Target time rejected | Check UTC conversion and earliest/latest values. Wait for latest restorable time to advance. |
| Restored data is empty | You may have selected a time after deletion. Retain source backups and restore another new DB using the recorded pre-delete target; delete the incorrect copy after verification. |
| TLS validation fails | Use the official CA bundle and actual endpoint; do not disable certificate verification. |
| Restore cannot launch | Check RDS quotas, class availability, subnet group/AZ coverage and account permissions. |

## Cleanup

1. Stop any watch process with Ctrl+C.
2. Delete `lab07-mysql-restored` and any incorrect additional restore copies. For synthetic data, uncheck final snapshot and retained automated backups.
3. Delete `lab07-mysql` with the same disposable-data choices. Disable deletion protection first if necessary.
4. Wait until all lab DB instances are gone. Check **Snapshots** and **Automated backups → Retained**; delete any lab-only retained copies you intentionally or accidentally kept.
5. Delete `lab07-db-subnets`.
6. Terminate `lab07-client` and verify its root volume is gone.
7. Delete the EC2 role and unused instance profile.
8. Delete DB SG, then client SG. Delete subnets, custom route tables, detach/delete IGW and delete VPC.
9. Review the resource worksheet. The restored DB is a separate billable resource and must be explicitly deleted.

## Completion checklist

- [ ] Exact sample data recorded before failure.
- [ ] Failover events/AZ change verified and data survived.
- [ ] Valid pre-deletion UTC recovery target established.
- [ ] Original DB confirmed empty after controlled deletion.
- [ ] Restored DB contains all three original rows and total 600.
- [ ] Client connection switch verified; recovery duration recorded.
- [ ] Both DBs, backups and all other lab resources cleaned up.

## References

- [Rebooting a DB instance](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_RebootInstance.html)
- [Restoring to a specified time](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIT.html)
- [RDS TLS certificates](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html)
