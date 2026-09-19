# 02 - Application Gateway and Web Architecture: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values. Supplied guest scripts run through the VM’s portal Run command page to install or test software inside the VM.

**Read before:** [Lab 02 - Application Gateway and web architecture](02-Application-Gateway-and-Web-Architecture.md)  
**Reading time:** 6–8 minutes. New to Azure? Read [foundation notes](01-Lab-Preparation-and-Cost-Controls-brief-notes.md) first.

## What you are building

A user reaches one public address. Application Gateway forwards the HTTP request to one of two web servers using private addresses. When a web server stops responding correctly, the gateway stops choosing it after health-check detection.

```text
Browser → gateway public IP → HTTP listener/rule → backend pool → web VM
```

## Terms before you create them

| Term | Meaning and purpose |
|---|---|
| VM | A virtual machine: operating system, CPU and memory running your web server |
| Image | The starting operating-system software, such as Ubuntu 22.04 |
| VM size | The CPU/memory configuration, similar to an EC2 instance type |
| Managed disk | Persistent VM storage, separate from the VM's CPU/memory lifecycle |
| NIC | Network interface connecting the VM to a subnet |
| VNet | A private regional IP network in Azure |
| Subnet | A smaller IP range inside that VNet |
| CIDR | Address-range notation; `10.52.1.0/24` describes a subnet, not one server |
| NSG | Network Security Group: ordered allow/deny rules for network traffic |
| Availability zone | An isolated deployment location within a Region |

Azure VNets and subnets span a Region's zones. Unlike AWS, you do not create a different subnet solely because a VM is in another AZ. A VM's zone is chosen separately. See [VNet overview](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview).

## Application Gateway vocabulary

- **Frontend IP:** where clients connect.
- **Listener:** accepts traffic on a chosen address/port/protocol.
- **Routing rule:** tells the gateway which backend setting/pool to use.
- **Backend pool:** the collection of application destinations.
- **Backend setting:** how to contact those destinations, for example HTTP on port 80.
- **Health probe:** a repeated request used to decide whether a backend is currently usable.

Think of a probe as a regular “Can you serve this URL?” test. VM status **Running** only says the VM is running; nginx may still be stopped. A **502** from the gateway often means it could not obtain a usable backend response. See [gateway components](https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-components).

## Why the lab uses these network rules

The gateway sits in its own dedicated subnet. Web VMs accept port 80 from that subnet, then explicitly deny other sources for that port. NSG rules use priorities: a smaller number is evaluated first. Default VNet-wide allowance is one reason the explicit deny matters.

The VM public IPs supply explicit outbound connectivity for installing software. They do not mean all inbound ports are open. The public gateway reaches the VMs over private IPs. An outbound **NAT** mechanism and an inbound load balancer solve different problems.

**Cloud-init** applies first-boot configuration. **Run Command** asks the Azure VM agent to run an administrative script inside the guest. The script executes inside the VM. A localhost request tests the local web process; opening the gateway IP in your browser tests the full inbound path.

## Relate it to AWS

| Familiar AWS idea | Azure idea here | Important difference |
|---|---|---|
| EC2 and AMI | VM and image | Different sizing/configuration options |
| VPC | VNet | Subnets are not AZ-bound |
| ALB | Application Gateway | Similar HTTP role; configuration and supporting subnet requirements differ |
| Target group health check | Backend pool and probe | Probe must match the actual app path/port |
| Security group | NSG | NSGs have ordered allow/deny rules and can apply at subnet/NIC scopes |

## Avoid these assumptions

Two servers do not automatically create a load balancer. A gateway does not automatically repair a failed standalone VM. Load balancing does not guarantee alternate responses on every browser refresh. HTTP routing success does not prove HTTPS, authentication or the database layer is secure.

## Check your understanding

1. Both VMs show Running, but one probe fails. Can its app be broken?
2. Will stopping nginx cause Application Gateway to create a replacement VM?
3. Why test both localhost and the gateway URL?

**Answers:** (1) Yes. (2) No; it changes routing, not VM lifecycle. (3) The first isolates the process; the second also exercises gateway/network configuration.

**Ready for the lab:** You can trace one request and explain why health checks, NSGs and VM status are separate checks.
