# 11 - Managed Identity and RBAC: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values. Supplied guest scripts run through the VM’s portal Run command page to install or test software inside the VM.

**Read before:** [Lab 11 - Managed identity, RBAC and VM operations](11-Managed-Identity-RBAC-and-VM-Operations.md)  
**Reading time:** 5–7 minutes. Read [foundation notes](01-Lab-Preparation-and-Cost-Controls-brief-notes.md) for tenant/subscription and access scopes.

## What problem are we solving?

An application needs to read a file from Storage. You could copy an account key into its source, but that creates a powerful secret to protect and rotate. Instead, the VM uses its own managed identity to obtain a temporary token and receives only the data role needed for one container.

```text
VM identity → temporary Storage token → blob request
                                      |
                                      +→ Azure checks role + scope
```

## Identity vocabulary

| Term | Meaning |
|---|---|
| Principal | The identity receiving permission: a user, group or application identity |
| Service principal | An application/service identity represented in a tenant |
| Managed identity | A service identity whose credential management Azure handles |
| System-assigned identity | Tied to the lifecycle of its owning resource, such as this VM |
| User-assigned identity | A separately created managed identity that can be attached to supported resources |
| Object/principal ID | The identifier used to refer to the actual identity in role assignments |
| Access token | A temporary credential presented to a service |
| Audience/resource | The service for which that token is intended |
| Role assignment | A principal, a role and the scope where it applies |

A display name is not the same as the principal's ID. Granting a similarly named identity does not grant the intended VM. See [managed identity overview](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview).

## How the VM obtains a token

The code contacts the **Instance Metadata Service (IMDS)** at a link-local address accessible from the VM. It requests a token for Storage. The script should run on the VM, not on your own computer. A token intended for Key Vault would not simply substitute for a Storage token.

The token must not be printed to logs. It is temporary, but still authorizes requests while valid. Managed identity removes the need to embed an application login secret; it does not make a compromised application harmless.

## Why one request succeeds and two fail

The VM receives **Storage Blob Data Reader** at the `allowed` container scope. It can read that container's test object, but it receives no grant to read the other container or overwrite the blob.

Your signed-in operator has a different role allowing setup/uploads. Therefore “my portal upload works” is not evidence that “the VM can upload.” Always identify the principal making the specific request.

Management-plane Contributor is also different from a blob data role. The lab explicitly uses Entra data authorization rather than falling back to Storage account keys.

## Run Command versus a terminal session

**Run Command** sends an administrative script to the VM agent. For the Linux exercise it runs with powerful guest privileges. It does not require opening inbound SSH, but it does require working agent/platform connectivity and appropriate operator permissions.

It is not an interactive Session Manager shell. The Python code placed in its script block runs inside the VM, so it can use that VM's metadata identity endpoint.

## Read failure signals correctly

- **200:** the request succeeded.
- **403:** access was refused; investigate authorization and service network controls.
- **404:** check the object/path, while remembering some services can mask access details.
- **Timeout:** investigate reachability/DNS/endpoint availability before editing RBAC.

Role changes can take time to propagate or be affected by cached authorization. Repeated immediate retries are not proof that the scope is wrong. Equally, do not solve a denied write by assigning Owner when the expected outcome is a denied write.

## AWS connection

An EC2 instance role is a useful mental comparison for a VM managed identity obtaining temporary credentials. Azure's role definitions/scopes, token audiences and principal representation differ from IAM policies/instance profiles. Run Command and Session Manager also have different interaction models.

## Check your understanding

1. Does turning on a VM identity grant it access to every Storage account?
2. Whose identity does the blob-reading code use when run inside the VM?
3. Why is a denied write a successful lab result?

**Answers:** (1) No, grant the appropriate data role. (2) The VM managed identity. (3) The role should permit only reading the intended scope.

**Ready for the lab:** You can name the operator principal and VM principal separately and predict each tested operation's result.

Further reading: [Azure role assignment concepts](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments), [VM Run Command](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/run-command).
