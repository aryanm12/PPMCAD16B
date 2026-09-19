# Hands-On Lab 04 - Private EC2, VPC Endpoints and Network Troubleshooting

## Outcome

Connect to an EC2 instance with no public IP, NAT gateway or Internet Gateway. Read a private S3 object through a gateway endpoint, deliberately remove its route, and recover access. Diagnose a separate security-group failure.

**Time:** 75–105 minutes. **Costs:** One EC2 instance/EBS disk and two interface endpoints in one AZ, plus small S3/API usage. Interface endpoints have ongoing hourly/data charges. The S3 gateway endpoint itself has no hourly endpoint charge. Delete endpoints at the end.

No previous lab is required. This intentionally isolated instance cannot download arbitrary internet packages.

```text
Console → SSM service → ssm / ssmmessages interface endpoints → private EC2
Private EC2 → S3 prefix-list route → S3 gateway endpoint → private bucket
```

## Prerequisites

- Sandbox permissions for VPC/endpoints, EC2, IAM roles/inline policies/PassRole, SSM sessions and S3.
- Choose a Region supporting SSM interface endpoints, for example `ap-south-1`.
- Use a current standard Amazon Linux 2023 AMI with the preinstalled SSM Agent and AWS CLI. Modern SSM Agent uses `ssmmessages`; this guide does not support older custom images requiring legacy messaging endpoints.
- Record all resource IDs. Commands run on the **private EC2 Session Manager terminal**.

## Lab 1 - Create an isolated subnet

1. **VPC → Create VPC → VPC only**: name `lab04-vpc`, CIDR `10.44.0.0/16`, no IPv6.
2. Select VPC → **Actions → Edit VPC settings**: enable DNS resolution and DNS hostnames. Both are needed for interface endpoint private DNS.
3. Create subnet `lab04-private-a`, CIDR `10.44.1.0/24`, in one AZ. Keep public-IP auto-assignment disabled.
4. Create route table `lab04-private-rt` in this VPC and explicitly associate the subnet.
5. Verify its only route is `10.44.0.0/16 → local`.
6. Do not create an Internet Gateway or NAT gateway. Keep the default network ACL rules.
7. Create security group `lab04-client-sg` in this VPC: no inbound rules, default outbound allow-all.
8. Create security group `lab04-endpoint-sg`: inbound **HTTPS TCP 443**, source **lab04-client-sg**; default outbound allow-all.

The endpoint SG accepts connections from the EC2 client's SG. The instance does not need inbound port 443.

## Lab 2 - Create the SSM interface endpoints

For each of these two service names, perform the steps below. Substitute your Region if different:

```text
com.amazonaws.ap-south-1.ssm
com.amazonaws.ap-south-1.ssmmessages
```

1. Open **VPC → Endpoints → Create endpoint**.
2. Name the first `lab04-ssm`, second `lab04-ssmmessages`.
3. Select **AWS services**, search the exact service name, and select type **Interface**.
4. VPC: `lab04-vpc`. Enable **Private DNS**.
5. Select the AZ and subnet `lab04-private-a` only. Use IPv4.
6. Select only `lab04-endpoint-sg`, removing the default group.
7. Keep the default full-access endpoint policy for this lab. Endpoint policy is an additional control; IAM still applies.
8. Create each endpoint and wait until **Available**.

**Checkpoint:** Two Available interface endpoints with private DNS enabled and network interfaces in the private subnet.

## Lab 3 - Create S3 data and the EC2 role

1. Create a private S3 General purpose bucket `lab04-YOUR-ACCOUNT-ID-UNIQUE-SUFFIX` in the **same Region** as the VPC.
2. Keep all public access blocked, ACLs disabled, SSE-S3 encryption, versioning disabled and Object Lock disabled.
3. Create a local `proof.txt` containing `Private S3 endpoint works` and upload it to the bucket root.
4. In **IAM → Roles → Create**, select trusted service **EC2**, attach `AmazonSSMManagedInstanceCore`, name `lab04-ec2-role`.
5. Add an inline JSON policy named `lab04-s3-read`, replacing both bucket placeholders:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": "s3:ListBucket", "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME"},
    {"Effect": "Allow", "Action": "s3:GetObject", "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"}
  ]
}
```

## Lab 4 - Create the S3 gateway endpoint

1. Open **VPC → Endpoints → Create endpoint**; name `lab04-s3`.
2. Select AWS service `com.amazonaws.ap-south-1.s3`, type **Gateway**. Do not select the S3 Interface service.
3. VPC: `lab04-vpc`; route table: **lab04-private-rt**.
4. Keep the default endpoint policy and create it.
5. Open `lab04-private-rt → Routes`. Confirm an additional route with destination `pl-...` and target `vpce-...`.

The prefix list represents the regional S3 IP ranges. This route is managed by the gateway endpoint association. It does not create general internet access.

## Lab 5 - Launch the private client

1. **EC2 → Launch instances**: name `lab04-client`; standard Amazon Linux 2023 x86_64; type `t3.micro`; no key pair.
2. Network: `lab04-vpc`, `lab04-private-a`, public IP **Disable**, only `lab04-client-sg`.
3. Storage: 8 GiB gp3, delete-on-termination enabled.
4. Advanced details: instance profile `lab04-ec2-role`, IMDSv2 required. Leave user data blank.
5. Launch and wait for status checks.
6. Verify **Public IPv4 address: none**.
7. **Connect → Session Manager → Connect**. Allow several minutes for registration.
8. Run:

```bash
aws --version
export AWS_DEFAULT_REGION=ap-south-1
BUCKET='YOUR-BUCKET-NAME'
aws s3 cp "s3://$BUCKET/proof.txt" /tmp/lab04-proof.txt \
  --cli-connect-timeout 5 --cli-read-timeout 5
cat /tmp/lab04-proof.txt
curl -I --connect-timeout 5 --max-time 10 https://example.com
```

Expected: the S3 download succeeds and contains the expected text; the internet request times out/fails. Public DNS may resolve an address without providing a route to it.

Do not use `aws sts get-caller-identity` as the connectivity test here: this design deliberately has no STS interface endpoint or internet route. The instance still obtains role credentials from EC2 instance metadata.

## Lab 6 - Break and repair the S3 route

1. Keep the SSM terminal open.
2. In **VPC → Endpoints → lab04-s3 → Route tables → Manage route tables**, deselect `lab04-private-rt` and save. If the console prevents an endpoint with no route tables, create an unused route table in `lab04-vpc`, associate the endpoint with that table, and remove the private table association.
3. Check that the S3 prefix-list route disappeared from `lab04-private-rt`.
4. On EC2, run:

```bash
AWS_MAX_ATTEMPTS=1 aws s3api get-object \
  --bucket "$BUCKET" --key proof.txt /tmp/lab04-proof-retry.txt \
  --cli-connect-timeout 5 --cli-read-timeout 5
```

Expected: a connection timeout. There is neither an S3 endpoint route nor an internet route. Your SSM terminal remains available because it uses different endpoints.

5. Reassociate `lab04-private-rt` with `lab04-s3`.
6. Verify the prefix-list route returns and rerun the command. It should succeed.

## Lab 7 - Break and repair endpoint security

1. In **Security groups → lab04-endpoint-sg → Inbound rules**, remove only the HTTPS rule you created.
2. Close the current SSM session and try opening a **new** session. It should fail to establish, though existing tracked connections can persist briefly.
3. Restore inbound HTTPS 443 from `lab04-client-sg` using the console.
4. Allow the agent to reconnect and open a new SSM session. If registration has not recovered after several minutes, reboot only `lab04-client` from EC2, then wait for status checks and retry.

**Why this is recoverable:** Console edits use your browser identity and do not depend on the private instance's network path.

## Troubleshooting decision table

| Symptom | Investigate first |
|---|---|
| Instance never appears in SSM | Instance profile, current AL2023 image, both SSM endpoint states, endpoint SG source, private DNS and VPC DNS settings |
| S3 timeout | Correct Region, gateway endpoint association with the actual subnet route table, outbound rules and network ACLs |
| S3 AccessDenied | Exact bucket/object ARN, instance-role policy, endpoint policy and bucket policy |
| S3 NoSuchKey | Object name and case; check `proof.txt` exists |
| Internet request fails | Expected; no default route exists |
| STS/package downloads fail | Expected; their endpoints/repositories were not provisioned in this isolated network |

An endpoint policy does not grant permissions missing from IAM. Conversely, broad IAM permission cannot repair a missing network route.

## Cleanup

1. End sessions and terminate `lab04-client`; verify its root disk is removed.
2. Delete `lab04-ssm`, `lab04-ssmmessages` and `lab04-s3`. Wait for interface endpoint network interfaces to disappear.
3. Empty and delete the S3 bucket.
4. Delete the EC2 role/inline policy and unused instance profile.
5. Delete endpoint SG first (it references the client SG), then client SG.
6. Delete the private subnet, custom route tables including any temporary table, then `lab04-vpc`.
7. Verify no interface endpoints remain for this lab; these are easy to overlook in billing.

## Completion checklist

- [ ] EC2 has no public IP and the subnet has no default route.
- [ ] SSM connection succeeds through interface endpoints.
- [ ] S3 succeeds through the gateway endpoint while internet access fails.
- [ ] Missing-route failure reproduced and repaired.
- [ ] Endpoint-SG failure reproduced and repaired.
- [ ] All resources deleted.

## References

- [Systems Manager VPC endpoints](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html)
- [S3 gateway endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html)
