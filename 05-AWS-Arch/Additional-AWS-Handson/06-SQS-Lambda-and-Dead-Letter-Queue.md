# Hands-On Lab 06 - Reliable Message Processing with SQS, Lambda and a DLQ

## Outcome

Send an order message to SQS, process it with Lambda and store one order record in DynamoDB. Send a duplicate without creating another record. Deliberately fail a different message, observe retries and dead-letter handling, repair the consumer and redrive the message.

**Time:** 60–90 minutes. **Costs:** Low-volume SQS/Lambda requests, DynamoDB on-demand writes/storage and CloudWatch Logs. No VPC or EC2 is needed. Do not send large batches or leave a failing producer running.

No previous lab is required.

```text
SQS source queue → Lambda → DynamoDB order record
       |
       +→ after repeated failures → DLQ → repair and redrive → source queue
```

## Prerequisites

- Sandbox permissions for SQS, Lambda, DynamoDB, CloudWatch Logs, IAM role/inline-policy creation and PassRole.
- Your console identity must be allowed to send messages and start/cancel DLQ message-move tasks. Redrive requires SQS permissions on both queues, including reading/deleting DLQ messages and sending to the destination.
- Use one Region for every resource, for example `ap-south-1`.
- Resource prefix `lab06`. Record the account ID, Region, both queue ARNs, table ARN and function role.

## Lab 1 - Create the table

1. Open **DynamoDB → Tables → Create table**.
2. Name `lab06-orders`.
3. Partition key `order_id`, type **String**. Do not add a sort key.
4. Choose **Customize settings** if needed to select **On-demand** capacity. Keep default encryption and no secondary indexes.
5. Create the table and wait for **Active**.
6. Open its overview and copy the table ARN.

The table is the business result for this exercise. A conditional write will make creation of each order atomic. We are not sending an external email or charging a payment card.

## Lab 2 - Create the dead-letter queue first

1. Open **SQS → Create queue**.
2. Type **Standard**, name `lab06-orders-dlq`.
3. Set message retention to **4 days**; keep encryption **SSE-SQS** (SQS-managed encryption), not a custom KMS key.
4. Keep the default access policy; do not grant public access.
5. Create the queue and copy its ARN.

## Lab 3 - Create the source queue

1. Create another **Standard** queue named `lab06-orders`.
2. Visibility timeout: **60 seconds**.
3. Message retention: **1 day**; delivery delay **0 seconds**; receive message wait time **0 seconds** is sufficient for the console exercise.
4. Encryption: **SSE-SQS**.
5. Enable **Dead-letter queue**, select `lab06-orders-dlq`, maximum receives **3**.
6. Create the queue and copy its ARN.
7. Return to the DLQ → **Edit → Redrive allow policy**. Select **By queue** and add the source queue ARN. Save.

Visibility timeout hides a received message temporarily; it does not delete the message. The SQS redrive policy sends repeatedly unsuccessful messages to the DLQ. This is different from Lambda's asynchronous invocation DLQ setting, which is not used here.

## Lab 4 - Create the Lambda role

1. In **IAM → Roles → Create**, choose trusted service **Lambda**.
2. Attach **AWSLambdaBasicExecutionRole**, name the role `lab06-consumer-role` and create it.
3. Add inline policy `lab06-queue-and-table`. Replace the two ARN placeholders:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
      "Resource": "YOUR-SOURCE-QUEUE-ARN"
    },
    {
      "Effect": "Allow",
      "Action": "dynamodb:PutItem",
      "Resource": "YOUR-TABLE-ARN"
    }
  ]
}
```

Lambda does not need permission to read the DLQ. SQS moves messages under the queue's redrive configuration; your console identity performs the later redrive operation.

## Lab 5 - Create the consumer

1. Open **Lambda → Create function → Author from scratch**.
2. Name `lab06-order-consumer`, runtime **Python 3.13** (or a newer supported Python runtime if unavailable), architecture x86_64.
3. Under execution role choose **Use an existing role → lab06-consumer-role**.
4. Create the function. Keep it outside a VPC.
5. In **Configuration → General configuration → Edit**, set memory **128 MB**, timeout **10 seconds**.
6. Under **Environment variables**, add `TABLE_NAME=lab06-orders` and `FAIL_DEMO=true`.
7. Replace the contents of `lambda_function.py` with:

```python
import json
import os

import boto3
from botocore.exceptions import ClientError

table = boto3.resource('dynamodb').Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    failures = []
    for record in event.get('Records', []):
        message_id = record['messageId']
        try:
            order = json.loads(record['body'])
            order_id = order['order_id']
            if not isinstance(order_id, str) or not order_id:
                raise ValueError('order_id must be a nonempty string')
            if order.get('simulate_failure') and os.environ.get('FAIL_DEMO') == 'true':
                raise RuntimeError('Controlled processing failure')
            try:
                table.put_item(
                    Item={'order_id': order_id, 'status': 'CONFIRMED'},
                    ConditionExpression='attribute_not_exists(order_id)',
                )
                print(json.dumps({'result': 'CREATED', 'order_id': order_id}))
            except ClientError as error:
                if error.response['Error']['Code'] == 'ConditionalCheckFailedException':
                    print(json.dumps({'result': 'DUPLICATE_SKIPPED', 'order_id': order_id}))
                else:
                    raise
        except Exception as error:
            print(json.dumps({
                'result': 'FAILED', 'message_id': message_id,
                'error_type': type(error).__name__,
            }))
            failures.append({'itemIdentifier': message_id})
    return {'batchItemFailures': failures}
```

8. Choose **Deploy**.

The conditional DynamoDB write both creates the lab's business result and guards against duplicates. A separate “processed” flag followed by an external side effect would have a crash gap; this example deliberately avoids that pattern. Reusing an order ID for different orders would be a producer error.

## Lab 6 - Attach the SQS trigger

1. On the function, **Add trigger → SQS**.
2. Select source queue `lab06-orders`, not the DLQ.
3. Batch size **1**, batch window **0**, enable the trigger.
4. Enable **Report batch item failures** / `ReportBatchItemFailures` for the event source mapping. If it is not available in the add-trigger dialog, create the trigger, then edit its mapping under **Configuration → Triggers**.
5. If the console does not expose the option, open **CloudShell** in the same Region and run:

```bash
export AWS_DEFAULT_REGION=ap-south-1
aws lambda list-event-source-mappings --function-name lab06-order-consumer \
  --query 'EventSourceMappings[].{UUID:UUID,Queue:EventSourceArn}' --output table
# Replace the placeholder with the UUID for the SOURCE queue mapping.
aws lambda update-event-source-mapping --uuid YOUR-MAPPING-UUID \
  --function-response-types ReportBatchItemFailures
```

6. Verify the mapping is Enabled and reports partial batch failures. Use CloudShell if necessary:

```bash
aws lambda get-event-source-mapping --uuid YOUR-MAPPING-UUID \
  --query '{State:State,FailureReporting:FunctionResponseTypes,BatchSize:BatchSize}'
```

**Do not continue without this check.** Without failure reporting, returning `batchItemFailures` could be treated as a successful invocation and the demonstration message could be deleted instead of retried.

The 60-second queue visibility timeout is six times the function's 10-second timeout. Do not configure function reserved concurrency to zero.

## Lab 7 - Send a successful order

1. Open **SQS → lab06-orders → Send and receive messages**.
2. Under **Send message**, enter:

```json
{"order_id":"order-001"}
```

3. Choose **Send message**. Do not poll/receive messages from the source queue in the console; Lambda is its consumer.
4. After a short delay, open **DynamoDB → Explore table items → lab06-orders** and run a scan/refresh.
5. Expected: one item with `order_id=order-001`, `status=CONFIRMED`.
6. Open **Lambda → Monitor → View CloudWatch logs**, open the latest stream and find `CREATED`.
7. In CloudWatch log-group settings, set retention for `/aws/lambda/lab06-order-consumer` to **1 day**.

## Lab 8 - Verify duplicate protection

1. Send the same JSON to the source queue again.
2. Inspect recent logs for `DUPLICATE_SKIPPED`.
3. Refresh the DynamoDB items. There should still be exactly one `order-001` item.

Standard queues and Lambda processing can deliver messages more than once. The stable business key, not SQS message ID, prevents a repeated order from creating a second record.

## Lab 9 - Observe retries and the DLQ

Send this message to the **source** queue:

```json
{"order_id":"order-002","simulate_failure":true}
```

1. Inspect Lambda logs. Expect `FAILED` with `RuntimeError` and a message ID.
2. Wait several minutes. Visibility timeout, polling and retry backoff mean movement is not immediate or an exact three-minute timer.
3. In SQS refresh the DLQ's available message count. Counts are approximate and can lag.
4. Check recent Lambda logs for repeated failures for the same message ID. Do not expect the function's **Errors** metric to rise: the handler successfully returns a partial-failure response.
5. Verify DynamoDB still has no `order-002` item.
6. Once the DLQ shows a message, optionally choose **Send and receive messages → Poll for messages** on the **DLQ only**, then open the message body. Do not delete it.
7. If you inspected it, wait for its visibility timeout to expire before redriving.

**Checkpoint:** Failed message retained in DLQ; successful order remains in the table. The failure is isolated without silently losing the order.

## Lab 10 - Repair and redrive

1. In Lambda environment variables change `FAIL_DEMO` to `false` and save. Wait until the function update completes.
2. Open **SQS → lab06-orders-dlq → Start DLQ redrive**.
3. Destination: **Redrive to source queue** (verify `lab06-orders`). Use a custom maximum velocity of **1 message per second**, if offered.
4. Start the redrive task and monitor its status.
5. Refresh DynamoDB. Expected: `order-001` and `order-002`, both CONFIRMED.
6. Inspect logs for `CREATED` for `order-002`. Check the source and DLQ drain after eventual count updates.
7. Resend the `order-002` JSON. With failure mode disabled, it should produce `DUPLICATE_SKIPPED` and still only one record for that ID.

Fix the consumer before redriving. Redriving while `FAIL_DEMO=true` merely repeats the failure cycle.

## Troubleshooting

| Symptom | Correction |
|---|---|
| No Lambda invocation | Check mapping Enabled, correct queue/Region, source role permissions and no reserved concurrency of zero. |
| Failing message disappears | Check `ReportBatchItemFailures` and the exact `batchItemFailures`/`itemIdentifier` field names. |
| DynamoDB denied | Verify table ARN and `dynamodb:PutItem` in the function role. |
| DLQ remains empty | Check source redrive policy, max receives, logs and elapsed visibility/backoff time. Do not poll source messages manually. |
| Redrive denied | Your console identity needs redrive permissions on both queues; the Lambda role is not the operator. |
| Redriven message fails again | Confirm environment update finished and value is lowercase `false`. |
| Duplicate produces no second row | Expected; inspect logs for the skipped result. |

## Cleanup

1. Disable/delete the Lambda SQS trigger and cancel any running DLQ redrive task.
2. Delete `lab06-order-consumer`.
3. Delete source queue `lab06-orders`, then `lab06-orders-dlq`. This removes remaining lab messages.
4. Delete DynamoDB table `lab06-orders`; no backups are required for this synthetic data. Remove any manually created backups if you made them.
5. Delete CloudWatch log group `/aws/lambda/lab06-order-consumer`.
6. Delete `lab06-consumer-role` and its inline policy.

## Completion checklist

- [ ] Source message creates one order item.
- [ ] Duplicate business key is skipped.
- [ ] Controlled failure retries and reaches DLQ.
- [ ] Repair and redrive create the missing order.
- [ ] Two unique order records, no duplicate records.
- [ ] All resources cleaned up.

## References

- [Configure an SQS event source](https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-configure.html)
- [Partial batch responses](https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-errorhandling.html)
- [SQS dead-letter queue redrive](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-configure-dead-letter-queue-redrive.html)
