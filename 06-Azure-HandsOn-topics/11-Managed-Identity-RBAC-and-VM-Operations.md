# Lab 11 - Managed Identity, Scoped RBAC and VM Operations

**Read first:** [Brief notes - concepts for this lab](11-Managed-Identity-RBAC-and-VM-Operations-brief-notes.md)

**How to work:** Use Azure portal for resource creation, settings, verification and cleanup. Follow the guest-script instructions only when a step needs software running inside a VM.

## Outcome

Enable a VM's system-assigned identity, grant read access to one blob container and prove that reading another container and uploading are denied. Administer the VM with Run Command without opening SSH.

**Time:** 50–75 minutes. **Costs:** One small VM/disk/public IP and small Storage usage. No earlier lab is required.

## Prerequisites

- Contributor plus permission to assign roles at the storage account/container scope.
- Access to [Azure portal](https://portal.azure.com) with your learning subscription selected. Keep a local worksheet of the resource names you choose.
- Registered Compute, Network and Storage providers.
- Run Command executes as root. Use it only on your disposable VM; it is an administration mechanism, not an equivalent of an interactive Session Manager shell.

## Lab 1 - Create storage and a VM

1. In [Azure portal](https://portal.azure.com), search **Resource groups → Create**. Select your learning subscription, name `azlab11-identity`, Region **East US 2** (or the supported Region chosen for this lab). Select **Review + create → Create**.
2. Open the group → **Tags**; add `Project=AzureHandsOn` and `Lab=11`; **Apply**. Keep all resources below in this subscription, group and Region. Record names in your lab worksheet.

1. Search **Storage accounts → Create**. Select lab subscription/group/Region. Choose a globally unique name such as `azlab11yourinitials1234` (3–24 lowercase letters/digits); record your actual name. Performance **Standard**, redundancy **LRS**, general-purpose v2.
2. On **Advanced**, keep secure transfer required, minimum TLS **1.2**, and **Allow enabling anonymous access on individual containers** disabled. For this initial setup, **Networking → Public network access → Enable from all networks**. Private containers still require authorization.
3. **Review + create → Create**. Open **Overview** and verify deployment success. Use your recorded name wherever the guide says `YOUR-STORAGE-ACCOUNT`.

1. Search **Virtual networks → Create**; select the lab group and Region, name `lab11-vnet`.
2. On **IP addresses**, replace the default address space with `10.61.0.0/16`. Remove the default subnet if it conflicts. Add these subnets (name → address range): `client` → `10.61.1.0/24`. Leave optional security services disabled for this lab.
3. **Review + create → Create**; wait for deployment success. Reopen **Subnets** and check each range.

1. Search **Network security groups → Create**; use `lab11-nsg`, lab group and Region. Open it after deployment.
4. Open **Subnets → Associate**; select `lab11-vnet` and `client`; **OK**. Retain default rules, including AzureLoadBalancer health probes. Do not add public SSH/RDP rules. Verify association before creating VMs.

1. Search **Virtual machines → Create → Azure virtual machine**. Select lab subscription/group/Region; name `lab11-vm`; image **Ubuntu Server 22.04 LTS, x64**; size **Standard_B2s** (select an available small equivalent if necessary). Use no infrastructure redundancy requirement for this single test VM. Username `azureuser`, authentication **SSH public key**, generate a new key pair; public inbound ports **None**.
2. **Disks**: OS disk **Standard SSD LRS**. **Networking**: select `lab11-vnet`, subnet `client`; public IP **Create new → Standard, static**; NIC network security group **None** because the subnet NSG already applies. Leave load balancing off.
3. Under **Management**, enable **System assigned managed identity**. Disable optional paid services such as Backup for this VM unless this lab asks for them. **Review + create → Create**; download the private key when prompted and store it securely.
4. Wait for deployment. Open **Overview** to record private IP and provisioning status. Open **Identity → System assigned**, confirm **On**, and record Object (principal) ID. Use **Operations → Run command → RunShellScript** for the guest scripts in this lab; paste the entire specified block and select **Run**. These Linux commands execute inside the VM, not on your computer.

The public IP supplies explicit outbound access; the NSG has no Internet inbound allow rule. The default VNet rules still allow VNet-internal traffic.

Record storage name and VM identity:

1. Open **your storage account → Access control (IAM) → Add → Add role assignment**.
2. Search/select **Storage Blob Data Contributor → Next**. Assign access to **User, group, or service principal**. **Select members** → your signed-in user. **Select → Review + assign** (confirm again if prompted).
3. Open **Role assignments** and verify role, member and scope. Allow several minutes for propagation. A Contributor role alone cannot assign roles; use an account with the required role-assignment permission.

If directory lookup is blocked, copy your own **Object ID** from **Microsoft Entra ID → Users → your user** and set `ME` to it. For a service-principal session use that principal's ID/type instead; this guide's default is an interactive user.

## Lab 2 - Upload two sample blobs

Allow a few minutes for RBAC propagation, then:

1. On your computer, open a plain-text editor and save `message.txt` containing `Managed identity read works`. In Windows Save As, choose **All files** to avoid a hidden `.txt` suffix.
2. In the storage account open **Data storage → Containers → + Container**, name `allowed`, anonymous access **Private**, **Create** (skip creation if it already exists).
3. Open the container; choose **Switch to Microsoft Entra user account** if the page shows access-key authentication. Select **Upload → Browse for files**, choose `message.txt`, then **Upload**. Refresh and confirm the blob name. Select the blob → **Download** and open it; verify the original content.

1. On your computer, open a plain-text editor and save `message.txt` containing `Managed identity read works`. In Windows Save As, choose **All files** to avoid a hidden `.txt` suffix.
2. In the storage account open **Data storage → Containers → + Container**, name `restricted`, anonymous access **Private**, **Create** (skip creation if it already exists).
3. Open the container; choose **Switch to Microsoft Entra user account** if the page shows access-key authentication. Select **Upload → Browse for files**, choose `message.txt`, then **Upload**. Refresh and confirm the blob name. Select the blob → **Download** and open it; verify the original content.

1. Open **Storage account → Containers → allowed → Access control (IAM) → Add → Add role assignment**.
2. Search/select **Storage Blob Data Reader → Next**. Assign access to **Managed identity**. **Select members** → subscription → Virtual machine → lab11-vm. **Select → Review + assign** (confirm again if prompted).
3. Open **Role assignments** and verify role, member and scope. Allow several minutes for propagation. A Contributor role alone cannot assign roles; use an account with the required role-assignment permission.

Do not grant the VM your broader Blob Data Contributor role. System-assigned identity is tied to that VM's lifecycle.

## Lab 3 - Run identity-authenticated requests on the VM

Open **VM → Run command → RunShellScript**. Paste the following after replacing `YOUR-STORAGE-ACCOUNT`. This code uses only Python's standard library and never prints an access token:

```bash
python3 - <<'PY'
import json
import urllib.request
import urllib.error

account = 'YOUR-STORAGE-ACCOUNT'
token_url = ('http://169.254.169.254/metadata/identity/oauth2/token'
             '?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F')
request = urllib.request.Request(token_url, headers={'Metadata': 'true'})
with urllib.request.urlopen(request, timeout=10) as response:
    token = json.load(response)['access_token']

def call(container, method='GET'):
    url = f'https://{account}.blob.core.windows.net/{container}/message.txt'
    headers = {'Authorization': f'Bearer {token}', 'x-ms-version': '2023-11-03'}
    body = None
    if method == 'PUT':
        headers['x-ms-blob-type'] = 'BlockBlob'
        body = b'Write should be denied'
    request = urllib.request.Request(url, headers=headers, data=body, method=method)
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            print(method, container, response.status, response.read().decode())
    except urllib.error.HTTPError as error:
        print(method, container, error.code, error.headers.get('x-ms-error-code'))

call('allowed')
call('restricted')
call('allowed', 'PUT')
PY
```

Expected:

| Request | Result |
|---|---|
| GET allowed/message.txt | 200 and sample content |
| GET restricted/message.txt | 403 |
| PUT allowed/message.txt | 403 |

A 403 is an expected learning result for the two negative tests. A timeout suggests networking, not RBAC. Copy only status results into your worksheet.

## Lab 4 - Remove and restore the role

In the portal:

Open **Storage account → Containers → allowed → Access control (IAM) → Role assignments**. Find the **Storage Blob Data Reader** assignment whose member is **lab11-vm** and scope is this container. Select only that row → **Remove → Yes**. Do not remove your operator assignment.

1. Rerun the Run Command script periodically until the previously allowed GET is denied. Role/token authorization caches can delay revocation; do not promise immediate effect.
2. Restore the grant:

1. Open **Storage account → Containers → allowed → Access control (IAM) → Add → Add role assignment**.
2. Search/select **Storage Blob Data Reader → Next**. Assign access to **Managed identity**. **Select members** → subscription → Virtual machine → lab11-vm. **Select → Review + assign** (confirm again if prompted).
3. Open **Role assignments** and verify role, member and scope. Allow several minutes for propagation. A Contributor role alone cannot assign roles; use an account with the required role-assignment permission.

3. Allow propagation and rerun. Expected: only the allowed GET succeeds again.
4. In the VM **Identity** page, confirm System assigned is On. In Storage **IAM**, inspect the container-scoped assignment.

## Lab 5 - Understand the boundaries

Write answers before checking these explanations:

- Access to [Azure portal](https://portal.azure.com) with your learning subscription selected. Keep a local worksheet of the resource names you choose.
- Why does assigning Contributor to the VM not solve blob reading? Management operations and blob data permissions are distinct.
- Why is an account key absent? The VM obtains short-lived tokens from its local managed identity endpoint.
- Does identity eliminate networking requirements? No; the VM still needs a route to the storage endpoint.

## Troubleshooting

| Symptom | Correction |
|---|---|
| Role assignment denied | Obtain scoped role-assignment permission; Contributor is insufficient. |
| Identity token request fails | Confirm System assigned On and run the code on the VM, not on your own computer. |
| All blob GETs denied | Verify VM principal ID, container scope, storage name and propagation. |
| Restricted GET succeeds | Remove extra data roles/grants from this new identity; inspect inherited access. |
| Run Command unavailable | Check VM agent health and explicit outbound connectivity. |
| Unexpected 404 | Verify container/blob names and case. |

## Cleanup

List the group's resources, then delete only the lab group:

1. Open **Resource groups → azlab11-identity → Overview**. Review the complete resource list and confirm it contains only this exercise.
2. Select **Delete resource group**, type `azlab11-identity` to confirm, and select **Delete**.
3. Watch **Notifications** for successful deletion. Return to **Resource groups**, refresh, and verify the group is absent; also check **All resources** with the same subscription filter. If deletion failed, inspect the reported dependency/lock and resolve it before considering cleanup complete.

Expected: the deleted resource group is absent after refresh. The VM system identity is deleted with the VM. No subscription-wide role grants were created in this guide; resource-scoped grants disappear with their resources.

## Completion checklist

- [ ] Token obtained without keys and without printing it.
- [ ] Allowed read succeeds; restricted read and write fail.
- [ ] Role removal/recreation changes access after propagation.
- [ ] Resources deleted.

## References

- [VM managed identity access to Storage](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/tutorial-linux-vm-access-storage)
- [Linux VM Run Command](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/run-command)
