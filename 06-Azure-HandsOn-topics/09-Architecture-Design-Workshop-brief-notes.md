# 09 - Architecture Design: Brief Notes

**Learning interface:** This is a design exercise. Use the portal for service configuration and pricing exploration, and record your architecture decisions in the supplied worksheets.

**Read before:** [Lab 09 - Architecture design workshop](09-Architecture-Design-Workshop.md)  
**Reading time:** 6–8 minutes. No resource creation is required for these notes or the workshop.

## What an architecture is

An architecture explains how a system meets its requirements, including how it behaves when something goes wrong. A diagram containing many Azure logos is not sufficient. You should be able to explain why each component exists, what data it owns and what happens when it fails.

The workshop's ticket-booking scenario forces several competing requirements: low latency, traffic bursts, correct seat ownership, payment uncertainty, recovery and cost.

## Terms you need for the decisions

| Term | Plain-language meaning |
|---|---|
| Functional requirement | Something the system must do, such as reserve a seat |
| Quality requirement | How well it must operate, such as response time or availability |
| Constraint | A limit the design must respect, such as data residency or budget |
| Assumption | A working input not yet confirmed; label it so it can be revisited |
| Tradeoff | A benefit gained with a cost or disadvantage elsewhere |
| Failure domain | A group of components that can fail together, such as one zone |
| Single point of failure | A component whose failure can stop the required service without an adequate alternative |
| ADR | Architecture Decision Record: a short explanation of a choice, alternatives and consequences |

**RPO** is the acceptable data-loss window; **RTO** is the acceptable restoration time. They are requirements to test, not values that become true because you write them on a diagram.

## Correct booking is a data problem

A **transaction** groups database work into a controlled unit. A **unique constraint** rejects duplicate values in a protected key. A **conditional write** changes data only if a required condition still holds. **Concurrency** means different requests can overlap in time.

For example, two clients can both read “seat available” before either writes “booked.” Checking only in application code leaves a race. The database must enforce the chosen ownership rule at the relevant transactional boundary.

**Idempotency** means repeating the same logical request does not create additional business effects. An idempotency key identifies the request; it is not simply a new random ID generated on every retry.

## A timeout does not tell you whether a payment happened

The provider may have charged the customer before its response was lost. Blindly sending another unrelated charge can charge twice. Your design needs a stable provider reference/idempotency mechanism and **reconciliation**: checking the authoritative outcome and bringing local records into agreement.

**Compensation** is an explicit business action to correct a partial result, such as refunding a payment when the booking cannot be completed. It is not the same as automatically undoing every remote system with one local database rollback.

## Messaging and state

A **stateless compute tier** keeps no irreplaceable business state only on one instance. It can use state stored elsewhere. A database is still stateful.

An **outbox** records a pending event in the same database transaction as a business change. A later dispatcher publishes it. This helps avoid “booking committed but notification event lost,” while consumers still need duplicate handling.

A **cache** is a reusable copy for speed; it can be stale. Do not make stale cached seat counts the final authority for ownership. A **DLQ** retains failed messages for investigation/recovery; it does not fix the consumer.

## Azure services by responsibility

| Responsibility | Candidate services in the workshop |
|---|---|
| Global delivery/protection | Front Door with an attached WAF policy |
| Regional HTTP routing | Application Gateway |
| Replaceable compute | VM Scale Sets or Functions, depending on workload |
| Transactional records | MySQL Flexible Server or another justified database |
| Asynchronous work | Service Bus and consumers |
| Object content | Storage blobs |
| Credentials/identity | Key Vault and managed identities |
| Operational evidence | Azure Monitor and Application Insights |

An **observability signal** is useful when it leads to a decision. “Monitor queue age and investigate delayed processing” is more actionable than adding a generic Monitor icon.

## AWS connection

The design principles are the same ones used in AWS: requirements first, explicit failure behavior, least privilege and measured recovery. Azure service names and networking details differ. Do not copy an AWS diagram and assume that replacing icons proves feature compatibility.

## Check your understanding

1. Does caching prevent two concurrent bookings of the same seat?
2. Does a payment timeout prove the customer was not charged?
3. What makes an ADR useful beyond naming a service?

**Answers:** (1) Not by itself; enforce consistency at the system of record. (2) No; reconcile the outcome. (3) It records the requirement, options, tradeoff and validation method.

**Ready for the workshop:** You can connect a requirement to a mechanism and a test, and clearly label assumptions.

Further reading: [Azure Well-Architected Framework](https://learn.microsoft.com/en-us/azure/well-architected/), [Retry pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/retry).
