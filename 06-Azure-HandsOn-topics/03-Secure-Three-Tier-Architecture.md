# Lab 03 - Public Gateway, Private Application VMs and Private MySQL

**Read first:** [Brief notes - concepts for this lab](03-Secure-Three-Tier-Architecture-brief-notes.md)

**How to work:** Use Azure portal for resource creation, settings, verification and cleanup. Follow the guest-script instructions only when a step needs software running inside a VM.

## Outcome

Build a working database-backed page through Application Gateway while application VMs and MySQL have no public IP. Each VM retrieves its credential from Key Vault using managed identity.

**Time:** 2–3 hours. **Costs:** Application Gateway Standard_v2, NAT Gateway/public IP, two VMs/disks, MySQL and Key Vault. Delete after validation. This is a teaching architecture, not a complete production security baseline: the frontend uses HTTP with synthetic data and a small demonstration Python server.

```text
Internet → Application Gateway → private app-a / app-b → private MySQL
                                      | managed identities
                                      +→ Key Vault
Private apps → NAT Gateway → package repositories / Azure service endpoints
```

## Prerequisites

- Contributor plus role-assignment permission on Key Vault. Compute/Network/DBforMySQL/KeyVault providers registered.
- Access to [Azure portal](https://portal.azure.com) with your learning subscription selected. Keep a local worksheet of the resource names you choose.
- Password manager for the temporary DB administrator credential. Only synthetic data is used.

## Lab 1 - Create three subnet roles and explicit outbound access

1. In [Azure portal](https://portal.azure.com), search **Resource groups → Create**. Select your learning subscription, name `azlab03-three-tier`, Region **East US 2** (or the supported Region chosen for this lab). Select **Review + create → Create**.
2. Open the group → **Tags**; add `Project=AzureHandsOn` and `Lab=03`; **Apply**. Keep all resources below in this subscription, group and Region. Record names in your lab worksheet.

1. Search **Virtual networks → Create**; select the lab group and Region, name `lab03-vnet`.
2. On **IP addresses**, replace the default address space with `10.53.0.0/16`. Remove the default subnet if it conflicts. Add these subnets (name → address range): `gateway` → `10.53.0.0/24`; `app` → `10.53.1.0/24`; `database` → `10.53.2.0/24`. Leave optional security services disabled for this lab.
3. **Review + create → Create**; wait for deployment success. Reopen **Subnets** and check each range.

Open **Subnets → database**; set **Subnet delegation → Microsoft.DBforMySQL/flexibleServers → Save**.

1. Search **NAT gateways → Create**; lab group/Region; name `lab03-nat`, Standard SKU.
2. **Outbound IP → Create a new public IP address**: `lab03-nat-ip`, Standard, static.
3. **Subnet**: VNet `lab03-vnet`, select `app`. **Review + create → Create**. Verify the subnet shows this NAT gateway. This supplies explicit outbound access for private VMs; it does not open inbound access.

1. Search **Network security groups → Create**; use `lab03-nsg`, lab group and Region. Open it after deployment.
2. Open **Inbound security rules → Add**: Source **IP Addresses**, `10.53.0.0/24`; source ports `*`; Destination **Any**; Service **Custom**; destination port `8080`; protocol **TCP**; action **Allow**; priority `100`; name `AllowApplication`; **Add**.
3. Add another inbound rule: Source **Any**, source ports `*`, Destination **Any**, destination port `8080`, TCP, **Deny**, priority `110`, name `DenyOtherApplication`. This overrides the default VNet allow for this port.
4. Open **Subnets → Associate**; select `lab03-vnet` and `app`; **OK**. Retain default rules, including AzureLoadBalancer health probes. Do not add public SSH/RDP rules. Verify association before creating VMs.

Keep the delegated database subnet's default service networking; do not add a deny-all rule that blocks managed-service traffic. The app subnet is shared across the two VM zones—Azure subnets are regional, unlike AWS AZ-specific subnets.

## Lab 2 - Provision the private database

1. Portal **MySQL flexible servers → Create**, resource group `azlab03-three-tier`, same Region.
2. Globally unique name `lab03mysql-SUFFIX`; supported MySQL 8.0; authentication MySQL; admin `labadmin`; strong password stored privately.
3. Select Burstable B1ms or the smallest offered suitable class, minimum offered storage, 7-day backup retention, HA Disabled. Review cost.
4. Networking **Private access (VNet Integration)**, `lab03-vnet/database`; create a new private DNS zone and VNet link through the wizard.
5. Create and wait for Ready. Record its full hostname. Do not enable public access.

For zone resilience of the whole application, the DB would need supported zone-redundant HA. Two app VMs alone do not remove the non-HA database failure point.

## Lab 3 - Store the credential and create identities

1. Search **Key vaults → Create**; lab group/Region; globally unique name `azlab03-yourinitials1234`; Standard tier; soft-delete retention `7` days. Record the name.
2. **Access configuration**: Azure role-based access control. **Networking**: public access enabled for this exercise. **Review + create → Create**.

1. Open **your new vault → Access control (IAM) → Add → Add role assignment**.
2. Search/select **Key Vault Secrets Officer → Next**. Assign access to **User, group, or service principal**. **Select members** → your signed-in user. **Select → Review + assign** (confirm again if prompted).
3. Open **Role assignments** and verify role, member and scope. Allow several minutes for propagation. A Contributor role alone cannot assign roles; use an account with the required role-assignment permission.

1. After propagation, open the vault → **Secrets → Generate/Import**, name `database`.
2. Enter a JSON value in the portal, replacing values with the actual DB settings. Do not run this JSON as a shell command or save the filled value in source control:

```json
{"host":"YOUR-SERVER.mysql.database.azure.com","username":"labadmin","password":"YOUR-DB-PASSWORD"}
```

3. Save. The password must match the DB; storing a secret does not change DB authentication.
4. Create VMs without public IPs in the portal:

1. Search **Virtual machines → Create → Azure virtual machine**. Select lab subscription/group/Region; name `lab03-app-a`; image **Ubuntu Server 22.04 LTS, x64**; size **Standard_B2s** (select an available small equivalent if necessary). Availability options **Availability zone**, select **1** only. Username `azureuser`, authentication **SSH public key**, generate a new key pair; public inbound ports **None**.
2. **Disks**: OS disk **Standard SSD LRS**. **Networking**: select `lab03-vnet`, subnet `app`; public IP **None**; NIC network security group **None** because the subnet NSG already applies. Leave load balancing off.
3. Under **Management**, enable **System assigned managed identity**. Disable optional paid services such as Backup for this VM unless this lab asks for them. **Review + create → Create**; download the private key when prompted and store it securely.
4. Wait for deployment. Open **Overview** to record private IP and provisioning status. Open **Identity → System assigned**, confirm **On**, and record Object (principal) ID. Use **Operations → Run command → RunShellScript** for the guest scripts in this lab; paste the entire specified block and select **Run**. These Linux commands execute inside the VM, not on your computer.

1. Search **Virtual machines → Create → Azure virtual machine**. Select lab subscription/group/Region; name `lab03-app-b`; image **Ubuntu Server 22.04 LTS, x64**; size **Standard_B2s** (select an available small equivalent if necessary). Availability options **Availability zone**, select **2** only. Username `azureuser`, authentication **SSH public key**, generate a new key pair; public inbound ports **None**.
2. **Disks**: OS disk **Standard SSD LRS**. **Networking**: select `lab03-vnet`, subnet `app`; public IP **None**; NIC network security group **None** because the subnet NSG already applies. Leave load balancing off.
3. Under **Management**, enable **System assigned managed identity**. Disable optional paid services such as Backup for this VM unless this lab asks for them. **Review + create → Create**; download the private key when prompted and store it securely.
4. Wait for deployment. Open **Overview** to record private IP and provisioning status. Open **Identity → System assigned**, confirm **On**, and record Object (principal) ID. Use **Operations → Run command → RunShellScript** for the guest scripts in this lab; paste the entire specified block and select **Run**. These Linux commands execute inside the VM, not on your computer.

1. Open **your dedicated lab vault → Access control (IAM) → Add → Add role assignment**.
2. Search/select **Key Vault Secrets User → Next**. Assign access to **Managed identity**. **Select members** → subscription → Virtual machine → lab03-app-a and lab03-app-b. **Select → Review + assign** (confirm again if prompted).
3. Open **Role assignments** and verify role, member and scope. Allow several minutes for propagation. A Contributor role alone cannot assign roles; use an account with the required role-assignment permission.

This assignment covers this dedicated vault; it contains only the lab database secret. Do not store unrelated secrets in it. The role grants secret reads, not secret editing.

## Lab 4 - Install the application on both VMs

Open each application VM → **Run command → RunShellScript**. Replace `YOUR-VAULT-NAME` with your recorded vault name (not a secret), paste the entire block below and select **Run**. Repeat on both VMs. The code installs the guest application; resource creation uses the portal:

```bash
set -eu
apt-get update
apt-get install -y python3-venv ca-certificates
install -d /opt/lab03
python3 -m venv /opt/lab03/venv
/opt/lab03/venv/bin/pip install azure-identity azure-keyvault-secrets 'PyMySQL[rsa]'
cat > /opt/lab03/app.py <<'PY'
import json
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer
import pymysql
from azure.identity import ManagedIdentityCredential
from azure.keyvault.secrets import SecretClient

client = SecretClient(vault_url='https://YOUR-VAULT-NAME.vault.azure.net',
                      credential=ManagedIdentityCredential())

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200); self.end_headers(); self.wfile.write(b'healthy'); return
        try:
            secret = json.loads(client.get_secret('database').value)
            with pymysql.connect(host=secret['host'], user=secret['username'],
                password=secret['password'], connect_timeout=5, read_timeout=5,
                ssl_ca='/etc/ssl/certs/ca-certificates.crt',
                ssl_verify_cert=True, ssl_verify_identity=True) as connection:
                with connection.cursor() as cursor:
                    cursor.execute('SELECT 1')
                    assert cursor.fetchone()[0] == 1
            body = f'<h1>Azure private application</h1><p>{socket.gethostname()}</p><p>Database: SUCCESS</p>'
            self.send_response(200)
        except Exception as error:
            print('Dependency failure:', type(error).__name__, flush=True)
            body = '<h1>Dependency unavailable</h1>'
            self.send_response(503)
        self.send_header('Content-Type', 'text/html'); self.end_headers()
        self.wfile.write(body.encode())

HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
PY
cat > /etc/systemd/system/lab03.service <<'UNIT'
[Unit]
After=network-online.target
Wants=network-online.target
[Service]
ExecStart=/opt/lab03/venv/bin/python /opt/lab03/app.py
Restart=on-failure
User=nobody
WorkingDirectory=/opt/lab03
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now lab03
curl --retry 5 --retry-connrefused --retry-delay 3 -fsS http://127.0.0.1:8080/health
```

The simple server retrieves a secret per page for visible teaching behavior. A production service should use an appropriate web server, connection pooling and a bounded secret cache/refresh strategy.

## Lab 5 - Add the public gateway

1. Open each VM **Overview / Networking** and record its **private** IP.
2. Search **Application gateways → Create**; lab group/Region; name `lab03-gateway`; tier **Standard V2**; disable autoscaling for this exercise and set instance count `2`. Select `lab03-vnet`, dedicated subnet `gateway`.
3. **Frontends**: Public; **Add new** Standard static public IP `lab03-gateway-ip`.
4. **Backends → Add a backend pool**: name `web-pool`, add targets now, target type **IP address or FQDN**; enter both VM private IPs. **Add**.
5. **Configuration → Add a routing rule**: name `web-rule`, priority `100`. Listener `http-listener`, frontend Public, protocol HTTP, port `80`, listener type Basic.
6. **Backend targets**: target `web-pool`; **Add new backend setting** `web-settings`, HTTP, port `8080`, cookie affinity disabled, request timeout `20` seconds; keep host-name override off. Save setting and rule.
7. **Review + create → Create**; wait for successful deployment. Record the public frontend IP from Overview. Continue with the custom probe below.

1. In Gateway **Health probes**, create `lab03-health`, HTTP, host `127.0.0.1`, path `/health`, default thresholds.
2. Associate it with the HTTP backend setting. Wait for both Backend health entries to be Healthy.
3. Browse `http://GATEWAY-PUBLIC-IP/`. Expect a VM hostname and **Database: SUCCESS**.
4. Refresh several times; record both app hostnames if observed. Strict alternation is not guaranteed.
5. On each VM Overview verify there is **no public IP**. On MySQL Networking verify private access.

## Lab 6 - Diagnose two different failure types

1. Use app-a **Run command** to run `systemctl stop lab03`. Observe the failed probe and continued service from app-b.
2. Run `systemctl start lab03`; wait for Healthy again.
3. In Key Vault temporarily disable the current `database` secret version. New page requests should return a dependency failure (503), while `/health` remains 200.
4. Re-enable the same version and retry until the database-backed page succeeds.
5. Explain the distinction: `/health` proves this process is serving; it does not prove every dependency is healthy. Readiness/dependency probes require careful design to avoid removing all instances during a shared DB outage.

## Troubleshooting

| Symptom | Correction |
|---|---|
| Install/Run Command stalls | NAT association on app subnet, healthy VM agent, no outbound deny rule. |
| Gateway 502 | Backend port 8080, probe association, NSG source, process status. |
| Page 503 | Run `journalctl -u lab03 -n 30 --no-pager`; check exception class, secret enabled, RBAC and DB hostname/password. |
| DB hostname does not resolve | Verify private DNS zone is linked to `lab03-vnet`. |
| Secret forbidden | Verify each VM's principal has Secrets User on the exact secret. |

## Cleanup

Open **Resource groups → azlab03-three-tier**, review the resources, select **Delete resource group**, type the group name and confirm. Wait for deletion success and refresh the group list to verify absence. Delete a lab-only private DNS zone placed outside the group if applicable. Record the Key Vault soft-deleted state; do not weaken purge protection. Verify gateway, NAT, public IPs, database and VM disks are removed.

## Completion checklist

- [ ] Public entry point reaches a real private database through private app VMs.
- [ ] Managed identities retrieve the secret; no DB password in VM source/user data.
- [ ] Process failure and shared dependency failure distinguished.
- [ ] Remaining production requirements identified: TLS, WAF, DB HA, monitoring and robust runtime.
- [ ] Cleanup complete.

## References

- [NAT Gateway design](https://learn.microsoft.com/en-us/azure/nat-gateway/nat-gateway-design)
- [Application Gateway backend health](https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-probe-overview)
- [Private MySQL networking](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concepts-networking-vnet)
- [Key Vault Python client](https://learn.microsoft.com/en-us/python/api/overview/azure/keyvault-secrets-readme)
