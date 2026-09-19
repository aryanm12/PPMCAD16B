# 04 - Functions, APIs and Releases: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values. Python code publishing uses the documented Visual Studio Code graphical extension; it does not require Azure CLI commands.

**Read before:** [Lab 04 - Functions, API Management and deployment](04-Functions-API-Management-and-Deployment.md)  
**Reading time:** 6–8 minutes. Review [foundation notes](01-Lab-Preparation-and-Cost-Controls-brief-notes.md) for subscription/RBAC basics.

## What you are building

A client calls an API Management endpoint. API Management applies its policies and forwards the request to a Python Function. You then change which release receives requests and observe the result through the same client-facing API.

```text
Client → API Management → production Function OR staging Function
                                 |
                                 +→ application telemetry
```

## Terms before deployment

| Term | Meaning |
|---|---|
| API | An interface through which a client asks an application to perform work |
| Endpoint / route | A URL path and HTTP method, such as GET `/orders` |
| Function | Code invoked by a trigger, such as an HTTP request |
| Function App | The Azure resource hosting one or more functions and their shared configuration |
| Hosting plan | The compute/scaling/billing arrangement for that app |
| Runtime | The language execution environment, such as Python |
| Trigger | What causes the function to run |
| API Management (APIM) | A gateway/control layer for publishing APIs and applying policies |
| Backend | The service APIM calls to handle a request |
| Policy | APIM instructions, such as changing headers or choosing a backend |
| Named value | Reusable APIM configuration; it can be marked secret for credentials |

**Serverless** means the platform handles much of the server lifecycle; it does not mean no servers or no idle charges. The lab chooses **Elastic Premium EP1**, which has standing compute costs and supports slots. Flex Consumption currently does not supply deployment slots and is not a drop-in substitution for this exercise. See [Functions hosting](https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale) and [deployment slots](https://learn.microsoft.com/en-us/azure/azure-functions/functions-deployment-slots).

## Understand the files

`function_app.py` defines the Python function and its route. `requirements.txt` lists Python dependencies. `host.json` configures the Functions host. Keep these files at the VS Code project root; the Azure Functions extension packages and publishes them through its graphical deployment action. **Remote build** installs/builds the dependencies in Azure's deployment environment.

**Application Insights** records application telemetry. A **log** records an event/message; a **metric** summarizes measurements over time. Logs may arrive after a delay, so an empty view immediately after a request is not conclusive.

## Two different credentials

The client may send an **APIM subscription key** to API Management. APIM sends a **Function key** to the Function backend. They authenticate different legs of the path and are not interchangeable. An APIM subscription is an API-access construct, not your Azure billing subscription.

Keys are shared secrets, not proof of a named human's identity. A real application may need token-based user/service authentication in addition to gateway controls. Do not paste keys into screenshots or source code.

## Release vocabulary

- **Staging slot:** a separate app deployment environment with its own hostname.
- **Canary:** expose a limited portion of requests to a candidate release before broader rollout.
- **Promotion:** make the candidate the main release.
- **Rollback:** return traffic to a known-good release.
- **Slot swap:** exchange deployment roles/configuration according to the platform's swap behavior; it is not a database rollback.

The lab's approximate 90/10 routing is an APIM policy. It is not a direct copy of Lambda weighted aliases. A small request sample need not split exactly 90/10. A slot swap also does not guarantee that every in-flight invocation completes uninterrupted.

## AWS connection

Functions fills a similar compute role to Lambda; API Management fills a similar gateway role to API Gateway. Function Apps, hosting plans and slots have their own lifecycle. Application Insights/Azure Monitor cover observability responsibilities familiar from CloudWatch, but their telemetry/query models differ.

## Check your understanding

1. What does a successful direct Function test fail to prove about APIM?
2. Is a staging slot an immutable Lambda version?
3. If rollback restores old code, has it undone database writes?

**Answers:** (1) APIM routing, policy and credentials still need testing. (2) No; it is a deployable environment. (3) No; data changes require their own compatible release/recovery strategy.

**Ready for the lab:** You can distinguish the client URL, backend URL, two keys and two releases.
