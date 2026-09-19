# Lab 09 - Design and Review an Azure Ticket-Booking Platform

**Read first:** [Brief notes - concepts for this lab](09-Architecture-Design-Workshop-brief-notes.md)

**How to work:** Complete the design worksheets; use Azure portal to explore the relevant service settings. This exercise requires no command-line tools.

## Outcome

Produce a requirements sheet, Azure architecture diagram, decision records, failure/recovery runbook and cost assumptions. Compare your work with the reference design and score it without a trainer.

**Time:** 90–120 minutes. **Cost:** None; this is a design workshop, not a provisioning lab. Use diagrams.net, PowerPoint, a text editor or paper.

## Prerequisites

- A diagramming tool or paper, and a text editor for worksheets.
- Basic familiarity with compute, networking, databases and backups. The service mapping/reference solution below supplies the Azure context.
- No Azure subscription, deployed resources or trainer is required.

## Scenario

A ticket platform serves customers in several countries. Traffic peaks when tickets go on sale. A seat must not be sold twice. An external provider collects payments. The application must withstand a zone failure, recover accidental data deletion and control costs during quiet periods.

Use these exercise assumptions rather than silently inventing requirements:

| Requirement | Value |
|---|---|
| Normal traffic | 20 requests/second |
| Sale opening | 1,000 requests/second for 15 minutes |
| Booking data loss objective | RPO 15 minutes for regional disaster; no duplicate confirmed seat |
| Recovery objective | RTO 2 hours for regional disaster |
| Availability | Survive one application-zone failure |
| Data residency | Primary data stays in an approved geography; DR location must also be approved |
| Payment handling | Provider stores card details; app stores provider references |
| Cost | Scale with demand; quantify the always-on baseline before deployment |

These numbers are design inputs, not performance promises for a particular SKU.

## Lab 1 - Separate requirements from implementation

Create `requirements.md` with one row per requirement:

```text
Requirement | Business reason | Proposed control | Evidence needed | Unknowns
```

Example:

```text
No duplicate seat | Customer trust | Transaction/unique seat constraint |
Concurrent booking test | Exact isolation/locking strategy
```

Add at least eight rows. Include peak traffic, security, zone failure, accidental deletion, regional recovery, observability, external payment failure and deployment rollback.

## Lab 2 - Draw the request and data paths

Draw these distinct boundaries:

1. Internet users and identity provider.
2. Global edge delivery and WAF attachment.
3. Regional ingress.
4. Application compute across zones.
5. Transactional database.
6. Object storage.
7. Messaging and consumers.
8. Management/identity/secrets.
9. Monitoring/audit and recovery resources.

Label arrows with protocol, direction and authentication. A WAF policy is attached to an ingress service; it is not an independent network hop with its own backend.

## Lab 3 - Select services by responsibility

Fill in your own choices before consulting the reference solution:

| Responsibility | Your choice | Reason / rejected alternative |
|---|---|---|
| DNS | | |
| Global HTTPS/static delivery | | |
| Web protection | | |
| Regional HTTP ingress | | |
| Replaceable compute | | |
| Transactional seat inventory | | |
| Asynchronous notifications | | |
| Shared session/cache if needed | | |
| Identity/secret access | | |
| Metrics/logs/audit | | |
| Historical data recovery | | |

Do not insert a cache unless you explain consistency, invalidation and why it is necessary. The source of truth for remaining seats must not be a stale cache.

## Lab 4 - Design the booking consistency boundary

Write pseudocode for a database transaction with these properties:

1. Stable client idempotency key is stored with a unique constraint.
2. Seat assignment is protected by a unique key/transactional lock or equivalent conditional update.
3. A competing booking receives a controlled conflict instead of two confirmations.
4. The payment reference is stored and reconciled after timeout.
5. Notification publication cannot be silently lost after commit.

Suggested table responsibilities:

```text
Seats(event_id, seat_id, status) -- unique event/seat
Bookings(booking_id, request_key, event_id, seat_id, state, payment_reference)
Outbox(event_id, booking_id, event_type, published_at)
```

One possible approach is to reserve a seat in a short DB transaction, persist a booking/request key, call the payment provider with its own idempotency key, then confirm or compensate based on the provider outcome. Do not hold a database transaction open for an arbitrary remote payment call.

An outbox row written in the same commit as confirmation can be dispatched later. Consumers must tolerate duplicate dispatch. A unique booking key alone does not solve every payment timeout/reconciliation case.

## Lab 5 - Analyse failures

Complete this table for your design:

| Failure | User impact | Detection | Immediate action | Data/recovery concern |
|---|---|---|---|---|
| One app VM fails | | | | |
| One zone fails | | | | |
| Database unavailable | | | | |
| Payment succeeded but response timed out | | | | |
| Consumer fails repeatedly | | | | |
| Private DNS link removed | | | | |
| Accidental DELETE | | | | |
| Entire primary Region unavailable | | | | |

Separate restart/retry, failover and historical restore. They are not interchangeable actions.

## Lab 6 - Define observable evidence

For at least six signals record **threshold, window, action and owner**:

- Gateway 5xx/error rate and backend health.
- API latency and successful booking rate.
- DB connections/CPU/lock contention.
- Service Bus oldest-message age, active and dead-letter count.
- Payment reconciliation backlog.
- Deployment version/error comparison.
- Backup failures and restore-test results.

Example: “DLQ count > 0 for 5 minutes → investigate consumer error and affected order IDs; fix before replay.” Do not claim delivery success merely because a message left the source queue.

## Lab 7 - Write two architecture decision records

Use this template twice:

```text
Title:
Context and measurable requirement:
Options considered:
Decision:
Reason:
Cost/operational consequence:
Failure behavior:
How to validate:
When to revisit:
```

Suggested decisions: VMSS vs Functions; managed MySQL vs Azure SQL; private origin Front Door vs public origin; asynchronous notification vs synchronous booking consistency.

## Lab 8 - Worked reference solution

Compare rather than copy blindly:

```text
Users → Azure DNS → Front Door Premium with WAF policy
                         |
                         +→ Storage static assets through supported Private Link origin
                         |
                         +→ Regional Application Gateway → VMSS across zones
                                                              |
                                                              +→ MySQL Flexible Server, zone-redundant HA
                                                              +→ transactional outbox → Service Bus → Functions
                                                              +→ managed identity → Key Vault
Azure Monitor / Application Insights: application + dependency signals
Activity Log: management operations
Native DB backups/PITR + tested regional recovery: historical data protection
```

This is a logical reference. The exact Front Door-to-regional-ingress network/security configuration must be designed and validated separately; do not assume any diagram arrow automatically creates Private Link support.

Reference reasoning:

- VMSS holds no unique booking/session data, so replacement is safe.
- Database transaction/constraints protect seats; idempotency protects retries.
- Payment state remains explicit; uncertain payment responses trigger reconciliation instead of blind recharging.
- Notifications are asynchronous; core seat consistency remains in the transactional boundary.
- Managed identities use scoped data permissions; Key Vault stores credentials where DB-native identity is not used.
- Private DNS and outbound dependencies are part of the design, not afterthoughts.
- DB HA handles supported infrastructure failures; PITR handles historical corruption/deletion. Regional recovery needs network, identities, keys, configuration and tested endpoint changes as well as data.
- Two-hour regional RTO is an objective requiring measured evidence. Do not certify it from a service diagram.

Alternative designs using App Service, Container Apps, AKS, Azure SQL or Cosmos DB can be valid if they meet the same requirements and explain consistency, networking, cost and recovery tradeoffs.

## Lab 9 - Self-assessment rubric

Score each area 0–2: **0 missing; 1 named but unproven; 2 mechanism and validation explained**.

| Area | Maximum |
|---|---:|
| Requirements trace to controls | 2 |
| Request/data/security boundaries | 2 |
| Concurrent seat consistency | 2 |
| Payment timeout/idempotency | 2 |
| Duplicate/retry/DLQ behavior | 2 |
| Zone failure across critical tiers | 2 |
| Historical and regional recovery | 2 |
| Identity/network/secret separation | 2 |
| Monitoring tied to actions | 2 |
| Cost assumptions and tradeoffs | 2 |

Target at least 16/20, with no zero in consistency, payment handling or recovery. For every point lost, write a concrete change/test. This is a learning rubric, not a formal certification.

## Troubleshooting your design

| Weak answer | Improve it by |
|---|---|
| “Use autoscaling” | State metric, bounds, provisioning delay and downstream DB limit. |
| “Use backup” | State restore point, restore steps, dependencies, validation and measured time. |
| “Retry payment” | Define provider idempotency and status reconciliation first. |
| “Use private endpoints” | Identify service/subresource, DNS zone/link and client authorization. |

## Cleanup and completion

No Azure resources were created. Save your requirements, diagram, two ADRs, failure table and rubric score. If you opened unrelated portal resources for research, do not modify them.

- [ ] Every requirement has a control and validation method.
- [ ] Payment and booking failure cases are explicit.
- [ ] Restore runbook includes actual data/application checks.
- [ ] Reference solution comparison and score recorded.

## References

- [Azure Well-Architected Framework](https://learn.microsoft.com/en-us/azure/well-architected/)
- [Competing Consumers pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/competing-consumers)
- [Retry pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/retry)
