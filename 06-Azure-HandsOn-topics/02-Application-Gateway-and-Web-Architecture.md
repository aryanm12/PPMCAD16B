# Lab 02 - Two-Zone Web Architecture with Application Gateway

**Read first:** [Brief notes - concepts for this lab](02-Application-Gateway-and-Web-Architecture-brief-notes.md)

**How to work:** Use Azure portal for resource creation, settings, verification and cleanup. Follow the guest-script instructions only when a step needs software running inside a VM.

## Outcome

Create a VNet, two web VMs in different availability zones and a public Application Gateway. Verify backend health and continue serving requests when one web server fails.

**Time:** 75–105 minutes. **Cost:** Two VMs/disks, their public IPs and Standard_v2 Application Gateway. Gateway provisioning can take 15–30 minutes. No existing network is required.

```text
Browser → public Application Gateway → private IP of web-a / web-b
                                      zone 1             zone 2
```

## Prerequisites

- Contributor for the lab; permission to run VM Run Command. Registered Compute/Network providers.
- Access to [Azure portal](https://portal.azure.com) with your learning subscription selected. Keep a local worksheet of the resource names you choose.
- Region offering zones 1/2, Standard_v2 Gateway and `Standard_B2s`. If that VM size is unavailable, inspect **VM → Size** for another small available size and use it for both VMs.
- This starter lab assigns VM public IPs for explicit outbound package installation, with no public inbound VM rules. Guide 03 uses private VMs and NAT Gateway.

## Lab 1 - Create the network and NSG

1. In [Azure portal](https://portal.azure.com), search **Resource groups → Create**. Select your learning subscription, name `azlab02-web`, Region **East US 2** (or the supported Region chosen for this lab). Select **Review + create → Create**.
2. Open the group → **Tags**; add `Project=AzureHandsOn` and `Lab=02`; **Apply**. Keep all resources below in this subscription, group and Region. Record names in your lab worksheet.

1. Search **Virtual networks → Create**; select the lab group and Region, name `lab02-vnet`.
2. On **IP addresses**, replace the default address space with `10.52.0.0/16`. Remove the default subnet if it conflicts. Add these subnets (name → address range): `gateway` → `10.52.0.0/24`; `web` → `10.52.1.0/24`. Leave optional security services disabled for this lab.
3. **Review + create → Create**; wait for deployment success. Reopen **Subnets** and check each range.

1. Search **Network security groups → Create**; use `lab02-nsg`, lab group and Region. Open it after deployment.
2. Open **Inbound security rules → Add**: Source **IP Addresses**, `10.52.0.0/24`; source ports `*`; Destination **Any**; Service **Custom**; destination port `80`; protocol **TCP**; action **Allow**; priority `100`; name `AllowApplication`; **Add**.
3. Add another inbound rule: Source **Any**, source ports `*`, Destination **Any**, destination port `80`, TCP, **Deny**, priority `110`, name `DenyOtherApplication`. This overrides the default VNet allow for this port.
4. Open **Subnets → Associate**; select `lab02-vnet` and `web`; **OK**. Retain default rules, including AzureLoadBalancer health probes. Do not add public SSH/RDP rules. Verify association before creating VMs.

The explicit deny overrides Azure's default AllowVNetInBound for HTTP. Lower priority numbers are evaluated first. We do not attach an NSG to the dedicated gateway subnet in this introductory lab; gateway infrastructure traffic must not be accidentally blocked.

## Lab 2 - Define a reproducible web server

Copy this cloud-init YAML into **Advanced → Custom data** when creating each VM in the next section:

```yaml
#cloud-config
package_update: true
packages:
  - nginx
runcmd:
  - [bash, -c, 'printf "<h1>Azure web lab</h1><p>Server: %s</p>\n" "$(hostname)" > /var/www/html/index.html']
  - [bash, -c, 'echo healthy > /var/www/html/health.html']
  - [systemctl, enable, --now, nginx]
```

Cloud-init runs on first boot. The gateway will later test `/health.html` independently of your browser.

## Lab 3 - Launch two VMs

1. Search **Virtual machines → Create → Azure virtual machine**. Select lab subscription/group/Region; name `lab02-web-a`; image **Ubuntu Server 22.04 LTS, x64**; size **Standard_B2s** (select an available small equivalent if necessary). Availability options **Availability zone**, select **1** only. Username `azureuser`, authentication **SSH public key**, generate a new key pair; public inbound ports **None**.
2. **Disks**: OS disk **Standard SSD LRS**. **Networking**: select `lab02-vnet`, subnet `web`; public IP **Create new → Standard, static**; NIC network security group **None** because the subnet NSG already applies. Leave load balancing off.
3. Under **Advanced → Custom data**, paste the cloud-init YAML below exactly, beginning with `#cloud-config`. Disable optional paid services such as Backup for this VM unless this lab asks for them. **Review + create → Create**; download the private key when prompted and store it securely.
4. Wait for deployment. Open **Overview** to record private IP and provisioning status. Use **Operations → Run command → RunShellScript** for the guest scripts in this lab; paste the entire specified block and select **Run**. These Linux commands execute inside the VM, not on your computer.

Repeat the same wizard for `lab02-web-b`, selecting **zone 2** and the same custom data. Do not put both VMs in one zone.

The subnet NSG applies to both VMs. No inbound SSH rule is opened; use portal Run Command for administration.

1. In the portal, open each VM → **Run command → RunShellScript** and run:

```bash
cloud-init status --wait
systemctl is-active nginx
curl -fsS http://127.0.0.1/health.html
```

2. Expected: active and healthy. If Run Command times out during initial installation, allow a few minutes, then rerun.
3. Record the private addresses from the portal:

Open each VM → **Overview → Networking / Properties**. Copy its private IP into your worksheet as Backend A and Backend B.

Record both. The gateway connects to these private addresses, not the VM public IPs.

## Lab 4 - Create Application Gateway

1. Open each VM **Overview / Networking** and record its **private** IP.
2. Search **Application gateways → Create**; lab group/Region; name `lab02-gateway`; tier **Standard V2**; disable autoscaling for this exercise and set instance count `2`. Select `lab02-vnet`, dedicated subnet `gateway`.
3. **Frontends**: Public; **Add new** Standard static public IP `lab02-gateway-ip`.
4. **Backends → Add a backend pool**: name `web-pool`, add targets now, target type **IP address or FQDN**; enter both VM private IPs. **Add**.
5. **Configuration → Add a routing rule**: name `web-rule`, priority `100`. Listener `http-listener`, frontend Public, protocol HTTP, port `80`, listener type Basic.
6. **Backend targets**: target `web-pool`; **Add new backend setting** `web-settings`, HTTP, port `80`, cookie affinity disabled, request timeout `20` seconds; keep host-name override off. Save setting and rule.
7. **Review + create → Create**; wait for successful deployment. Record the public frontend IP from Overview. Continue with the custom probe below.

Wait for successful creation; do not launch duplicate create operations while it is provisioning.

1. Open **Application Gateway → lab02-gateway → Health probes → Add**.
2. Name `lab02-health`; protocol HTTP; host `127.0.0.1`; path `/health.html`; interval 30 seconds, timeout 30, unhealthy threshold 3. Leave status-code match 200–399.
3. Associate the probe with the `web-settings` backend setting. If association is not offered here, save the probe, open **Backend settings**, edit the HTTP setting and select **Use custom probe → lab02-health**.
4. Wait for the update to finish. Open **Backend health** and verify both private IPs are Healthy.

## Lab 5 - Validate the request path

In the Azure portal:

Open **lab02-gateway → Overview**, copy its public frontend IP and browse to `http://YOUR-GATEWAY-IP/`. Refresh eight times (use Ctrl+F5 to bypass browser caching) and record the server names.

Expected: pages naming the web VMs. Exact alternation is not guaranteed. Open the same URL in your browser.

1. Copy a VM public IP from its Overview.
2. Try `http://VM-PUBLIC-IP/`; the request should fail because it did not come from the gateway subnet.
3. Record gateway response, backend-health status and direct-access failure.

This lab uses HTTP to teach routing with synthetic content. TLS certificates, WAF policy and application authentication are separate production requirements.

## Lab 6 - Cause an application failure

1. In **web-a → Run command → RunShellScript**, run `systemctl stop nginx`.
2. Observe Backend health until web-a becomes Unhealthy. Expect a detection delay; requests during transition may fail.
3. Refresh the gateway page eight times with Ctrl+F5 again. Healthy traffic should reach web-b.
4. Restart web-a with `systemctl start nginx` through Run Command.
5. Wait for both backends to become Healthy and verify the response again.

**What this proves:** The gateway routes around a failed backend. It does not automatically repair a standalone VM. Guide 12 adds automatic repair and scale-out.

## Troubleshooting

| Symptom | Check |
|---|---|
| Gateway returns 502 | Backend health, web NSG source CIDR, correct private IPs and nginx status. |
| Web package installation failed | VM has a Standard public IP for explicit outbound; inspect `/var/log/cloud-init-output.log` via Run Command. |
| Probe unhealthy but localhost works | Verify probe association/path, backend port 80 and subnet NSG rule order. |
| Run Command fails | VM agent must be healthy and able to reach required Azure endpoints; check VM instance view/boot diagnostics. |
| VM size or zone unavailable | Choose a supported regional size/zone; do not silently put both VMs in the same zone and claim zone resilience. |
| Direct VM HTTP works | Check subnet NSG association and whether a higher-priority allow rule was added. |

## Cleanup

1. Open **Resource groups → azlab02-web → Overview**. Review the complete resource list and confirm it contains only this exercise.
2. Select **Delete resource group**, type `azlab02-web` to confirm, and select **Delete**.
3. Watch **Notifications** for successful deletion. Return to **Resource groups**, refresh, and verify the group is absent; also check **All resources** with the same subscription filter. If deletion failed, inspect the reported dependency/lock and resolve it before considering cleanup complete.

Confirm only lab resources before deletion. Wait for the portal deletion notification and verify the group is absent. Verify the gateway, both VMs, all disks/NICs and public IPs are gone; stopping VMs alone does not remove these charges.

## Completion checklist

- [ ] Web servers in two distinct zones.
- [ ] Both gateway backends healthy.
- [ ] Direct VM HTTP denied.
- [ ] Failed nginx instance removed from healthy routing and recovered.
- [ ] Resource group deleted.

## References

- [Application Gateway portal quickstart](https://learn.microsoft.com/en-us/azure/application-gateway/quick-create-portal)
- [Custom probes](https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-create-probe-portal)
- [Azure explicit outbound connectivity](https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/default-outbound-access)
