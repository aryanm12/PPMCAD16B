# Lab 12 - VM Scale Sets, Autoscaling and Automatic Repair

**Read first:** [Brief notes - concepts for this lab](12-VM-Scale-Sets-Autoscaling-and-Repair-brief-notes.md)

**How to work:** Use Azure portal for resource creation, settings, verification and cleanup. Follow the guest-script instructions only when a step needs software running inside a VM.

## Outcome

Deploy a two-zone web scale set behind a Standard Load Balancer, scale between two and four VMs based on CPU, and replace a VM whose application becomes unhealthy.

**Time:** 90–150 minutes. **Costs:** Two to four `Standard_D2s_v5` VMs/disks, Standard Load Balancer/public IP, NAT Gateway/public IP and monitoring. Non-burstable VMs make the bounded CPU demonstration predictable. Check regional quota for eight vCPUs.

Azure Load Balancer is a layer-4 service, not a full ALB equivalent. The HTTP-aware gateway is demonstrated in guides 02/03. This lab focuses on scale-set lifecycle management.

## Prerequisites

- Access to [Azure portal](https://portal.azure.com) with your learning subscription selected. Keep a local worksheet of the resource names you choose.
- Region with zones 1/2 and the specified size or another suitable non-burstable size.
- No existing VMSS/network required. The guide explicitly selects **Flexible** orchestration so each instance has a regular VM portal resource.

## Lab 1 - Create network, NAT and load balancer

1. Portal **Resource groups → Create**: learning subscription, `azlab12-vmss`, **East US 2** or your chosen supported Region → **Review + create → Create**.
2. **Virtual networks → Create**: same group/Region, `lab12-vnet`; **IP addresses**: space `10.62.0.0/16`, remove default subnet, add `app` with `10.62.1.0/24`; create.
3. **NAT gateways → Create**: name `lab12-nat`, same group/Region, Standard SKU. **Outbound IP → Create new public IP**: `lab12-nat-ip`, Standard/static. **Subnet**: `lab12-vnet/app`; create and wait for success.
4. **Network security groups → Create**: `lab12-nsg`, same group/Region. **Inbound security rules → Add**: Source **Service Tag → Internet**, source ports `*`, Destination Any, service Custom, destination port `80`, TCP, Allow, priority `100`, name `Web`; Add. Retain default AzureLoadBalancer probe rule.
5. NSG **Subnets → Associate**: `lab12-vnet/app`; OK. Do not open SSH to the Internet.
6. **Load balancers → Create**: `lab12-lb`, same group/Region, SKU **Standard**, type **Public**, tier **Regional**. **Frontend IP configuration → Add**: name `front`, new Standard/static public IP `lab12-lb-ip`, zone-redundant if offered; Save.
7. **Backend pools → Add**: name `back`, VNet `lab12-vnet`, configuration **NIC**. Leave membership empty until scale-set creation. **Review + create → Create**.
8. Open LB **Health probes → Add**: `web-health`, HTTP, port `80`, path `/health.html`, interval `5` seconds, unhealthy threshold `2`; Save.
9. **Load balancing rules → Add**: `web-rule`, IPv4, frontend `front`, backend `back`, protocol TCP, frontend/backend port `80`, probe `web-health`, session persistence None, idle timeout `4`, floating IP Disabled. For outbound SNAT select **Use outbound rules to provide outbound access** / disable implicit outbound SNAT. Save; NAT gateway provides outbound access, so no LB outbound rule is needed.

The default NSG AllowAzureLoadBalancerInBound rule permits health probes. NAT provides explicit outbound access; this lab does not depend on the load-balancing rule for outbound SNAT.

## Lab 2 - Launch a repeatable scale set

1. Search **Virtual machine scale sets → Create**. Select the lab group/Region, name `lab12-vmss`, orchestration **Flexible**, zones **1 and 2**, balancing across zones enabled if offered. Flexible instances appear as regular VM resources, allowing the portal Run Command workflow below.
2. Image **Ubuntu Server 22.04 LTS x64**, size **Standard_D2s_v5**; username `azureuser`; generate SSH key; inbound ports **None**. **Disks**: Standard SSD LRS.
3. **Networking**: edit NIC configuration; VNet `lab12-vnet`, subnet `app`, public IP per instance **Disabled**, NIC NSG **None** (subnet NSG applies). Enable load balancing, choose existing **Azure Load Balancer → lab12-lb → back**. Save NIC configuration.
4. **Scaling**: initial instance count `2`, manual scaling initially; configure autoscale later. **Management / Upgrade policy**: Manual if selectable. Keep automatic repairs off until health is verified. **Advanced → Custom data**: paste the YAML below, starting with `#cloud-config`.
5. **Review + create → Create**; download the key when prompted. Wait for successful deployment.

```yaml
#cloud-config
package_update: true
packages: [nginx]
runcmd:
  - [bash, -c, 'printf "<h1>Scale set server %s</h1>\n" "$(hostname)" > /var/www/html/index.html']
  - [bash, -c, 'echo healthy > /var/www/html/health.html']
  - [systemctl, enable, --now, nginx]
```

1. Open VMSS → **Instances**; wait for two healthy running instances.
2. Open Load Balancer → **Backend pools**, verify both NICs are registered.
3. Browse the load balancer public IP on HTTP; expect the server name.
4. Repeated requests may remain on one backend because load-balancing hashes connections. This is not evidence the other backend is broken; inspect health/metrics.

## Lab 3 - Configure application health and repair

1. Open **VMSS → Health and repair**. Enable application health monitoring using **Application Health extension**. Select **Binary health states** (version 1.0) if a choice is offered; protocol HTTP, port `80`, path `/health.html`; Save. This lab returns plain text with HTTP 200, not rich-state JSON.
2. Apply the model/extension to existing instances: **Instances**, select the two original VMs, **Upgrade / Update** if marked not on latest model. Wait for provisioning success. Check each VM's **Extensions + applications** for the application-health extension and the VMSS Instances health column.
3. If a rich-state version is selected instead, switch the health setting to **TCP, port 80** for this nginx stop/start exercise; TCP evaluates whether the application accepts a connection and does not require JSON. Confirm Healthy before enabling repairs.
4. Keep the LB probe for traffic routing. Do not also select that LB probe as the scale set's orchestration health source; use the application-health extension for repairs.

Verify existing instances have the health configuration before using automatic repair.

1. Open VMSS **Health and repair / Automatic repairs**.
2. Health monitoring: Application Health extension; wait until instances report Healthy.
3. Enable Automatic repairs, action **Replace**, grace period **10 minutes**. Save and apply the model to existing instances if requested.
4. Record each instance's ID and VM ID/provisioning time. Instance numbers may be reused; the platform VM ID/time helps prove replacement.

## Lab 4 - Enable autoscale

1. VMSS → **Scaling → Custom autoscale**, name `lab12-autoscale`.
2. Default profile minimum **2**, default **2**, maximum **4**.
3. Add scale-out rule: metric **Percentage CPU**, aggregation Average, operator Greater than, threshold **60**, duration **5 minutes**; action increase count by **1**, cooldown **5 minutes**.
4. Add scale-in rule: Average Percentage CPU Less than **25**, duration **10 minutes**; decrease count by **1**, cooldown **5 minutes**.
5. Save. Inspect the configured rules again. Do not choose “scale to 4” as a manual test and call it automatic scaling.

## Lab 5 - Run a bounded CPU load on existing instances

Open **VMSS → Instances**, record the two original VM names. Open the first instance’s VM resource (or find that exact name under **Virtual machines**) → **Run command → RunShellScript**. Paste/run the block below, then repeat on the second original VM. The Linux script runs inside each guest and stops its load after 20 minutes:

```bash
cat > /tmp/lab12-load.py <<'PY'
import multiprocessing
import time
def burn():
    end = time.monotonic() + 1200
    value = 1
    while time.monotonic() < end:
        value = (value * 17 + 3) % 10000019
if __name__ == '__main__':
    workers = [multiprocessing.Process(target=burn) for _ in range(multiprocessing.cpu_count())]
    for worker in workers: worker.start()
    for worker in workers: worker.join()
PY
nohup python3 /tmp/lab12-load.py >/tmp/lab12-load.log 2>&1 &
echo 'Bounded load started for 20 minutes'
```

1. Watch VMSS **Metrics → Percentage CPU** and **Scaling → Run history**.
2. Allow metric evaluation plus VM provisioning time. Record a scale-out event and a new instance.
3. Verify the new instance becomes healthy and serves the web page.
4. Do not run the load script on newly created instances. The original load ends after 20 minutes.
5. To stop early, run on each original ID:

On each original VM, use **Run command → RunShellScript**:

```bash
pkill -f '^python3 /tmp/lab12-load.py$' || true
```

6. Observe CPU fall and scale-in after the ten-minute evaluation window/cooldown. Minimum remains two. Record run-history evidence rather than assuming a fixed completion minute.

## Lab 6 - Trigger automatic application repair

After load has stopped and scaling is stable:

1. Choose one current instance ID from the Instances list.
2. Use the selected VM’s portal administration page:

Open the selected instance's VM resource → **Run command → RunShellScript**, paste and run:

```bash
systemctl stop nginx
```

3. Observe application health become Unhealthy. The load balancer stops sending new connections to that unhealthy endpoint after detection.
4. Wait for the repair grace period and platform repair operation. Do not manually restart nginx during this observation.
5. Inspect Activity log/repair history and the new VM ID/provisioning time. Cloud-init should install/start nginx on the replacement.
6. Verify Healthy again and working HTTP. If repair does not occur, inspect the settings/model before concluding the service repaired itself.

## Troubleshooting

| Symptom | Correction |
|---|---|
| No web page | NAT/package install, subnet NSG port 80, LB backend association and probe path. |
| No health status | Apply the extension model to current instances; inspect extension provisioning. |
| No scaling | Correct metric/aggregation, min/max, load on original instances and evaluation windows. |
| Repair absent | Application health enabled, repairs Enabled, Replace action, grace elapsed, model applied. |
| Replacement fails | Read Activity log for quota/size/zone allocation problems. |

## Cleanup

Stop load if still active. Inspect/delete `azlab12-vmss` in **Resource groups**: open the group, review resources, choose **Delete resource group**, type its name and confirm. Wait for success and refresh the resource-group list to verify absence. Confirm autoscale settings, scale set/disks, LB and NAT/public IPs are removed.

## Completion checklist

- [ ] Web scale set healthy in two zones.
- [ ] Metric-driven scale-out and scale-in evidenced.
- [ ] Stopped application caused an automatic replacement.
- [ ] Load bounded/stopped and all resources removed.

## References

- [Autoscale a VM scale set](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-autoscale-portal)
- [Automatic instance repairs](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-instance-repairs)
- [Application Health extension](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-health-extension)
