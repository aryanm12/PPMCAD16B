# 01 - Azure Foundations: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values.

**Read before:** [Lab 01 - Preparation and cost controls](01-Lab-Preparation-and-Cost-Controls.md)  
**Reading time:** 10–12 minutes. Start here even if you already know AWS.

## What this lab is teaching

Before creating a server, you need to know **whose environment you are using, where resources belong, what you can access and who pays**. Lab 01 establishes those boundaries, then uses a small Storage example to practise them.

## The Azure organization model

| Term | Plain-language meaning | Example in your learning environment |
|---|---|---|
| Microsoft Entra ID | Azure's identity directory service: it authenticates users and application identities | Your sign-in account belongs to, or is a guest in, a directory |
| Tenant / directory | One organization's instance of that identity directory | A training organization can have one tenant with many learners |
| Subscription | A boundary for resource management, quotas and billing attribution | Your learning subscription contains the lab deployments |
| Management group | An optional governance scope above subscriptions | A company can apply common rules to several subscriptions |
| Resource | An individually manageable cloud item | A VM, disk, VNet or Storage account |
| Resource group (RG) | A lifecycle container for related resources within a subscription | `azlab01-preparation` holds the resources you will delete together |
| Region / location | An Azure geographic deployment area | Select **East US 2** in the Region dropdown |

```text
Microsoft Entra tenant: identities
    |
    +-- Subscription: learning environment
            |
            +-- Resource group: lab 01
            |       +-- Storage account
            |
            +-- Resource group: another lab
                    +-- VM + disk + network
```

A resource group is neither a network nor a VM folder on disk. Putting two resources in the same group does not automatically connect them. The group's location concerns its management metadata; individual resources have their own locations. Lab resources are grouped by lifecycle so cleanup is easier. Locks, dependencies and retention controls can still block or defer deletion. See [Resource Manager concepts](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/overview).

## Who is allowed to do what?

**Authentication** asks “Who are you?” **Authorization** asks “What may you do?” **RBAC** means role-based access control.

A role assignment combines:

```text
Principal (who) + Role (allowed actions) + Scope (where)
```

Example: “Give this learner **Storage Blob Data Reader** on **this Storage account**.” A subscription-level assignment can affect many more resources than an account-level assignment.

| Role | Useful meaning for the labs |
|---|---|
| Reader | Inspect resource configuration; does not automatically read stored business data |
| Contributor | Manage resources; normally cannot grant other people RBAC roles |
| Owner | Manage resources and assign access at its scope |
| Storage Blob Data Contributor | Read/write/delete blob data at its scope |

The **management plane** creates/configures resources. The **data plane** reads or changes the content those services hold. Being allowed to create a Storage account is different from receiving an Entra data role to download its blobs. Some management privileges can also expose account keys, so treat powerful management access carefully. These labs explicitly use identity-based data access. See [control and data planes](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/control-plane-and-data-plane).

## Storage vocabulary you will encounter

```text
Storage account → blob container → blob
                 practice         hello.txt
```

A **Storage account** establishes a service namespace and configuration. A **blob** is an object/file; a **container** groups blobs. For basic object storage, a blob container is closer to an S3 bucket than the entire Azure Storage account is. An account can expose other storage services too.

`Standard_LRS` is a storage **SKU**, meaning a selected service configuration. LRS means locally redundant storage. Redundancy protects against certain infrastructure failures; it is not a historical backup of a deleted file.

## Understand the portal before selecting Create

The **Azure portal** is the browser management console at portal.azure.com. Its top search bar finds services such as Resource groups and Storage accounts. A resource's left menu opens pages such as Overview, Networking, Access control (IAM), Monitoring and Properties. In these guides, an arrow means select the next item, for example **Resource groups → Create**.

A creation wizard has tabs. **Basics** identifies subscription, resource group, name and Region; later tabs configure networking, access and cost-related options. **Review + create** validates the form; the final **Create** starts a real deployment and may start billing. A green validation check is not the same as a completed deployment.

Use **Notifications** and **Go to resource** to follow completion. If it fails, open the deployment error and correct the specific field, permission, policy or quota problem. Do not repeatedly create duplicate resources because the page is still processing.

Keep a local worksheet of your chosen names, Region and subscription. A placeholder such as `YOUR-STORAGE-ACCOUNT` means substitute the actual name you recorded. Refreshing your browser does not delete resources. Deletion requires a separate action and confirmation; verify the resource disappears afterward.

**Run Command** in later VM labs is a portal feature that runs a supplied Linux script inside a VM using its agent. It is used for guest software, not as the resource-provisioning interface. SQL runs in a database client. Each hands-on identifies where those necessary code blocks belong.

## Costs and access constraints

A **tag** is a key/value label such as `Lab=01`. It helps identify resources; it does not create a deletion schedule. Group tags do not automatically become resource tags.

A **budget** sends spending notifications. It is not a prepaid balance or an automatic shutdown switch. **Quota** limits available capacity; **Azure Policy** can restrict configurations; a **resource provider** such as `Microsoft.Compute` supplies a family of resource types and may need subscription registration. A failure in one of these areas is not fixed by choosing a stronger VM password.

## AWS connection—and limits of the comparison

An Azure subscription is a useful first comparison to an AWS account for resources/billing, but tenant identity and subscription organization differ. An Azure resource group is **not** the same thing as an AWS VPC, nor an exact equivalent of AWS tag-based Resource Groups. Azure portal serves the same learning role as the AWS Management Console, with Azure-specific pages and permissions.

## Check your understanding

1. Does creating a resource group create a server or a network?
2. Can you assume Contributor permits role assignments and blob reads?
3. Why inspect the resource list before deleting the group?

**Answers:** (1) No; it creates a management container. (2) No; check role-assignment and data permissions separately. (3) Group deletion targets the resources inside it, including anything accidentally placed there.

**Ready for the lab:** You can identify tenant, subscription, resource group and Region, explain your role's scope, and recognize which portal actions create or delete resources.

Further reading: [Azure RBAC overview](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview), [Storage account overview](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview).
