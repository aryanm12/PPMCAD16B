# Lab 15 - Service Bus, Functions, Duplicate Protection and DLQ Recovery

**Read first:** [Brief notes - concepts for this lab](15-Service-Bus-Functions-and-Dead-Letter-Recovery-brief-notes.md)

**How to work:** Use Azure portal for resource administration and service tests. The code-publishing section explains the necessary Visual Studio Code graphical workflow; no Azure CLI commands are required.

## Outcome

Send an order to a Service Bus queue, process it with a Function and atomically create one Azure Table record. Repeat the order without duplicating the result. Cause a failure, inspect the dead-letter subqueue, repair the function and replay the message.

**Time:** 75–120 minutes. **Costs:** Service Bus Standard, Functions Elastic Premium EP1 (standing compute charge), Storage and telemetry. EP1 is selected for a consistent Python deployment workflow, not because a small queue inherently requires Premium compute.

## Prerequisites

- Contributor plus role-assignment permission; Web, Storage, ServiceBus, Insights providers registered.
- Access to [Azure portal](https://portal.azure.com) with your learning subscription selected. Keep a local worksheet of the resource names you choose.
- Access to [Azure portal](https://portal.azure.com) with your learning subscription selected. Keep a local worksheet of the resource names you choose.

## Lab 1 - Create queue, table storage and function app

1. Portal **Resource groups → Create**; select your learning subscription, name `azlab15-messaging`, Region **East US 2** (or a Region supporting these services); **Review + create → Create**.
2. Search **Function App → Create**; select **Functions Premium**. Select the group/Region; globally unique app name `azlab15-fn-yourinitials1234`. Record the accepted name.
3. Runtime **Python**, version **3.11** if offered; otherwise choose a supported Python version from the dropdown and install that same version locally. OS **Linux**. Create plan `lab15-plan`, pricing **EP1**. Do not substitute Flex Consumption.
4. **Storage**: create a unique general-purpose v2 account, for example `azlab15yourinitials1234`, **Standard LRS**; record its name. Leave the wizard's host-storage connection configuration intact; application data roles are separate from host-storage access.
5. **Networking**: public access enabled for this sandbox. **Monitoring**: enable Application Insights in the same group; record its linked workspace. **Review + create → Create**. Wait for success and record the exact app hostname from Overview. Premium compute charges continue while idle.

6. Portal **Service Bus → Create**: same group/Region, unique namespace `azlab15-yourinitials1234`, **Standard** tier; **Review + create → Create**. Record the namespace hostname from Overview.
7. Namespace → **Queues → + Queue**, name `orders`, maximum delivery count `3`, lock duration **1 minute**, duplicate detection disabled; **Create**. If advanced options appear only after creation, set them under queue **Properties → Save** before sending.
8. Function App → **Identity → System assigned → On → Save**; record principal ID.

Select a supported Python runtime in the portal and use the same version in your local project.

## Lab 2 - Grant distinct data roles

For each table row open the stated resource → **Access control (IAM) → Add role assignment**, select exact role → **Next**. For the function select **Managed identity → Select members → Function App → your lab app**; for yourself choose **User, group, or service principal → your signed-in user**. **Review + assign** and verify member, role and scope. Allow several minutes for propagation.

| Scope to open | Member | Role |
|---|---|---|
| Service Bus namespace → Queues → orders | Function identity | Azure Service Bus Data Receiver |
| Storage account | Function identity | Storage Table Data Contributor |
| Service Bus namespace → Queues → orders | Your user | Azure Service Bus Data Sender |
| Service Bus namespace → Queues → orders | Your user | Azure Service Bus Data Receiver |
| Storage account | Your user | Storage Table Data Contributor |

Contributor alone cannot grant these roles; the operator needs role-assignment permission.

After propagation, create the table:

1. **Storage account → Storage browser → Tables**; use **Microsoft Entra user account** authentication; **Add table**, name `orders`, create. If creation is under **Data storage → Tables**, use that blade and verify the result in Storage browser.
2. **Function App → Settings → Environment variables → App settings → Add**. Add each setting below. Replace uppercase placeholders with recorded names; preserve the double underscore. **Apply → Confirm**; the app restarts.

| Name | Value |
|---|---|
| ServiceBusConnection__fullyQualifiedNamespace | YOUR-NAMESPACE.servicebus.windows.net |
| TABLE_ENDPOINT | https://YOUR-STORAGE-ACCOUNT.table.core.windows.net |
| TABLE_NAME | orders |
| FAIL_DEMO | true |

Do not add a Service Bus connection string or shared-access key. Leave host settings such as AzureWebJobsStorage intact.

Do not create an app setting named exactly `ServiceBusConnection` with a connection string; that would override/confuse the identity-based prefix. The Functions host's own Storage connection was set by app creation; business table access here uses managed identity.

## Lab 3 - Deploy the consumer

**Publishing exception:** Python Functions source is authored and published outside the portal. Use Visual Studio Code's graphical extension; no Azure CLI commands are needed. Resource settings and service tests stay in the portal.

1. Install [Visual Studio Code](https://code.visualstudio.com/) and [Python](https://www.python.org/downloads/) matching the app runtime. On Windows enable Python's PATH option. In VS Code **Extensions**, install Microsoft's **Python** and **Azure Functions** extensions and their required Azure dependencies.
2. In your file manager create an empty `azlab15-code` folder. VS Code **File → Open Folder**, choose it and trust your own folder.
3. **View → Command Palette → Azure Functions: Create New Project**. Choose this folder, **Python**, **Model V2** if asked, and the matching interpreter. Choose **Skip for now** for the trigger if offered; otherwise generate the default HTTP trigger, which the complete code below replaces. Accept generated project files. If prompted to install Azure Functions Core Tools, follow the extension's installation guidance; you do not need to type a deployment command.
4. In the **Azure** sidebar select **Sign in to Azure**; complete browser sign-in with the same tenant/subscription as the portal. Select the correct subscription filter.
5. In Explorer replace the following three files. Keep generated `.vscode` configuration and `.funcignore`; ensure none of these source files are excluded. Keep secrets out of source and `local.settings.json`.

Create/replace **host.json** at the project root:

```json
{
  "version":"2.0",
  "extensionBundle":{"id":"Microsoft.Azure.Functions.ExtensionBundle","version":"[4.0.0, 5.0.0)"},
  "extensions":{"serviceBus":{"prefetchCount":0,"maxConcurrentCalls":1}}
}
```

Create/replace **requirements.txt** at the project root:

```text
azure-functions
azure-identity
azure-data-tables
```

Create/replace **function_app.py** at the project root:

```python
import json
import os
import logging
import azure.functions as func
from azure.identity import ManagedIdentityCredential
from azure.data.tables import TableClient
from azure.core.exceptions import ResourceExistsError

app = func.FunctionApp()
table = TableClient(endpoint=os.environ['TABLE_ENDPOINT'],
                    table_name=os.environ['TABLE_NAME'], credential=ManagedIdentityCredential())

@app.service_bus_queue_trigger(arg_name='message', queue_name='orders', connection='ServiceBusConnection')
def process_order(message: func.ServiceBusMessage):
    order = json.loads(message.get_body().decode('utf-8'))
    order_id = order['order_id']
    if not isinstance(order_id, str) or not order_id or any(c in order_id for c in '/\\#?'):
        raise ValueError('Invalid order ID')
    if order.get('simulate_failure') and os.environ.get('FAIL_DEMO') == 'true':
        logging.error('Controlled failure for %s', order_id)
        raise RuntimeError('Controlled lab error')
    try:
        table.create_entity({'PartitionKey':'orders', 'RowKey':order_id, 'Status':'CONFIRMED'})
        logging.info('CREATED %s', order_id)
    except ResourceExistsError:
        logging.info('DUPLICATE_SKIPPED %s', order_id)
```

1. Save all files. **View → Command Palette → Azure Functions: Deploy to Function App**. Choose this project, subscription and the **existing app created above**, not Create new.
2. Confirm the target name and deployment. The extension packages the project and requests a remote build for Python dependencies. Watch **View → Output → Azure Functions** for completion; inspect any build errors before retrying.
3. In the portal refresh **Function App → Functions** and wait for discovery. If missing, check deployment logs, Python versions and that host.json, requirements.txt and function_app.py are at the project root.

Reference: [Microsoft's Visual Studio Code Functions workflow](https://learn.microsoft.com/en-us/azure/azure-functions/functions-develop-vs-code).

The row key is the stable business ID. `create_entity` atomically fails if that entity exists. We do not perform an external payment/email after writing a separate “processed” marker; such a design has additional crash/transaction concerns.

1. In the portal verify `process_order` is discovered.
2. Enable Application Insights if app creation did not configure it: app → Application Insights → Turn on → create in this group.
3. Inspect invocation logs. A failed function invocation leaves the message for retry according to the trigger/broker behavior; this code must raise the error, not swallow it as success.

## Lab 4 - Send an order with Service Bus Explorer

In the Azure portal:

1. Portal **Service Bus namespace → Queues → orders → Service Bus Explorer**. In settings select **Microsoft Entra ID** authentication for your operator user.
2. **Send messages**: content type `application/json`, Message ID `normal-001`, count `1`, body below. Select **Send** and confirm success.

```json
{"order_id":"order-001"}
```

The Function is the active consumer. Do not manually receive active messages during normal processing.

## Lab 5 - Validate successful and duplicate processing

1. Storage account → **Storage browser → Tables → orders**, authenticate with Entra user account if prompted.
2. Refresh/query; expect partition `orders`, row `order-001`, Status CONFIRMED.
3. Function logs should contain `CREATED order-001`.
4. Use **Service Bus Explorer → Send messages** again with the same order-001 body, but Message ID `normal-001-retry`.
5. Expect `DUPLICATE_SKIPPED order-001` and still one table row.

## Lab 6 - Fail into the dead-letter subqueue

In **Service Bus Explorer → Send messages**, content type `application/json`, Message ID `failure-002`, count `1`, send:

```json
{"order_id":"order-002","simulate_failure":true}
```

1. Inspect function logs for controlled failures.
2. Wait for broker delivery attempts to exceed the configured maximum. Lock handling, invocation timing and backoff mean this is not an exact minute timer.
3. Namespace → queue `orders` → inspect dead-letter message count. Service Bus uses a built-in **subqueue**, not a separately provisioned SQS-style DLQ.
4. Inspect the message:

In **Service Bus Explorer → Peek mode**, select **Dead-letter → Peek from start**. Select the message and inspect body, delivery count and DeadLetterReason without consuming it.

5. Expect the order-002 body. Peek does not consume/delete the message.
6. Verify no order-002 table entity exists yet. Do not repeatedly receive from the main queue while the Function is the intended consumer.

## Lab 7 - Repair and replay

**Function App → Settings → Environment variables → App settings**: edit `FAIL_DEMO` to lowercase `false`; **Apply → Confirm** and wait for restart.

1. Wait for the app's settings update/restart and healthy function host.
2. Replay using the portal:

1. **Service Bus Explorer → Dead-letter → Peek from start**. Select only `order-002` → **Re-send selected messages**. Keep the body; use fresh Message ID `recovery-002` if prompted. Send one copy to the original queue.
2. Re-send leaves the original in the DLQ. Refresh Storage browser and logs; wait until `order-002` is CONFIRMED before removing that original.
3. Switch Explorer to **Receive mode**, choose **Dead-letter**, **Peek-lock**, count `1`; receive and inspect the body. Confirm this is the recovered order, then select **Complete** to remove the locked original. If its lock expired, receive again and complete. Do not use Receive-and-delete or purge. Refresh the DLQ count until zero.
4. If send or business processing fails, leave the original for investigation. Retrying may duplicate a delivery; the atomic table insert handles that here.

[Service Bus Explorer documentation](https://learn.microsoft.com/en-us/azure/service-bus-messaging/explorer) explains re-send and settlement.

3. Verify order-002 is now CONFIRMED, logs show CREATED and the DLQ drains.
4. Send the same order-002 failure-test body again through **Service Bus Explorer**, Message ID `failure-002-retry`, with failure mode disabled. Expect duplicate skipped and still only two business rows.

Replay sends before completing the DLQ copy to avoid losing the message on a failed send. A crash between send and complete can replay twice; atomic business-key creation handles that duplicate here. This is not a universal exactly-once guarantee for external side effects.

## Troubleshooting

| Symptom | Correction |
|---|---|
| Function does not start | Check remote build, extension bundle, Python version and discovered function logs. |
| Service Bus authorization error | Correct function principal, Data Receiver scope, identity-setting prefix and propagation. |
| Table operation denied | Storage Table Data Contributor for the function, correct endpoint/table. |
| Operator denied | Operator user needs Sender and Receiver; it is not the Function identity. |
| DLQ stays empty | Confirm errors are raised, max-delivery count, function running and sufficient time. |
| Replay loops back to DLQ | Ensure FAIL_DEMO is lowercase false and new settings are applied before replay. |

## Cleanup

1. Portal **Resource groups → azlab15-messaging → Overview**. Review the full resource list and confirm this is only your lab.
2. Select **Delete resource group**, type `azlab15-messaging`, and confirm **Delete**.
3. Wait for **Notifications** to report success; refresh **Resource groups** and **All resources** for this subscription and verify absence. Inspect any deletion error rather than assuming the resources are gone.

Delete resource group `azlab15-messaging` and verify absence. Confirm **Premium plan**, function, namespace, Storage and Application Insights/workspace are gone. Remove the local source project files if no longer needed; none should contain keys.

## Completion checklist

- [ ] Normal message creates a row; duplicate does not.
- [ ] Controlled failure reaches DLQ.
- [ ] Repaired/replayed order creates its missing row.
- [ ] Two unique business rows verified.
- [ ] All chargeable resources removed.

## References

- [Functions Service Bus bindings](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-service-bus-trigger)
- [Identity-based Functions connections](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference#configure-an-identity-based-connection)
- [Service Bus Python client](https://learn.microsoft.com/en-us/python/api/overview/azure/servicebus-readme)
- [Azure Tables Python client](https://learn.microsoft.com/en-us/python/api/overview/azure/data-tables-readme)
