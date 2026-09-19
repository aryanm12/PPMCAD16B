# Lab 01 - Azure Subscription, Portal Navigation and Cost Controls

**Read first:** [Brief notes - concepts for this lab](01-Lab-Preparation-and-Cost-Controls-brief-notes.md)

**How to work:** Use Azure portal and your browser. Any website or sample text files are created in a local text editor; no command-line setup is required.

## Outcome

Select the correct subscription, inspect your access, create a budget, deploy/tag a small resource and remove it. No prior Azure lab is needed.

**Time:** 30–45 minutes. **Cost:** Small Storage transaction/storage charges. Budget alerts do not stop spending.

## Prerequisites

- An active Azure subscription and access to [Azure portal](https://portal.azure.com).
- Contributor on your learning resource group or subscription for resource creation. Creating resource groups requires subscription-level permission.
- Cost Management permissions to create budgets. Assigning RBAC roles in later guides requires Owner, Role Based Access Control Administrator or User Access Administrator at the relevant scope; Contributor alone is insufficient.
- Use a sandbox, not a production resource group. If permissions are denied, an account administrator must supply the missing access; do not grant yourself broad roles as a workaround.

## Lab 1 - Identify tenant and subscription

1. Sign in. Open **Subscriptions** and select the intended subscription.
2. Record subscription ID, subscription name and tenant/directory ID in `azure-lab-record.txt` on your computer.
3. Open **Access control (IAM) → View my access**. Record your effective roles and their scopes.
4. Under **Usage + quotas**, inspect regional compute quota. Later VM exercises require a few available vCPUs.
5. Select a Region such as **East US 2** (`eastus2`) for the learning path. If a required SKU is unavailable, choose an allowed Region that supports that lab's services before creating resources.

Worksheet:

```text
Tenant ID:
Subscription ID/name:
Identity:
Roles and scope:
Region:
Lab resource group:
Resource / ID / purpose / cleanup status:
```

## Lab 2 - Create your first resource group

1. In [Azure portal](https://portal.azure.com), search **Resource groups → Create**. Select your learning subscription, name `azlab01-preparation`, Region **East US 2** (or the supported Region chosen for this lab). Select **Review + create → Create**.
2. Open the group → **Tags**; add `Project=AzureHandsOn` and `Lab=01`; **Apply**. Keep all resources below in this subscription, group and Region. Record names in your lab worksheet.

Expected: the new group appears under the intended subscription. Open its Overview and verify the location and tags. Portal creation is asynchronous; use Notifications and the deployment page to check completion.

4. Open **Resource groups → azlab01-preparation** and verify location/tags.
5. Resource provider registration: under **Subscription → Resource providers**, register `Microsoft.Compute`, `Microsoft.Network`, `Microsoft.Storage`, `Microsoft.Web`, `Microsoft.DBforMySQL`, `Microsoft.KeyVault`, `Microsoft.ServiceBus`, `Microsoft.RecoveryServices`, `Microsoft.Insights` and `Microsoft.ApiManagement` as needed for later labs. Registration is a subscription operation; if denied, request the specific registration from your administrator.

## Lab 3 - Create a cost budget

1. Open **Cost Management + Billing → Cost Management → Budgets**.
2. Set the scope to your learning **subscription**, not merely the resource group.
3. Choose **Add**. Name `azure-learning-monthly`; reset period Monthly; start this month and choose an end date after your course.
4. Set an amount suited to your account, for example **10 in the displayed billing currency**. This is a notification threshold, not the expected cost of the course.
5. Add actual-cost alerts at **50%, 80%, 100%**. Add your email address to each alert.
6. Review/create; reopen the budget and verify scope, currency, thresholds and recipients.

Expected: budget visible with correct settings. Do not intentionally incur charges to trigger it. Cost data and notifications can be delayed.

## Lab 4 - Create and tag private storage

In the Azure portal:

1. Search **Storage accounts → Create**. Select lab subscription/group/Region. Choose a globally unique name such as `azlab01yourinitials1234` (3–24 lowercase letters/digits); record your actual name. Performance **Standard**, redundancy **LRS**, general-purpose v2. On **Tags**, add `Project=AzureHandsOn` and `Lab=01`; group tags do not automatically propagate to resources.
2. On **Advanced**, keep secure transfer required, minimum TLS **1.2**, and **Allow enabling anonymous access on individual containers** disabled. For this initial setup, **Networking → Public network access → Enable from all networks**. Private containers still require authorization.
3. **Review + create → Create**. Open **Overview** and verify deployment success. Use your recorded name wherever the guide says `YOUR-STORAGE-ACCOUNT`.

Storage account names must be globally unique, 3–24 lowercase letters/numbers. Record your chosen unique name. The private-container setting does not disable the account's public network endpoint; authorization and network access are separate.

1. Open the account → **Data storage → Containers → + Container**; name `practice`, anonymous access Private.
2. If the portal requires data permissions, open **IAM → Add role assignment**, select **Storage Blob Data Contributor**, choose your signed-in user and assign at this storage account. Wait several minutes for propagation. Do not use account keys to bypass the learning objective.
3. In the portal, select Microsoft Entra authentication explicitly:

1. On your computer, open a plain-text editor and save `hello.txt` containing `Azure lab 01`. In Windows Save As, choose **All files** to avoid a hidden `.txt` suffix.
2. In the storage account open **Data storage → Containers → + Container**, name `practice`, anonymous access **Private**, **Create** (skip creation if it already exists).
3. Open the container; choose **Switch to Microsoft Entra user account** if the page shows access-key authentication. Select **Upload → Browse for files**, choose `hello.txt`, then **Upload**. Refresh and confirm the blob name. Select the blob → **Download** and open it; verify the original content.

Expected: `Azure lab 01`. Keep credentials out of screenshots and notes.

## Lab 5 - Review costs and resource inventory

1. Open **Cost analysis**, scope your subscription, choose current month, group by Service name.
2. Change grouping to Resource group. Find your lab group if billing data has arrived.
3. Record `No data yet` if empty; do not confuse absence of data with guaranteed zero cost.
4. Inspect the inventory:

Open **Resource groups → azlab01-preparation → Overview**. Refresh the resource list and record each name, type and location.

5. Record each resource. Tags support ownership and cost analysis; a tag named `DeleteAfter` does not automatically delete anything.

## Troubleshooting

| Symptom | Correction |
|---|---|
| Wrong subscription | Open portal Settings → Directories + subscriptions; select the correct directory/filter, then check the Subscription field in the resource creation form. |
| Cannot create a group | Your role must allow resource-group creation at subscription scope. |
| Cannot assign a role | Contributor cannot grant RBAC. Obtain the specific role-assignment permission. |
| Blob operation denied | Confirm Blob Data Contributor, correct account and propagation; management-plane Contributor is different. |
| Storage name unavailable | Change the name suffix in the creation form and retry only storage creation. |
| Budget missing | Check billing scope and Cost Management access. |

## Cleanup

1. Open **Resource groups → azlab01-preparation → Overview**. Review the complete resource list and confirm it contains only this exercise.
2. Select **Delete resource group**, type `azlab01-preparation` to confirm, and select **Delete**.
3. Watch **Notifications** for successful deletion. Return to **Resource groups**, refresh, and verify the group is absent; also check **All resources** with the same subscription filter. If deletion failed, inspect the reported dependency/lock and resolve it before considering cleanup complete.

Expected: successful deletion notification and the resource group absent after refresh. Leave the course budget in place; delete it from Budgets when no longer needed.

## Completion checklist

- [ ] Correct tenant/subscription and access scope recorded.
- [ ] Budget configured and verified.
- [ ] Tagged storage created; authenticated upload/download works.
- [ ] Resource group deletion verified.
- [ ] You can explain management-plane vs data-plane access.

## References

- [Azure portal overview](https://learn.microsoft.com/en-us/azure/azure-portal/azure-portal-overview)
- [Create budgets](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets)
- [Assign blob data roles](https://learn.microsoft.com/en-us/azure/storage/blobs/assign-azure-role-data-access)
