# 13 - Private Endpoints and DNS: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values. Supplied guest scripts run through the VM’s portal Run command page to install or test software inside the VM.

**Read before:** [Lab 13 - Private endpoints and DNS](13-Private-Endpoints-DNS-and-Troubleshooting.md)  
**Reading time:** 5–7 minutes. Review [identity notes](11-Managed-Identity-RBAC-and-VM-Operations-brief-notes.md) if data roles are unfamiliar.

## What this lab makes private

The lab makes the VM-to-Storage **data path** private. The VM still has explicit outbound management connectivity through a public IP. Do not conclude that the VM is fully internet-isolated just because its Storage traffic uses a private endpoint.

```text
VM asks for normal Storage hostname
    → private DNS resolves endpoint IP
    → private endpoint reaches Storage
    → Storage authorizes the VM identity
```

## Vocabulary before creating the endpoint

| Term | Meaning |
|---|---|
| Private Link | Azure capability enabling private connectivity to supported services |
| Private endpoint | A network interface/private IP in your VNet used to reach a particular service resource |
| Subresource | The specific service interface being connected, such as Storage blob, file or web |
| DNS | The system that translates hostnames into network addresses |
| Private DNS zone | DNS records available through an intended private resolution context |
| VNet link | Associates the private zone's name resolution with a VNet |
| A record | Maps a hostname to an IPv4 address |
| CNAME | Makes one DNS name an alias of another |
| TTL | The period a DNS answer may be cached |

DNS does not move packets by itself. It tells the client which address to contact. Routing, endpoint approval, network controls and service authorization still have to work.

## Why keep the normal service hostname?

The application still requests `ACCOUNT.blob.core.windows.net`. Private DNS and the service's alias chain lead it to the correct private address. Hard-coding an endpoint IP bypasses useful name resolution and can break TLS hostname verification.

For this blob connection, the private zone is `privatelink.blob.core.windows.net`. Choosing a website/file subresource or an unrelated zone will not automatically give the same result. A private DNS zone with no matching VNet link is not visible to the client just because it is in the same resource group. See [private endpoint DNS](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns).

## Three controls that are easy to confuse

1. **Public network access:** whether the service's public network path accepts requests under its configuration.
2. **Private endpoint connectivity:** whether the VNet has the intended private path.
3. **RBAC/data authorization:** whether the requester is permitted to read the object.

Turning off public network access does not grant data access to every VM. Giving Blob Data Reader does not build a private endpoint. Both network and identity controls must match the intended client.

## What the deliberate DNS failure proves

The lab removes the VNet link while leaving the blob, role assignment and private endpoint intact. After cached answers expire, the client no longer resolves the intended private endpoint through that zone. A request can then fail against the public path, which the Storage account has disabled.

Restoring the DNS link repairs the naming problem. Assigning a broader role would change the wrong layer. A **403** can reflect service network controls as well as identity authorization, so first record the resolved address and request context.

## Private endpoint versus service endpoint

These are different Azure networking features. A private endpoint assigns a private interface/address for a supported resource. A **service endpoint** extends subnet identity/connectivity to supported public service endpoints and their network rules; it does not create the same private IP endpoint. The lab specifically teaches Private Link/private endpoints.

## AWS comparison

AWS interface VPC endpoints are a useful analogy for the private-address pattern. Do not translate the S3 gateway endpoint route-table exercise literally: Azure Private Link and Azure service endpoints are not S3 gateway endpoint aliases.

## Check your understanding

1. Does a private endpoint give the VM permission to read all blobs?
2. Why might portal browser outside the VNet fail while the VM succeeds?
3. Why can removing a DNS link appear to have no effect for a short time?

**Answers:** (1) No, authorization still applies. (2) They use different network/resolution contexts. (3) Cached DNS answers may remain until expiry/flush.

**Ready for the lab:** You can diagnose name resolution, connectivity and authorization as separate layers.

Further reading: [Storage private endpoints](https://learn.microsoft.com/en-us/azure/storage/common/storage-private-endpoints).
