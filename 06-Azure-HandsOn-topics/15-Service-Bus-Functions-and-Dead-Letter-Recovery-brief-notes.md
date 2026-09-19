# 15 - Service Bus, Functions and Failed Messages: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values. Python code publishing uses the documented Visual Studio Code graphical extension; it does not require Azure CLI commands.

**Read before:** [Lab 15 - Service Bus and DLQ recovery](15-Service-Bus-Functions-and-Dead-Letter-Recovery.md)  
**Reading time:** 6–8 minutes. Review [Functions notes](04-Functions-API-Management-and-Deployment-brief-notes.md) and [identity notes](11-Managed-Identity-RBAC-and-VM-Operations-brief-notes.md) if needed.

## Why put work in a queue?

A producer can submit work without waiting for a consumer to finish it immediately. The queue holds messages while the consumer processes them. This helps absorb bursts and separates components' operating speeds, but introduces retries, delayed completion and duplicate-delivery concerns.

```text
Producer → Service Bus queue → Function → one business record in Azure Table
                    |
                    +→ repeated failure → dead-letter subqueue → repair/replay
```

## Vocabulary before provisioning

| Term | Meaning |
|---|---|
| Namespace | The Service Bus resource/endpoint containing queues and other messaging entities |
| Queue | A broker-managed holding area for work messages |
| Producer / consumer | The sender / the processor of a message |
| Message body | The application payload, here JSON describing an order |
| Broker message ID | An identifier attached to a particular sent message |
| Business ID | The stable identity of the logical work, here `order_id` |
| Trigger binding | Functions integration that receives queue messages and invokes your code |
| Delivery count | How many processing deliveries/attempts have occurred under broker rules |
| DLQ | Dead-letter queue/subqueue retaining messages that need investigation or special handling |

In Service Bus, a queue has a built-in dead-letter **subqueue**. You do not create a separate SQS-style DLQ and wire its ARN into the source. See [Service Bus dead-letter queues](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-dead-letter-queues).

## The processing lifecycle

With **Peek-Lock** receiving, a message is temporarily locked for processing rather than immediately removed. **Complete** acknowledges success and removes it. **Abandon** releases it for another attempt; expiry of the lock can also make it available again. Repeated failures can exceed the configured delivery threshold and send it to the DLQ.

The Functions trigger handles broker interaction around your invocation. If the handler catches every error and returns success, a failed business operation can appear completed. In this lab the controlled error is raised so retry behavior can occur.

**Peek** observes a message without consuming it. **Replay** sends the failed work back for processing after the cause is repaired. A DLQ is not an automatic error-fixing service.

## Why duplicates are expected design work

Suppose the function writes the business result but fails before acknowledging the message. A later delivery can run the work again. A new send can also carry the same logical order under another broker message ID.

The lab's **idempotency** uses the business ID, not the delivery's message ID. **Azure Table Storage** stores entities identified by a **PartitionKey + RowKey** pair. The function uses a fixed partition and the order ID as the row key; an atomic create rejects an already-existing entity.

“Atomic” means the entity-creation decision is not split into an unsafe check-then-insert race. The table entity is the lab's business result itself. This does not magically make a separate external payment or email exactly-once.

## Identity and replay order

The Function identity needs queue-receive and table-write roles. Your operator identity needs send/receive permissions for the portal Service Bus Explorer. They are different principals.

Replay sends the new source message before completing the DLQ copy. If sending fails, the original remains recoverable. A crash after sending but before completion can produce a duplicate replay, which the business-key check handles in this exercise.

**Max delivery count**, function retry/backoff and message lock timing mean DLQ arrival is not an exact wall-clock timer. Use observed message/log evidence rather than assuming it must happen at a precise minute.

## AWS comparison

The responsibility resembles SQS → Lambda → durable result storage. Service Bus namespaces, Peek-Lock settlement, built-in DLQ subqueues and Functions bindings have different configuration/behavior. Azure Table Storage is a different data service from DynamoDB; only the conditional business-record idea is being compared here.

## Check your understanding

1. Is a message leaving the source queue proof its order was processed correctly?
2. Why use `order_id` instead of a newly generated message ID for duplicate protection?
3. Should you replay before disabling the controlled failure?

**Answers:** (1) No; check the result and DLQ. (2) It identifies the same logical order across sends. (3) No; repair first or repeat the failure cycle.

**Ready for the lab:** You can explain complete, retry, dead-letter and replay, and why duplicate handling remains necessary.

Further reading: [Service Bus settlement](https://learn.microsoft.com/en-us/azure/service-bus-messaging/message-transfers-locks-settlement), [Tables overview](https://learn.microsoft.com/en-us/azure/storage/tables/table-storage-overview).
