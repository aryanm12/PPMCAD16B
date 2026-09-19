# Lab 04 - Functions, API Management, Canary Releases and Rollback

**Read first:** [Brief notes - concepts for this lab](04-Functions-API-Management-and-Deployment-brief-notes.md)

**How to work:** Use Azure portal for resource administration and service tests. The code-publishing section explains the necessary Visual Studio Code graphical workflow; no Azure CLI commands are required.

## Outcome

Deploy a Python HTTP function, publish it through API Management, inspect a controlled error, test a staging release, route a small share of API requests to staging, promote it and roll back.

**Time:** 90–150 minutes. **Costs:** Functions **Elastic Premium EP1** has standing compute charges even when idle; APIM Consumption and Storage/telemetry add usage charges. Delete the entire group after the exercise.

This guide explicitly uses a plan with deployment slots. **Flex Consumption does not provide deployment slots**; do not substitute it in these steps. APIM performs the demonstration's weighted routing, not a Lambda-style weighted function alias.

## Prerequisites

- Contributor with Web, Storage, Insights and ApiManagement providers registered.
- Access to [Azure portal](https://portal.azure.com) with your learning subscription selected. Keep a local worksheet of the resource names you choose.
- No prior function or API required. Function keys are credentials: keep them in APIM secret named values, not source code or screenshots.

## Lab 1 - Create the hosting resources

1. Portal **Resource groups → Create**; select your learning subscription, name `azlab04-api`, Region **East US 2** (or a Region supporting the required services); **Review + create → Create**.
2. Search **Function App → Create** and select hosting option **Functions Premium**. Select that group/Region; globally unique app name `azlab04-fn-yourinitials1234`. Record the accepted name.
3. Runtime **Python**, version **3.11** if offered; otherwise choose a currently supported Python version in the dropdown and install the same version locally. Operating system **Linux**. Create plan `lab04-plan`, pricing **EP1**. Do not accept a Flex Consumption substitution for this exercise.
4. On **Storage**, create a uniquely named general-purpose v2 account such as `azlab04yourinitials1234`, **Standard LRS**. Record its exact name. Leave the wizard's host-storage connection configuration in place. The application data roles below are separate from the Functions host's own storage configuration.
5. **Networking**: public access enabled for this sandbox. **Monitoring**: enable Application Insights, create in the same resource group; record any linked workspace. **Review + create → Create**. Wait for deployment success; open the app Overview and record the exact hostname. Premium billing continues while idle.

Record your app/storage names and Python version. The code uses the Python v2 programming model.

## Lab 2 - Write and deploy version 1

**Why this is the one publishing exception:** Python Functions source is authored and published outside the portal. Use the graphical Visual Studio Code extension; no Azure CLI commands are needed. All Azure resource settings and tests stay in the portal.

1. Install [Visual Studio Code](https://code.visualstudio.com/) and [Python](https://www.python.org/downloads/) matching the app's runtime version. On Windows enable Python's PATH option. In VS Code **Extensions**, install Microsoft's **Python** and **Azure Functions** extensions (accept their required Azure dependencies).
2. In your computer's file manager create an empty folder `azlab04-code`. VS Code **File → Open Folder**, choose it and trust your own folder.
3. Open **View → Command Palette → Azure Functions: Create New Project**. Choose this folder, **Python**, **Model V2** if asked, and the matching Python interpreter. Choose **Skip for now** for the trigger if offered; otherwise create the default HTTP trigger, which the complete `function_app.py` below will replace. Accept generation of the project files. If the extension prompts to install Azure Functions Core Tools, follow its installation prompt; local debugging uses that runtime, but you do not need to type a deployment command.
4. Open the **Azure** sidebar and **Sign in to Azure**; finish browser sign-in with the same tenant/subscription used in the portal. Select the correct subscription filter.
5. In **Explorer**, replace the following three files with the supplied contents. Keep the extension-generated `.vscode` configuration and `.funcignore`; ensure they do not exclude these three files. Do not put secrets in source or `local.settings.json`.

Create/replace **host.json** at the project root:

```json
{"version":"2.0"}
```

Create/replace **requirements.txt** at the project root:

```text
azure-functions
```

Create/replace **function_app.py** at the project root, then save:

```python
import json
import logging
import azure.functions as func

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

@app.route(route='orders', methods=['GET'])
def orders(req: func.HttpRequest) -> func.HttpResponse:
    if req.params.get('fail') == '1':
        logging.error('Controlled lab failure')
        return func.HttpResponse('Controlled lab error', status_code=500)
    logging.info('Orders endpoint served version v1')
    return func.HttpResponse(json.dumps({'version':'v1','message':'Orders API works'}),
                             mimetype='application/json')
```

1. Save all files. Open **View → Command Palette → Azure Functions: Deploy to Function App**. Select this project folder, the correct subscription and the **existing function app created above**. Do not choose Create new.
2. Review the target name; confirm deployment. The extension packages the project and requests a remote build for Python dependencies from `requirements.txt`. Watch **View → Output → Azure Functions** for successful completion; inspect build errors before retrying.
3. Return to the portal, refresh **Function App → Functions**, and wait for function discovery. If no function appears, inspect deployment logs and confirm the three files are at the project root, the Python versions match, and the remote dependency build succeeded.

Reference: [Microsoft's Visual Studio Code Functions workflow](https://learn.microsoft.com/en-us/azure/azure-functions/functions-develop-vs-code).

Wait for deployment completion. In the portal open the function app → **Functions → orders → Code + Test / Test/Run**, method GET, and run. Expect HTTP 200 with v1. If function discovery is still pending, wait and refresh; inspect deployment logs before redeploying.

## Lab 3 - Enable and inspect telemetry

1. In the function app open **Application Insights**. If not configured, choose **Turn on**, create an instance in the same group and apply.
2. Invoke `orders` again. Open **Monitor / Application Insights → Logs**.
3. In the Application Insights Logs query editor, run:

```kusto
traces
| where timestamp > ago(30m)
| where message contains "Orders endpoint" or message contains "Controlled lab"
| project timestamp, message, severityLevel
| order by timestamp desc
```

4. In the test panel add query parameter `fail=1` and run; expect HTTP 500. Verify the controlled-error log after ingestion delay.
5. Remove the parameter and verify HTTP 200. This exercises a failure without leaving broken code deployed.

If the portal is showing workspace-native tables, use `AppTraces` with columns `TimeGenerated`, `Message`, `SeverityLevel` instead. Select the Application Insights resource scope to use the query above.

## Lab 4 - Create and import into API Management

1. Portal **API Management services → Create**; group `azlab04-api`; unique name; same Region; your email/organization; pricing tier **Consumption**.
2. Review/create and wait until available. If Consumption is not offered, choose another supported Region before provisioning; do not silently accept a costly Developer/Premium tier.
3. Open APIM → **APIs → Add API → Function App**.
4. Browse to your function app, select `orders`, display name `Lab04 Orders`, API URL suffix `lab04`, and create.
5. Open the API **Settings**; keep **Subscription required** enabled.
6. Open **Test**, select GET operation and Send. Expect HTTP 200/v1.
7. Note the generated backend and secret named value created by the import. APIM sends the function key to the backend; clients use an APIM subscription key, which is a different credential.

The APIM test console supplies a subscription key for the selected subscription. For an external client, retrieve an authorized APIM subscription key and send it as `Ocp-Apim-Subscription-Key`; do not publish it in a URL or repository.

## Lab 5 - Create staging and version 2

In the Azure portal:

1. Portal **Function App → Deployment slots → Add slot**; name `staging`, clone settings from production, **Add**. Wait for creation.
2. In VS Code make a local backup of the v1 project outside the deployment folder. In `function_app.py`, change both occurrences of `v1` to `v2`; save.
3. In the **Azure** sidebar expand the subscription → Function App → your app → **Slots / Deployment slots**, refresh, and locate **staging**. Right-click the **staging slot** → **Deploy to Slot** (the extension may label the target action **Deploy to Function App**). Select the project folder. Confirm the deployment target explicitly includes staging; never choose the production app here.
4. Wait for successful deployment in **Output → Azure Functions**. If the slot is not listed, refresh the Azure tree and subscription filter before proceeding.

1. Open function app **Deployment slots → staging → Functions → orders** and Test/Run. Expect v2.
2. Test production through APIM; expect v1. The slot is a separate hostname/deployment.
3. Record both exact hostnames from their Overviews. Do not guess them from app names if the platform has assigned a different hostname format.
4. Open production **App keys** and staging **App keys**. In APIM **Named values**, create secret values `lab04-prod-key` and `lab04-stage-key` containing the corresponding default host keys. Never print them to logs.

## Lab 6 - Apply an API-level canary policy

1. In APIM select the imported API → **All operations → Inbound processing → Code editor**.
2. Save a local copy of the current policy (without resolved secret values).
3. Replace the policy with the following, substituting the two exact hostnames. Keep `{{...}}` named-value expressions literally as written:

```xml
<policies>
  <inbound>
    <base />
    <choose>
      <when condition="@((new Random()).Next(100) &lt; 10)">
        <set-backend-service base-url="https://YOUR-STAGING-HOSTNAME/api" />
        <set-header name="x-functions-key" exists-action="override"><value>{{lab04-stage-key}}</value></set-header>
      </when>
      <otherwise>
        <set-backend-service base-url="https://YOUR-PRODUCTION-HOSTNAME/api" />
        <set-header name="x-functions-key" exists-action="override"><value>{{lab04-prod-key}}</value></set-header>
      </otherwise>
    </choose>
  </inbound>
  <backend><base /></backend>
  <outbound><base /></outbound>
  <on-error><base /></on-error>
</policies>
```

4. If the imported API has an operation-level backend/key policy, remove or align that operation-level override so it does not supersede this All operations policy. Keep the GET operation's URL template `/orders`.
5. Save; invoke the APIM GET operation 30–50 times. Count v1/v2 responses. Around 10% are expected to use staging, but a small sample is not guaranteed to be exactly 90/10.
6. Test `fail=1` through APIM, inspect HTTP 500 and telemetry, then remove the parameter.

This is a teaching canary based on per-request random routing. Production releases need automated health criteria and a rollback decision, and may need stable per-user cohorts.

## Lab 7 - Promote and roll back

1. Replace the `choose` section with only the production `set-backend-service` and production `set-header` elements. Save. Verify all requests return v1 before swapping.
2. In function app **Deployment slots → Swap**, source staging, target production. Review and complete the swap.
3. Through APIM expect v2. Verify production key validity after the swap; if configuration/key behavior changed, update the secret named value using the production slot's current key. Do not disable function authentication to bypass a 401.
4. Swap the slots again to roll back. Through APIM expect v1.
5. Record before/after API responses. A slot swap may interrupt running invocations; it is not a guarantee that every request is uninterrupted.

## Troubleshooting

| Symptom | Correction |
|---|---|
| No function discovered | Zip must contain host.json/function_app.py/requirements.txt at root; inspect remote-build logs. |
| APIM 401 | Distinguish missing APIM subscription key from invalid backend function key. |
| APIM 404 | Verify imported operation `/orders`, API suffix and backend `/api` base path. |
| Only one release observed | Check policy placement, slot code, named values and sufficiently large sample. |
| Logs absent | Enable Application Insights, invoke again, allow ingestion time, check scope/table name. |
| Slot unavailable | Confirm Elastic Premium; Flex Consumption is not this lab's plan. |

## Cleanup

Delete `azlab04-api` in **Resource groups**: review its resources, choose **Delete resource group**, type its name and confirm. Wait for success and refresh the list to verify absence. Confirm APIM, **Premium plan**, slots, Storage and telemetry resources are gone. Remove local release files if not needed; they contain source, not credentials.

## Completion checklist

- [ ] Working API through APIM, controlled error and logs inspected.
- [ ] Separate staging release validated.
- [ ] Both versions observed through the same API during canary routing.
- [ ] Promotion and rollback validated through APIM.
- [ ] Premium compute and other resources deleted.

## References

- [Functions deployment slots](https://learn.microsoft.com/en-us/azure/azure-functions/functions-deployment-slots)
- [Python Functions programming model](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python)
- [Import Functions into APIM](https://learn.microsoft.com/en-us/azure/api-management/import-function-app-as-api)
- [APIM choose policy](https://learn.microsoft.com/en-us/azure/api-management/choose-policy)
- [APIM policy expressions](https://learn.microsoft.com/en-us/azure/api-management/api-management-policy-expressions)
