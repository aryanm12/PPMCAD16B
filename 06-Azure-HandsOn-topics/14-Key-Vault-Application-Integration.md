# Lab 14 - Key Vault and a Managed-Identity Application

**Read first:** [Brief notes - concepts for this lab](14-Key-Vault-Application-Integration-brief-notes.md)

**How to work:** Use Azure portal for resource creation, settings, verification and cleanup. Follow the guest-script instructions only when a step needs software running inside a VM.

## Outcome

Create a secret, let one VM read it using managed identity, and run a Python application that uses the retrieved value without printing it. Remove the role to reproduce an authorization failure, then restore it.

**Time:** 50–75 minutes. **Costs:** VM, disk, public IP and Key Vault operations. No prior lab is required.

This focused exercise uses a synthetic application credential. Guide 03 applies the same pattern to an actual MySQL-backed web application.

## Prerequisites

- Contributor plus permission to assign Key Vault RBAC roles.
- Access to [Azure portal](https://portal.azure.com) with your learning subscription selected. Keep a local worksheet of the resource names you choose.
- Registered Compute, Network, KeyVault providers. Do not use a production/shared vault.

## Lab 1 - Create a vault and VM

1. In [Azure portal](https://portal.azure.com), search **Resource groups → Create**. Select your learning subscription, name `azlab14-keyvault`, Region **East US 2** (or the supported Region chosen for this lab). Select **Review + create → Create**.
2. Open the group → **Tags**; add `Project=AzureHandsOn` and `Lab=14`; **Apply**. Keep all resources below in this subscription, group and Region. Record names in your lab worksheet.

1. Search **Virtual networks → Create**; select the lab group and Region, name `lab14-vnet`.
2. On **IP addresses**, replace the default address space with `10.64.0.0/16`. Remove the default subnet if it conflicts. Add these subnets (name → address range): `app` → `10.64.1.0/24`. Leave optional security services disabled for this lab.
3. **Review + create → Create**; wait for deployment success. Reopen **Subnets** and check each range.

1. Search **Network security groups → Create**; use `lab14-nsg`, lab group and Region. Open it after deployment.
4. Open **Subnets → Associate**; select `lab14-vnet` and `app`; **OK**. Retain default rules, including AzureLoadBalancer health probes. Do not add public SSH/RDP rules. Verify association before creating VMs.

1. Search **Virtual machines → Create → Azure virtual machine**. Select lab subscription/group/Region; name `lab14-vm`; image **Ubuntu Server 22.04 LTS, x64**; size **Standard_B2s** (select an available small equivalent if necessary). Use no infrastructure redundancy requirement for this single test VM. Username `azureuser`, authentication **SSH public key**, generate a new key pair; public inbound ports **None**.
2. **Disks**: OS disk **Standard SSD LRS**. **Networking**: select `lab14-vnet`, subnet `app`; public IP **Create new → Standard, static**; NIC network security group **None** because the subnet NSG already applies. Leave load balancing off.
3. Under **Management**, enable **System assigned managed identity**. Disable optional paid services such as Backup for this VM unless this lab asks for them. **Review + create → Create**; download the private key when prompted and store it securely.
4. Wait for deployment. Open **Overview** to record private IP and provisioning status. Open **Identity → System assigned**, confirm **On**, and record Object (principal) ID. Use **Operations → Run command → RunShellScript** for the guest scripts in this lab; paste the entire specified block and select **Run**. These Linux commands execute inside the VM, not on your computer.

Search **Key vaults → Create**. Lab group/Region, unique name `azlab14-yourinitials1234`, Standard tier, soft-delete retention `7` days. On **Access configuration** select **Azure role-based access control**; keep public networking enabled for this lab; **Review + create → Create**. Record vault name.

1. Open **your new vault → Access control (IAM) → Add → Add role assignment**.
2. Search/select **Key Vault Secrets Officer → Next**. Assign access to **User, group, or service principal**. **Select members** → your signed-in user. **Select → Review + assign** (confirm again if prompted).
3. Open **Role assignments** and verify role, member and scope. Allow several minutes for propagation. A Contributor role alone cannot assign roles; use an account with the required role-assignment permission.

If your user cannot be queried from the directory, set `ME` to your user Object ID from Entra ID. The VM public IP gives outbound connectivity; no SSH/HTTP inbound rule is created.

## Lab 2 - Store a synthetic credential

1. Wait for role propagation. Open **Key Vault → your vault → Objects → Secrets → Generate/Import**.
2. Upload option Manual; name `application-token`; value: generate at least 24 random characters in your password manager.
3. Leave enabled and create. Enter the value only in the secret creation field; keep it out of source code, screenshots and your worksheet.
4. Open the secret's current version and record only its **identifier/URL**, not its value.
5. In the portal grant the VM read permission on this dedicated lab vault:

1. Open **your dedicated lab vault → Access control (IAM) → Add → Add role assignment**.
2. Search/select **Key Vault Secrets User → Next**. Assign access to **Managed identity**. **Select members** → subscription → Virtual machine → lab14-vm. **Select → Review + assign** (confirm again if prompted).
3. Open **Role assignments** and verify role, member and scope. Allow several minutes for propagation. A Contributor role alone cannot assign roles; use an account with the required role-assignment permission.

Scope is this dedicated vault, which contains only this exercise’s secret. This role reads secrets but cannot create or change them. Do not add unrelated secrets to this vault.

Secrets User reads values; it does not allow changing the secret. The operator's Secrets Officer role is intentionally separate.

## Lab 3 - Run the application

Open **VM → Run command → RunShellScript**. Replace `YOUR-VAULT-NAME` below and run the whole block:

```bash
install -d -m 700 /opt/lab14
cat > /opt/lab14/app.py <<'PY'
import json
import urllib.request
import urllib.error
import sys

vault = 'YOUR-VAULT-NAME'
try:
    url = ('http://169.254.169.254/metadata/identity/oauth2/token'
           '?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net')
    req = urllib.request.Request(url, headers={'Metadata': 'true'})
    with urllib.request.urlopen(req, timeout=10) as response:
        token = json.load(response)['access_token']
    url = f'https://{vault}.vault.azure.net/secrets/application-token?api-version=7.4'
    req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})
    with urllib.request.urlopen(req, timeout=15) as response:
        credential = json.load(response)['value']
    # Demonstration use: validate credential shape without logging its content.
    if len(credential) < 24:
        raise ValueError('Credential does not meet this lab requirement')
    print('Secret retrieved: YES')
    print('Credential validation: PASS')
except urllib.error.HTTPError as error:
    print('Secret request failed; HTTP', error.code)
    sys.exit(1)
except Exception as error:
    print('Application failed:', type(error).__name__)
    sys.exit(1)
PY
chmod 600 /opt/lab14/app.py
python3 /opt/lab14/app.py
```

Expected: YES and PASS. The application uses a versionless secret URL, so a fresh run fetches the current version. It retrieves once per short process rather than once per business operation.

## Lab 4 - Verify failure and recovery

1. In the portal remove only the VM assignment:

Open **Vault → Access control (IAM) → Role assignments**. Select only **Key Vault Secrets User**, member **lab14-vm**, scope this vault → **Remove → Yes**. Keep your own Secrets Officer assignment.

2. Run `python3 /opt/lab14/app.py` through VM Run Command again after propagation. Expected HTTP 403. Cached authorization may delay the change; allow time before concluding it failed.
3. Restore permission:

1. Open **your dedicated lab vault → Access control (IAM) → Add → Add role assignment**.
2. Search/select **Key Vault Secrets User → Next**. Assign access to **Managed identity**. **Select members** → subscription → Virtual machine → lab14-vm. **Select → Review + assign** (confirm again if prompted).
3. Open **Role assignments** and verify role, member and scope. Allow several minutes for propagation. A Contributor role alone cannot assign roles; use an account with the required role-assignment permission.

4. Retry after propagation; expected PASS without editing application code.

## Lab 5 - Publish a new secret version

1. In the portal open the secret and choose **New Version**.
2. Enter a new random value of at least 24 characters. Save.
3. Record the new version identifier, without recording the value.
4. Rerun the application. It should pass using the latest version.

For a real database password/API key, changing Key Vault alone is not credential rotation: the database/provider must be changed in a coordinated way. Long-running applications also need a refresh/cache policy. This exercise changes only a synthetic credential.

## Lab 6 - Review the boundary

1. Inspect `/opt/lab14/app.py` via Run Command. It contains a vault name and secret name, but no stored credential.
2. Confirm the VM identity has Secrets User, not Secrets Officer.
3. Confirm no access policy was added under the older vault access-policy model; this lab consistently uses RBAC.
4. Record why a host administrator could still inspect process memory. Secret storage does not remove the need to secure the VM.

## Troubleshooting

| Symptom | Correction |
|---|---|
| 403 | Correct identity Object ID, dedicated-vault scope, role and propagation; also inspect vault firewall policy. |
| 404 | Check vault/secret name and whether a version was deleted/disabled. |
| Token failure | Run on the VM with system identity enabled, not on your own computer. |
| Timeout | Check VM outbound connectivity and vault networking settings. |
| Cannot create secret | Operator needs data-plane Secrets Officer; resource Contributor is not enough. |

## Cleanup

1. Open **Resource groups → azlab14-keyvault → Overview**. Review the complete resource list and confirm it contains only this exercise.
2. Select **Delete resource group**, type `azlab14-keyvault` to confirm, and select **Delete**.
3. Watch **Notifications** for successful deletion. Return to **Resource groups**, refresh, and verify the group is absent; also check **All resources** with the same subscription filter. If deletion failed, inspect the reported dependency/lock and resolve it before considering cleanup complete.

The vault can remain **soft-deleted** for its configured retention period, and its name may remain reserved. Open **Key Vaults → Manage deleted vaults** and record that state. Do not disable purge protection or purge shared vaults to finish this lab. If organization policy enforces longer retention, follow it. Verify all VM/disk/public-IP resources are removed even if the vault remains recoverable.

## Completion checklist

- [ ] No secret/token printed or embedded in source.
- [ ] Managed identity retrieves only the intended secret.
- [ ] Permission failure and restoration observed.
- [ ] New secret version consumed on a fresh run.
- [ ] Compute cleaned up and vault retention state recorded.

## References

- [Key Vault RBAC](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide)
- [Managed identities on VMs](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/how-to-use-vm-token)
- [Key Vault soft delete](https://learn.microsoft.com/en-us/azure/key-vault/general/soft-delete-overview)
