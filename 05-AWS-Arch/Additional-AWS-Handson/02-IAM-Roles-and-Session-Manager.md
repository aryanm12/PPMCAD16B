# Hands-On Lab 02 - EC2 IAM Roles and Session Manager

## Outcome

Create an EC2 instance with no inbound access, open a browser terminal through Session Manager, and give the instance permission to read only one S3 prefix. Verify both allowed and denied operations without creating access keys.

**Time:** 60–90 minutes. **Costs:** One small EC2 instance, its EBS disk, public IPv4 usage and small S3 requests/storage. Clean up in the same sitting. No previous guide or default VPC is required.

```text
Browser → Systems Manager → EC2 (no inbound ports)
                              |
                              +→ IAM role → read S3 allowed/ only
```

## Prerequisites and conventions

- A sandbox identity allowed to manage VPC, EC2, S3 and IAM roles/inline policies, pass the EC2 role, and start/terminate SSM sessions.
- Use one Region, for example `ap-south-1`. All shell blocks below run in the **EC2 Session Manager terminal**, not CloudShell, unless explicitly stated.
- Keep a worksheet containing the VPC ID, subnet ID, instance ID, role name and bucket name. Use only resources created here.
- IAM controls API authorization; security groups control network traffic. Both must permit an operation.

## Lab 1 - Build a small network

1. Open **VPC → Create VPC → VPC only**. Name: `lab02-vpc`; IPv4 CIDR: `10.42.0.0/16`; no IPv6.
2. Select the VPC → **Actions → Edit VPC settings**. Enable DNS resolution and DNS hostnames.
3. Open **Subnets → Create subnet**. Select `lab02-vpc`; name `lab02-public-a`; select one AZ; CIDR `10.42.1.0/24`.
4. Select the subnet → **Actions → Edit subnet settings** → enable auto-assign public IPv4.
5. Open **Internet gateways → Create**; name `lab02-igw`. Attach it to `lab02-vpc`.
6. Open **Route tables → Create**; name `lab02-public-rt`; select the VPC.
7. Open its **Routes → Edit routes**. Add `0.0.0.0/0` with target `lab02-igw`.
8. Under **Subnet associations → Edit**, select `lab02-public-a` and save.
9. Open **Security groups → Create**. Name `lab02-instance-sg`; description `Session Manager only`; select `lab02-vpc`. Add **no inbound rules**. Keep the default outbound allow-all rule.

The public IP and Internet Gateway provide outbound access to SSM and S3. They do not open inbound ports. A fully private endpoint-based design is covered in lab 04.

## Lab 2 - Create sample objects

1. In **S3**, create a General purpose bucket named `lab02-YOUR-ACCOUNT-ID-UNIQUE-SUFFIX` in your Region. Use lowercase letters/numbers/hyphens.
2. Keep all public access blocked, ACLs disabled, versioning disabled, default SSE-S3 encryption and Object Lock disabled.
3. Create a local file `message.txt` containing `Read permission works`.
4. Inside the bucket, choose **Create folder**, name it `allowed`, and create it. Open the folder and upload `message.txt`.
5. Return to the bucket root, create a folder `private`, open it and upload the same file.

You now have two object keys: `allowed/message.txt` and `private/message.txt`. A key is the full object name, including its prefix.

## Lab 3 - Create an EC2 role

1. Open **IAM → Roles → Create role**.
2. Trusted entity: **AWS service**; service/use case: **EC2**.
3. Attach **AmazonSSMManagedInstanceCore**.
4. Name the role `lab02-ec2-role` and create it.
5. Open the role → **Permissions → Add permissions → Create inline policy → JSON**.
6. Paste the policy below, replacing **both** instances of `YOUR-BUCKET-NAME` with your exact bucket name:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListAllowedPrefix",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME",
      "Condition": {"StringLike": {"s3:prefix": ["allowed/", "allowed/*"]}}
    },
    {
      "Sid": "ReadAllowedObjects",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/allowed/*"
    }
  ]
}
```

7. Name it `lab02-read-prefix` and save.

The bucket ARN authorizes listing; the object ARN authorizes reading object contents. There is no grant for uploads or the private prefix.

## Lab 4 - Launch and connect

1. Open **EC2 → Launch instances**.
2. Name: `lab02-client`; AMI: **Amazon Linux 2023**, **64-bit x86**, standard Amazon-provided image.
3. Type: `t3.micro`; key pair: **Proceed without a key pair**.
4. Edit networking: VPC `lab02-vpc`, subnet `lab02-public-a`, public IP **Enable**, existing security group `lab02-instance-sg` only.
5. Storage: 8 GiB gp3 root disk; keep delete-on-termination enabled.
6. Under **Advanced details**, select IAM instance profile `lab02-ec2-role`. Require IMDSv2 if the metadata setting is shown. No user data is needed.
7. Launch and wait for Running and all instance status checks to pass.
8. Select the instance → **Connect → Session Manager → Connect**. Allow several minutes for SSM registration.
9. In the browser terminal run:

```bash
whoami
aws --version
aws sts get-caller-identity
```

Expected: a shell user such as `ssm-user`, AWS CLI v2, and an ARN containing `assumed-role/lab02-ec2-role/`. This is the instance's role, not your browser identity.

If `aws` is absent on your selected image, run `sudo dnf install -y awscli2` and repeat. Do not configure access keys.

## Lab 5 - Prove least-privilege access

Set the actual values in the EC2 terminal:

```bash
export AWS_DEFAULT_REGION=ap-south-1
BUCKET='YOUR-BUCKET-NAME'
aws s3 ls "s3://$BUCKET/allowed/"
aws s3 cp "s3://$BUCKET/allowed/message.txt" /tmp/lab02-message.txt
cat /tmp/lab02-message.txt
```

Expected: the file is listed and its content is `Read permission works`.

Run the negative tests:

```bash
aws s3api get-object --bucket "$BUCKET" --key private/message.txt /tmp/lab02-denied.txt
aws s3 cp /tmp/lab02-message.txt "s3://$BUCKET/allowed/new.txt"
aws s3 ls "s3://$BUCKET/"
```

Expected: **AccessDenied** for all three. You allowed reading one prefix, not reading the private object, writing objects or listing the bucket root. Do not broaden the policy to make these tests pass.

## Lab 6 - Remove and restore application permission

1. Leave the SSM session open.
2. In IAM, open `lab02-ec2-role` and delete only the inline policy `lab02-read-prefix`. Keep `AmazonSSMManagedInstanceCore` attached.
3. After a short propagation delay, rerun the allowed `aws s3 cp` command. It should fail with AccessDenied.
4. Recreate the same inline policy from Lab 3.
5. Retry until the download succeeds. Policy changes are not instantaneous; allow a few minutes before diagnosing a mismatch.

**What this proves:** Network access and an active terminal do not imply S3 permission. The EC2 role supplies temporary credentials and authorization independently of your console identity.

## Troubleshooting

| Symptom | Correction |
|---|---|
| Session Manager unavailable | Verify the instance profile, public IP, route-table association, IGW attachment and outbound HTTPS. Wait for SSM registration. |
| Still not registered | Open EC2 **Actions → Monitor and troubleshoot → Get system log**. Confirm the Amazon Linux 2023 image and healthy boot. Recheck the role's EC2 trust relationship. |
| Browser user cannot connect | Your console identity needs SSM session permissions; the instance role alone does not grant these. |
| Allowed object denied | Check exact bucket name, prefix case, policy resource ARNs, and that you ran the command on EC2. |
| Denied operation succeeds | Check for extra IAM policies or bucket grants. Use only the new lab role and private bucket. |
| Timeout instead of AccessDenied | Investigate routing/DNS/outbound rules before editing IAM. |

## Cleanup

1. End the Session Manager session.
2. Terminate `lab02-client`. Wait for termination and verify its root volume was deleted.
3. In S3, empty only the lab bucket and then delete it.
4. In IAM, delete `lab02-ec2-role` and its inline policy. If an instance profile remains, remove the role from it and delete the profile using IAM/CLI; verify it is not attached to another instance.
5. Delete `lab02-instance-sg` after instance network interfaces disappear.
6. Delete the subnet, then the custom route table. Detach/delete the IGW and delete `lab02-vpc`.
7. Confirm the instance, volume, bucket and VPC are gone. AWS-managed IAM policies are shared definitions; do not try to delete them.

## Completion checklist

- [ ] Connected without a key pair or inbound SSH rule.
- [ ] Instance identity shows `lab02-ec2-role`.
- [ ] Allowed download succeeds; three negative tests fail.
- [ ] Removing and restoring the inline policy changes S3 access.
- [ ] All lab resources removed.

## References

- [Session Manager instance permissions](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-instance-profile.html)
- [IAM roles for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)
