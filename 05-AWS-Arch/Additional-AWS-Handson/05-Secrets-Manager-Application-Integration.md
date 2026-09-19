# Hands-On Lab 05 - Retrieve Database Credentials with an IAM Role

## Outcome

Run a small Python application on EC2 that retrieves an RDS credential from Secrets Manager, connects to a private MySQL database over TLS and reads test data. The application source and EC2 user data contain no password. Remove permission, observe the failure, and restore access.

**Time:** 90–120 minutes. **Costs:** One small EC2 instance, public IPv4, EBS, one Single-AZ RDS instance/storage/backups, one secret and API requests. RDS provisioning can take 15–30 minutes or longer. Delete resources when finished.

No earlier lab is required. This disposable demonstration uses the database administrator credential to keep setup short. Real applications should use a dedicated database user with only the SQL privileges they require.

```text
EC2 role → Secrets Manager → credential in process memory
EC2 application → TLS/MySQL 3306 → private RDS
```

## Prerequisites

- Sandbox access to VPC, EC2, SSM, RDS, Secrets Manager, IAM role/inline-policy creation and PassRole.
- One Region, e.g. `ap-south-1`, with two AZs and `db.t3.micro` or `db.t4g.micro` available for MySQL.
- Keep a resource worksheet. Store the temporary database password in your password manager, never in the worksheet, screenshots or terminal commands.
- Shell commands run on **EC2 through Session Manager**, unless a step explicitly says CloudShell.

## Lab 1 - Create the network

1. Create **VPC only** `lab05-vpc`, CIDR `10.45.0.0/16`, no IPv6.
2. Enable DNS resolution and DNS hostnames under VPC **Actions → Edit VPC settings**.
3. Create these subnets:

| Name | AZ | CIDR |
|---|---|---|
| lab05-client-a | AZ-A | 10.45.1.0/24 |
| lab05-db-a | AZ-A | 10.45.11.0/24 |
| lab05-db-b | Different AZ-B | 10.45.12.0/24 |

4. Enable auto-assign public IPv4 only on `lab05-client-a`.
5. Create `lab05-igw` and attach it to the VPC.
6. Create `lab05-public-rt`; add `0.0.0.0/0 → lab05-igw`; associate only the client subnet.
7. Create `lab05-db-rt`; keep only the local route; associate both DB subnets.
8. Create SG `lab05-client-sg`: no inbound, default outbound allow-all.
9. Create SG `lab05-db-sg`: inbound MySQL/TCP 3306 from **lab05-client-sg**, default outbound allow-all.

RDS needs no public IP or NAT gateway for this exercise. EC2 uses outbound internet access for SSM, Secrets Manager and package downloads.

## Lab 2 - Create the private database

1. Open **RDS → Subnet groups → Create**. Name `lab05-db-subnets`, select the VPC and both DB subnets in their two AZs.
2. Open **Databases → Create database → Standard create**.
3. Engine: **MySQL**; choose a currently supported **8.4** version if available. If unavailable, select a supported non-extended-support version offered in your Region.
4. Template: **Dev/Test**; deployment: **Single DB instance / Single-AZ**, not a cluster.
5. Identifier `lab05-mysql`; username `labadmin`.
6. Credentials: **Self managed**. Generate a strong temporary password in your password manager and enter it in the console. We will store that same value in Secrets Manager in the next step.
7. Instance class: **Burstable → db.t3.micro**, or `db.t4g.micro` if that is the available small class. Review the displayed estimate; do not accept an unexpectedly large default.
8. Storage: gp3, 20 GiB where offered; disable storage autoscaling for this bounded dataset. Keep encryption enabled using the default RDS key.
9. Connectivity: do not automatically connect an EC2 resource; select `lab05-vpc`, subnet group `lab05-db-subnets`, **Public access: No**, and only `lab05-db-sg`. Port 3306.
10. Additional configuration: initial database name `lab05db`; automated backup retention **1 day**; disable deletion protection for this disposable lab.
11. Disable optional paid monitoring features such as Enhanced Monitoring/advanced Database Insights for the lab if offered. Keep basic metrics.
12. Review cost and create. Wait for **Available**. Copy the database endpoint (hostname only, no `https://`).

## Lab 3 - Store the credential

1. Open **Secrets Manager → Store a new secret** in the same Region.
2. Select **Other type of secret**, then **Key/value pairs**.
3. Enter:

| Key | Value |
|---|---|
| username | labadmin |
| password | The exact RDS password from your password manager |
| host | Your RDS endpoint |
| port | 3306 |
| dbname | lab05db |

4. Encryption key: default **aws/secretsmanager**. Do not select a customer-managed key for this first exercise.
5. Name: `lab05/database`.
6. Leave automatic rotation disabled; finish creation.
7. Copy the **secret ARN**, including its generated suffix. Do not copy the secret value to your worksheet.

Storing an arbitrary secret does not change the RDS password. The stored password must match the database. Rotation is a separate coordinated operation and is not performed here.

## Lab 4 - Create the application role

1. In IAM create role `lab05-ec2-role` with trusted service **EC2**.
2. Attach `AmazonSSMManagedInstanceCore`.
3. Add inline JSON policy `lab05-read-secret`, replacing the ARN below with the **complete** secret ARN:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "secretsmanager:GetSecretValue",
    "Resource": "YOUR-COMPLETE-SECRET-ARN"
  }]
}
```

The role can read this secret, not list/read all secrets or modify them. This lab uses the AWS-managed secret key; customer-managed encryption keys require additional key-policy/IAM consideration.

## Lab 5 - Launch and prepare EC2

1. Launch `lab05-client` using standard **Amazon Linux 2023 x86_64**, `t3.micro`, no key pair.
2. Select the VPC, `lab05-client-a`, public IP enabled, only `lab05-client-sg`.
3. Use 8 GiB gp3 root storage, delete-on-termination enabled.
4. Advanced details: role `lab05-ec2-role`, IMDSv2 required. Leave user data blank.
5. Wait for status checks and connect using **Connect → Session Manager**.
6. Run:

```bash
sudo dnf install -y python3 python3-pip
mkdir -p "$HOME/lab05"
cd "$HOME/lab05"
python3 -m venv .venv
.venv/bin/pip install boto3 'PyMySQL[rsa]'
curl --fail --show-error --location \
  https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
  --output rds-ca.pem
test -s rds-ca.pem && echo 'RDS CA bundle downloaded'
```

The virtual environment keeps dependencies separate from the system Python. The CA bundle lets the client verify the database's TLS certificate.

## Lab 6 - Create the application

Paste this entire block in the same EC2 terminal:

```bash
cat > "$HOME/lab05/app.py" <<'PY'
import json
import os
import sys
from pathlib import Path

import boto3
import pymysql
from botocore.exceptions import BotoCoreError, ClientError

try:
    sm = boto3.client('secretsmanager', region_name=os.environ['AWS_DEFAULT_REGION'])
    result = sm.get_secret_value(SecretId=os.environ['LAB05_SECRET_ARN'])
    secret = json.loads(result['SecretString'])
    # Retrieve once per short process, not once per query. Never log secret contents.
    with pymysql.connect(
        host=secret['host'], port=int(secret['port']),
        user=secret['username'], password=secret['password'],
        database=secret['dbname'], connect_timeout=10,
        read_timeout=10, write_timeout=10, autocommit=True,
        ssl_ca=str(Path(__file__).with_name('rds-ca.pem')),
        ssl_verify_cert=True, ssl_verify_identity=True,
    ) as connection:
        with connection.cursor() as cursor:
            cursor.execute('CREATE TABLE IF NOT EXISTS proof (id INT PRIMARY KEY, message VARCHAR(100))')
            cursor.execute('INSERT IGNORE INTO proof VALUES (%s, %s)', (1, 'Secret-backed connection works'))
            cursor.execute('SELECT id, message FROM proof ORDER BY id')
            rows = cursor.fetchall()
            cursor.execute("SHOW SESSION STATUS LIKE 'Ssl_cipher'")
            cipher = cursor.fetchone()[1]
    print('Database connection: SUCCESS')
    print('TLS cipher:', cipher)
    print('Rows:', rows)
except ClientError as error:
    print('AWS request failed:', error.response['Error']['Code'], file=sys.stderr)
    sys.exit(1)
except (BotoCoreError, pymysql.MySQLError, KeyError, ValueError) as error:
    # Avoid printing raw connection details or secret values.
    print('Application failed:', type(error).__name__, file=sys.stderr)
    sys.exit(1)
PY
export AWS_DEFAULT_REGION=ap-south-1
export LAB05_SECRET_ARN='YOUR-COMPLETE-SECRET-ARN'
"$HOME/lab05/.venv/bin/python" "$HOME/lab05/app.py"
```

Replace the Region and secret ARN before running the last command. An ARN identifies the secret; it is not the password.

Expected output includes:

```text
Database connection: SUCCESS
TLS cipher: <a non-empty cipher name>
Rows: ((1, 'Secret-backed connection works'),)
```

Rerun the final command. It should still show one row, because the primary key and `INSERT IGNORE` prevent inserting a second copy of the demonstration row.

## Lab 7 - Verify the credential is external to the code

1. Inspect the source with `cat "$HOME/lab05/app.py"`. The code reads `secret['password']`; it contains no literal password.
2. In EC2 select the instance → **Actions → Instance settings → Edit user data** (or view user data). It should be empty.
3. Confirm the role has only the single-secret read policy plus SSM permissions.
4. Do not print the secret JSON or run a command that returns `SecretString` to prove success. The successful SQL query is the proof.

The password exists in process memory while connecting. Secrets Manager protects storage/distribution; it does not make a credential invisible to a sufficiently privileged process on the host.

## Lab 8 - Reproduce an IAM failure

1. In IAM, delete only the inline policy `lab05-read-secret`; keep SSM permissions.
2. Allow propagation, then start a new application process with the same final command.
3. Expected: `AWS request failed: AccessDeniedException` and a nonzero exit status. Run `echo $?` immediately afterward to see it.
4. Recreate the exact inline policy from Lab 4 and retry after propagation.
5. Expected: database query succeeds again without changing application code or entering a password on EC2.

## Troubleshooting

| Symptom | Action |
|---|---|
| SSM cannot connect | Check instance role, public IP, client-subnet route/IGW, outbound HTTPS and console-user session permissions. |
| AccessDeniedException | Check complete secret ARN, Region, role policy and propagation. |
| ResourceNotFoundException | Check secret name/ARN and Region; ensure it is not scheduled for deletion. |
| OperationalError / connection timeout | Check endpoint hostname, RDS Available, port 3306 and DB SG source is client SG. |
| Authentication fails | Compare secret username/password with the RDS credentials. Editing the secret alone does not update RDS. |
| Unknown database | Confirm initial DB name was `lab05db`; if omitted, use the RDS console Query Editor only if supported, or a MySQL client to create it before rerunning. See the explicit recovery command below. |
| TLS error | Redownload the official CA bundle, verify system time and use the actual RDS endpoint. Do not disable certificate verification. |

If you omitted the initial database, edit `app.py`: temporarily remove `database=secret['dbname'],` from the connection arguments, and insert `cursor.execute('CREATE DATABASE IF NOT EXISTS lab05db')` followed by `cursor.execute('USE lab05db')` before the table-creation statement. Run once, then restore the original program from Lab 6. This uses the same secret and avoids a password in the shell.

## Cleanup

1. Terminate EC2 and verify root EBS deletion.
2. Delete `lab05-mysql`: disable deletion protection if enabled; for this disposable data, uncheck final snapshot and retained automated backups. Confirm deletion and wait until the instance is gone. If you chose to retain snapshots/backups, delete those lab copies separately.
3. Delete `lab05-db-subnets` after database deletion.
4. In Secrets Manager choose `lab05/database → Actions → Delete secret`, select the minimum offered recovery window (normally 7 days), and schedule deletion. Record the scheduled deletion date; it is pending deletion, not immediately erased. Do not use this name for a new secret until deletion completes, or restore it if needed.
5. Delete the EC2 role and unused instance profile.
6. Delete DB SG first, then client SG; delete the three subnets, custom route tables, detach/delete IGW and delete VPC.
7. Verify RDS instances, retained backups, snapshots and EC2 storage for this lab are absent, and the secret is scheduled for deletion.

## Completion checklist

- [ ] Private RDS database accessible only from the client SG.
- [ ] Application reads the secret using its EC2 role.
- [ ] TLS query returns the expected row.
- [ ] No password in code, user data or shell commands.
- [ ] Permission removal and recovery verified.
- [ ] Resources cleaned up; secret deletion date recorded.

## References

- [Retrieve a secret with Python](https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secrets-python.html)
- [RDS TLS certificates](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html)
- [Deleting a secret](https://docs.aws.amazon.com/secretsmanager/latest/userguide/manage_delete-secret.html)
