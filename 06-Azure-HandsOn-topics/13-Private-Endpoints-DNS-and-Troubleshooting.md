# Lab 13 - Private Endpoint, Private DNS and Storage Access

**Read first:** [Brief notes - concepts for this lab](13-Private-Endpoints-DNS-and-Troubleshooting-brief-notes.md)

**How to work:** Use Azure portal for resource creation, settings, verification and cleanup. Follow the guest-script instructions only when a step needs software running inside a VM.

## Outcome

Read a private blob from a VM using managed identity, disable Storage public network access, and prove access continues through a private endpoint. Break the private DNS link, diagnose the resulting failure and repair it.

**Time:** 60–90 minutes. **Costs:** VM/disk/public IP, private endpoint and DNS/Storage usage. No previous lab required.

This VM retains explicit public-IP outbound access for management. The **storage data path** is private. This lab does not claim that the VM is fully internet-isolated or that Run Command is a private endpoint service.

## Prerequisites

- Contributor and permission to assign data roles. Network/Compute/Storage providers registered.
- Access to [Azure portal](https://portal.azure.com) with your learning subscription selected. Keep a local worksheet of the resource names you choose.

## Lab 1 - Create private data and an identity-enabled VM

1. In [Azure portal](https://portal.azure.com), search **Resource groups → Create**. Select your learning subscription, name `azlab13-private`, Region **East US 2** (or the supported Region chosen for this lab). Select **Review + create → Create**.
2. Open the group → **Tags**; add `Project=AzureHandsOn` and `Lab=13`; **Apply**. Keep all resources below in this subscription, group and Region. Record names in your lab worksheet.

1. Search **Storage accounts → Create**. Select lab subscription/group/Region. Choose a globally unique name such as `azlab13yourinitials1234` (3–24 lowercase letters/digits); record your actual name. Performance **Standard**, redundancy **LRS**, general-purpose v2.
2. On **Advanced**, keep secure transfer required, minimum TLS **1.2**, and **Allow enabling anonymous access on individual containers** disabled. For this initial setup, **Networking → Public network access → Enable from all networks**. Private containers still require authorization.
3. **Review + create → Create**. Open **Overview** and verify deployment success. Use your recorded name wherever the guide says `YOUR-STORAGE-ACCOUNT`.

1. Search **Virtual networks → Create**; select the lab group and Region, name `lab13-vnet`.
2. On **IP addresses**, replace the default address space with `10.63.0.0/16`. Remove the default subnet if it conflicts. Add these subnets (name → address range): `client` → `10.63.1.0/24`; `endpoints` → `10.63.2.0/24`. Leave optional security services disabled for this lab.
3. **Review + create → Create**; wait for deployment success. Reopen **Subnets** and check each range.

1. Search **Network security groups → Create**; use `lab13-nsg`, lab group and Region. Open it after deployment.
4. Open **Subnets → Associate**; select `lab13-vnet` and `client`; **OK**. Retain default rules, including AzureLoadBalancer health probes. Do not add public SSH/RDP rules. Verify association before creating VMs.

1. Search **Virtual machines → Create → Azure virtual machine**. Select lab subscription/group/Region; name `lab13-vm`; image **Ubuntu Server 22.04 LTS, x64**; size **Standard_B2s** (select an available small equivalent if necessary). Use no infrastructure redundancy requirement for this single test VM. Username `azureuser`, authentication **SSH public key**, generate a new key pair; public inbound ports **None**.
2. **Disks**: OS disk **Standard SSD LRS**. **Networking**: select `lab13-vnet`, subnet `client`; public IP **Create new → Standard, static**; NIC network security group **None** because the subnet NSG already applies. Leave load balancing off.
3. Under **Management**, enable **System assigned managed identity**. Disable optional paid services such as Backup for this VM unless this lab asks for them. **Review + create → Create**; download the private key when prompted and store it securely.
4. Wait for deployment. Open **Overview** to record private IP and provisioning status. Open **Identity → System assigned**, confirm **On**, and record Object (principal) ID. Use **Operations → Run command → RunShellScript** for the guest scripts in this lab; paste the entire specified block and select **Run**. These Linux commands execute inside the VM, not on your computer.

1. Open **your storage account → Access control (IAM) → Add → Add role assignment**.
2. Search/select **Storage Blob Data Contributor → Next**. Assign access to **User, group, or service principal**. **Select members** → your signed-in user. **Select → Review + assign** (confirm again if prompted).
3. Open **Role assignments** and verify role, member and scope. Allow several minutes for propagation. A Contributor role alone cannot assign roles; use an account with the required role-assignment permission.

1. Open **your storage account → Access control (IAM) → Add → Add role assignment**.
2. Search/select **Storage Blob Data Reader → Next**. Assign access to **Managed identity**. **Select members** → subscription → Virtual machine → lab13-vm. **Select → Review + assign** (confirm again if prompted).
3. Open **Role assignments** and verify role, member and scope. Allow several minutes for propagation. A Contributor role alone cannot assign roles; use an account with the required role-assignment permission.

After RBAC propagation:

1. On your computer, open a plain-text editor and save `proof.txt` containing `Private endpoint proof`. In Windows Save As, choose **All files** to avoid a hidden `.txt` suffix.
2. In the storage account open **Data storage → Containers → + Container**, name `proof`, anonymous access **Private**, **Create** (skip creation if it already exists).
3. Open the container; choose **Switch to Microsoft Entra user account** if the page shows access-key authentication. Select **Upload → Browse for files**, choose `proof.txt`, then **Upload**. Refresh and confirm the blob name. Select the blob → **Download** and open it; verify the original content.

## Lab 2 - Create the blob private endpoint

1. Portal Storage account → **Networking → Private endpoint connections → + Private endpoint**.
2. Resource group `azlab13-private`; name `lab13-blob-pe`; same Region.
3. Resource: this storage account; target subresource **blob**. Other subresources such as file/web require their own configuration.
4. VNet `lab13-vnet`, subnet `endpoints`; dynamic private IP.
5. **Integrate with private DNS zone: Yes**; create/use a new lab zone named `privatelink.blob.core.windows.net` in the lab group.
6. Review/create. Open the endpoint and confirm connection status Approved.
7. Open the private DNS zone and confirm an A record for the storage account, pointing to the endpoint's `10.63.2.x` address.
8. Under **Virtual network links**, confirm a link to `lab13-vnet` with autoregistration disabled.

## Lab 3 - Test from the VM

Open VM **Run command → RunShellScript**. Replace `YOUR-STORAGE-ACCOUNT`:

```bash
cat > /tmp/lab13-check.py <<'PY'
import socket
import json
import urllib.request
import urllib.error

account = 'YOUR-STORAGE-ACCOUNT'
host = f'{account}.blob.core.windows.net'
print('Resolved IP:', socket.gethostbyname(host))
url = ('http://169.254.169.254/metadata/identity/oauth2/token'
       '?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F')
with urllib.request.urlopen(urllib.request.Request(url, headers={'Metadata':'true'}), timeout=10) as response:
    token = json.load(response)['access_token']
req = urllib.request.Request(f'https://{host}/proof/proof.txt',
    headers={'Authorization':f'Bearer {token}','x-ms-version':'2023-11-03'})
try:
    with urllib.request.urlopen(req, timeout=15) as response:
        print('HTTP:', response.status, 'Content:', response.read().decode())
except urllib.error.HTTPError as error:
    print('HTTP:', error.code, 'Reason:', error.headers.get('x-ms-error-code'))
PY
python3 /tmp/lab13-check.py
```

Expected: private endpoint IP and HTTP 200/content. Continue using the normal Storage hostname; do not rewrite the application to connect to a private IP, which breaks hostname/certificate behavior.

## Lab 4 - Lock the public endpoint

1. Storage Networking → Public network access **Disabled**. Save.
2. Rerun `python3 /tmp/lab13-check.py` on the VM. It should still return the private IP and HTTP 200.
3. From the portal on your computer, repeat the authenticated blob download:

In the portal on your computer, open **Storage account → Storage browser → Blob containers → proof** using **Microsoft Entra user account**, and attempt to download `proof.txt` again. The same user successfully downloaded earlier. Expect a network-access error now; management pages can still open. Do not switch to account keys or anonymous access. The VM test must still succeed.

Expected network-access denial despite your Blob Data Contributor role. The portal browser outside the VNet environment is not in this VNet.

## Lab 5 - Break DNS and diagnose

1. Private DNS zone → **Virtual network links**, record the lab link name and delete only that link. Keep the private endpoint and DNS A record.
2. On VM Run Command run:

```bash
resolvectl flush-caches || true
python3 /tmp/lab13-check.py
```

3. Allow DNS cache/TTL expiry and repeat if it initially still succeeds.
4. Expected: hostname no longer resolves to your private endpoint; the blob request fails against the public endpoint because public access is disabled.
5. Record the resolved address and error. Do not add broad IAM permissions: the identity grant has not changed.
6. Recreate the VNet link: zone → **Virtual network links → Add**, name `lab13-link`, VNet `lab13-vnet`, autoregistration disabled.
7. Flush/wait for DNS, rerun; expect private IP and HTTP 200 again.

## Lab 6 - Use a layered diagnostic sequence

For each failure, inspect in this order:

1. DNS: does the normal service hostname resolve to the intended private endpoint IP?
2. Network: is the private endpoint Approved and reachable in the correct VNet/subnet?
3. Service network policy: public access disabled is expected; do not reopen it as a permanent fix.
4. Identity: is the VM's actual principal granted Blob Data Reader at the right scope?
5. Object: is the container/blob name correct?

Private endpoints control network reachability; they do not grant data authorization. A linked DNS zone does not by itself create an endpoint.

## Troubleshooting

| Symptom | Correction |
|---|---|
| Public IP returned before the failure exercise | Check DNS zone name, A record and VNet link. |
| 403 with private IP | Check RBAC, propagation and storage resource identity. |
| Timeout with private IP | Check endpoint approval, routes/NSGs and no custom DNS conflict. |
| DNS break appears ineffective | Allow caches/TTL to expire; use a fresh process and flush local resolver. |
| Portal data access denied | Expected after public access is disabled. |

## Cleanup

1. Portal **Resource groups → azlab13-private → Overview**. Review the full resource list and confirm this is only your lab.
2. Select **Delete resource group**, type `azlab13-private`, and confirm **Delete**.
3. Wait for **Notifications** to report success; refresh **Resource groups** and **All resources** for this subscription and verify absence. Inspect any deletion error rather than assuming the resources are gone.

Delete `azlab13-private` after listing its resources. Verify group deletion, including endpoint NIC, DNS zone, Storage, VM/disk/public IP. If you accidentally selected a shared DNS zone, remove only the lab A record/link/zone group after checking dependencies; do not delete that shared zone.

## Completion checklist

- [ ] Normal Storage hostname resolves to private IP inside VNet.
- [ ] VM read succeeds with public network access disabled.
- Access to [Azure portal](https://portal.azure.com) with your learning subscription selected. Keep a local worksheet of the resource names you choose.
- [ ] DNS failure reproduced and repaired without expanding RBAC.
- [ ] All lab resources removed.

## References

- [Storage private endpoints](https://learn.microsoft.com/en-us/azure/storage/common/storage-private-endpoints)
- [Private endpoint DNS](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns)
