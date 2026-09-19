# Hands-On Lab 01 - Prepare an AWS Lab Account and Control Costs

## Outcome

Identify the account and identity you are using, select a Region, verify CloudShell access, create a monthly budget, and practise tracking and deleting a small resource. No earlier lab is required.

**Time:** 30–45 minutes, excluding billing-data delays.

**Cost:** The core exercise uses CloudShell and an empty S3 bucket. Uploaded objects and requests can incur charges. Later labs use paid resources. A budget sends notifications; it does not impose a spending cap or automatically stop resources.

## Before you start

- Use a dedicated AWS learning account or a sandbox in which you are allowed to create resources. Do not use production resources.
- Sign in with a federated role or IAM identity. Do not use the root user for the exercises.
- You need access to CloudShell, STS GetCallerIdentity, S3 bucket creation/listing/tagging/deletion, and Billing/Budgets creation and viewing. Account policies can restrict these independently.
- You need an email address that you can read for budget notifications.
- If this is a managed sandbox and access is denied, its account administrator must grant the required access. Changing Region or creating access keys does not bypass a permission restriction.

## Lab 1 - Record account and Region

1. Sign in to the AWS Management Console.
2. Open the account menu at the top right. Record the **12-digit account ID** and identity/role name.
3. Select **Asia Pacific (Mumbai), ap-south-1** in the Region selector. If your account restricts Regions, choose an allowed Region and use it consistently.
4. Create a local text file named `aws-lab-record.txt`. Copy this worksheet into it:

```text
Account ID:
Sign-in identity/role:
Region:
Lab start time:
Planned cleanup time:
Budget name:
Resource name | Resource ID | Region | Purpose | Deleted?
```

Do not record passwords, access keys or secret values in this file. IAM and billing are account-wide; EC2, RDS and Lambda resources are regional.

## Lab 2 - Verify the command environment

These guides use **Bash in AWS CloudShell** or **Bash in an EC2 Session Manager session** where stated. Bash commands should not be pasted directly into Windows PowerShell.

1. Choose the **CloudShell** icon in the console toolbar.
2. Wait for the terminal prompt. This is a terminal in AWS, authenticated with your current console identity.
3. Run:

```bash
aws --version
aws sts get-caller-identity
aws configure get region
```

Expected: AWS CLI v2 and JSON containing your account ID and identity ARN. An empty output from the third command is not a failed login; set the Region explicitly below.

```bash
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION="$AWS_REGION"
aws ec2 describe-availability-zones --region "$AWS_REGION" \
  --query 'AvailabilityZones[?State==`available`].ZoneName' --output table
```

Replace `ap-south-1` if necessary. The final command requires EC2 read permission and should list available AZs. An **Availability Zone** is an isolated location inside a Region.

**Checkpoint:** The account ID matches your worksheet, and the terminal Region matches the console Region. Do not run `aws configure` to create or paste long-lived access keys; CloudShell already supplies credentials.

## Lab 3 - Create a monthly cost budget

1. Search for **Billing and Cost Management** in the console.
2. Open **Budgets → Create budget**.
3. Choose **Customize / advanced**, then **Cost budget**.
4. Set the following values:

| Setting | Lab value |
|---|---|
| Name | `aws-learning-monthly` |
| Period | Monthly |
| Recurrence | Recurring |
| Budgeting method | Fixed |
| Amount | USD 10, or a lower amount appropriate to your account |
| Scope | All AWS services in this account; no tag filter |

USD 10 is an example notification threshold, not a predicted cost for completing the other guides.

5. Add an alert for **Actual cost**, **80% of budgeted amount**. Enter your email address.
6. Add another alert for **Actual cost**, **100%**.
7. Review the settings and create the budget. Do not configure automatic budget actions for this exercise.
8. Reopen the budget. Verify its amount, scope, thresholds and notification recipients.

**Expected:** A saved budget with both alerts. You do not need to spend money to trigger a test. Billing data and notifications are delayed; do not treat the displayed spend as a live meter.

If billing access is denied, verify that your identity has billing permissions and that the account permits IAM access to billing where applicable. Record the blockage; do not claim the budget exists until you can see it.

## Lab 4 - Practise naming and ownership tags

1. Open **S3 → Create bucket**.
2. Choose a **General purpose** bucket in your selected Region.
3. Use a globally unique name such as `aws-learning-123456789012-20260919-ab`. Replace the account ID, date and suffix with your own values.
4. Keep **Block all public access** enabled, **ACLs disabled**, versioning disabled and default SSE-S3 encryption. Do not enable Object Lock.
5. Create the bucket and record its exact name in your worksheet.
6. Open **Properties → Tags → Edit** and add:

| Key | Value |
|---|---|
| Project | AWSHandsOn |
| Lab | 01 |
| Environment | Training |
| Owner | Your learner identifier |

7. Create a local file `hello.txt` containing `AWS learning lab 01`.
8. Open the bucket, choose **Upload → Add files**, select `hello.txt`, and choose **Upload**.
9. Select the object and choose **Download**. Open the downloaded file and verify its contents.

**Expected:** Upload and authenticated download succeed. The bucket remains private. Tags describe ownership; they do not automatically expire or delete a resource.

## Lab 5 - Inspect cost visibility

1. Open **Billing → Cost Explorer** and enable it if necessary.
2. Select the current month and group by **Service**.
3. Record the date range and the largest service cost, or record **No cost data available yet**.
4. Change grouping to **Region** and inspect the results.
5. If you want tag-based reporting, open **Cost allocation tags**, find `Project`, select it and activate it. Newly created tags may take time to appear; activation and cost-report availability are not immediate.

Do not wait for a billing charge to appear before cleaning up. A new account may have no meaningful optimization or forecast data yet.

## Cleanup - Lab 6: complete a cleanup rehearsal

1. Open the lab S3 bucket. Select `hello.txt` and choose **Delete**. Confirm the deletion.
2. Return to **Buckets**, select only your lab bucket, choose **Delete**, type its name and confirm.
3. Refresh the list and verify that the bucket is absent.
4. Mark the bucket deleted in the worksheet.
5. Keep the budget for later exercises. If you created it only for this rehearsal, open **Budgets**, select `aws-learning-monthly`, and delete it.

For later labs, verify resources in every Region used. Stopping an EC2 instance does not delete its EBS storage; stopping RDS is not permanent cleanup. NAT gateways, load balancers, interface endpoints, snapshots and retained backups may continue costing money after compute is stopped.

## Troubleshooting

| Symptom | Check and correction |
|---|---|
| CloudShell will not open | Confirm CloudShell permissions and regional availability. Use an allowed Region. |
| Account ID differs | Stop and sign in to the intended learning account. |
| Bucket name already exists | Choose a different unique suffix; bucket names are globally unique. |
| AccessDenied | Confirm the denied service/action and identity with the account administrator. Do not attach AdministratorAccess as a generic workaround. |
| No costs or tags appear | Allow for reporting delays; verify filters and dates. |
| Budget exists but no email | Verify recipient and threshold; a saved budget alone does not trigger a threshold notification. |

## Completion checklist

- [ ] Identity, account and Region recorded.
- [ ] CloudShell identity checked.
- [ ] Budget saved with verified recipients and thresholds.
- [ ] Private bucket created, tagged, tested and deleted.
- [ ] Resource worksheet updated.
- [ ] You can explain why a budget is not a hard spending limit.

## References

- [AWS Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html)
- [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)
- [Cost allocation tags](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html)
