# 03 - Secure Three-Tier Architecture: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values. Supplied guest scripts run through the VM’s portal Run command page to install or test software inside the VM.

**Read before:** [Lab 03 - Secure three-tier architecture](03-Secure-Three-Tier-Architecture.md)  
**Reading time:** 6–8 minutes. Review [foundation notes](01-Lab-Preparation-and-Cost-Controls-brief-notes.md) if needed.

## What “three-tier” means here

An application has different responsibilities: an entry/presentation tier receives users, an application tier performs work, and a data tier stores durable information. Separating them makes traffic rules, scaling and failure diagnosis easier to reason about.

```text
User → public Application Gateway → private app VM → private MySQL
                                         |
                                         +→ managed identity → Key Vault
```

The app retrieves a credential and performs a real database query. A page that displays “Database: SUCCESS” must therefore prove more than a web server being alive.

## Terms used in the lab

| Term | Explanation |
|---|---|
| Public entry point | An address reachable by internet clients, subject to its access controls |
| Private application VM | A VM reached through its private IP; this lab assigns it no public IP |
| NAT Gateway | Provides an explicit outbound route/address translation for subnet resources |
| Delegated subnet | A subnet reserved/configured for a named Azure service to deploy and manage its resources |
| MySQL Flexible Server | Azure's managed MySQL service; Azure runs the underlying database infrastructure |
| Private DNS | Name resolution that directs clients to private service addresses in the intended network |
| Managed identity | An Azure-managed identity the application uses to obtain tokens without storing its own login secret |
| Key Vault | A service for storing/retrieving secrets, keys and certificates with access controls |
| TLS | Encryption and server-identity verification for the connection to a service |

MySQL **VNet Integration** in this lab uses a delegated subnet. That is a specific service deployment model, not just a generic private endpoint attached to any subnet. See [MySQL private networking](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concepts-networking-vnet).

## There are three separate access decisions

1. **Network:** can the VM reach the database hostname/address and port?
2. **Azure identity permission:** may this VM's identity read the credential from Key Vault?
3. **Database authentication:** does MySQL accept the retrieved username/password?

Passing one does not imply passing the others. A working Key Vault token cannot repair private DNS. A reachable MySQL port does not make a wrong password valid. Storing a new password in Key Vault does not change the database password.

## Why each resource exists

Application Gateway provides inbound HTTP routing. NAT Gateway gives the private VMs outbound connectivity for packages and Azure service calls; it does not publish the application to users. The app NSG restricts its serving port to the gateway subnet. The database DNS link allows the VM to find the private database address. Each VM's managed identity has a scoped secret-reading role.

The **systemd service** starts/restarts the demonstration app. `/health` checks whether that app process serves requests. The normal page also tests its database dependency. A healthy probe with a failing database page is possible and intentional: they ask different questions.

## AWS comparison

This resembles ALB → private EC2 → private RDS, with IAM-role-based access to Secrets Manager. Azure uses Application Gateway, VNet subnets, managed identities and Key Vault. Do not copy AWS subnet/AZ or Internet Gateway configuration literally. Also, an Azure subnet NSG is not identical to an AWS instance security group.

## Where the training design stops

**Private** does not mean “secure against everything.” An authorized compromised VM can still misuse its access. The lab uses synthetic data, a simple Python server and an HTTP frontend. A production project needs suitable HTTPS termination, application authentication, runtime hardening, observability and tested recovery.

Two app VMs do not make a non-HA database highly available. The lab's database is intentionally small and non-HA; identify that remaining failure point before calling the whole system resilient.

## Check your understanding

1. Which service permits package downloads from the private VMs?
2. Why can `/health` be 200 while the application page returns 503?
3. Does a managed identity automatically have permission to read all secrets?

**Answers:** (1) NAT Gateway. (2) The process is alive but a dependency fails. (3) No; it needs the intended role at the intended scope.

**Ready for the lab:** You can explain the inbound path, outbound path and credential path separately.

Further reading: [NAT Gateway overview](https://learn.microsoft.com/en-us/azure/nat-gateway/nat-overview), [Key Vault overview](https://learn.microsoft.com/en-us/azure/key-vault/general/overview).
