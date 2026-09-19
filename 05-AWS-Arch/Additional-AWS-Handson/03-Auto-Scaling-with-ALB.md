# Hands-On Lab 03 - Auto Scaling, Load Balancing and Automatic Replacement

## Outcome

Build a web tier across two Availability Zones, automatically replace a failed server, and observe CPU-based scale-out and scale-in.

**Time:** 90–120 minutes, including metric and scaling delays.

**Costs:** Two to four `t3.micro` instances, root disks, public IPv4 addresses, an ALB and detailed EC2 monitoring. Set the maximum to four and delete the group at the end. CPU load is bounded to 15 minutes; T3 credit behavior affects sustained performance and cost.

No earlier lab or default VPC is required. This teaching design uses public instance subnets to avoid NAT gateways. Instance HTTP access is restricted to the ALB. Production application instances commonly use private subnets.

```text
Internet → ALB across AZ-A/AZ-B → Auto Scaling group
                                 minimum 2 / desired 2 / maximum 4
```

## Prerequisites

- Sandbox console access to VPC, EC2, ELB, Auto Scaling, CloudWatch, IAM and SSM.
- Permission to create/pass an EC2 role and create required service-linked roles.
- One Region with at least two AZs and quota for four small instances plus an ALB.
- Commands run in the **EC2 Session Manager terminal** unless specified otherwise.
- Record resource IDs and use prefix `lab03` throughout.

## Lab 1 - Create networking

1. Open **VPC → Create VPC → VPC only**. Name `lab03-vpc`, IPv4 `10.43.0.0/16`, no IPv6.
2. Select the VPC → **Actions → Edit VPC settings**. Enable DNS resolution and DNS hostnames.
3. Create two subnets:

| Name | AZ | CIDR |
|---|---|---|
| lab03-public-a | First AZ | 10.43.1.0/24 |
| lab03-public-b | Different AZ | 10.43.2.0/24 |

4. On each subnet, **Actions → Edit subnet settings → Enable auto-assign public IPv4**.
5. Create Internet Gateway `lab03-igw` and attach it to `lab03-vpc`.
6. Create route table `lab03-public-rt` in the VPC. Add `0.0.0.0/0 → lab03-igw`.
7. Explicitly associate both subnets with this route table.
8. Create the following security groups in `lab03-vpc`, retaining outbound allow-all:

| Group | Inbound |
|---|---|
| lab03-alb-sg | HTTP TCP 80 from 0.0.0.0/0 |
| lab03-web-sg | HTTP TCP 80 from security group lab03-alb-sg |

Add no SSH rule. When creating the ALB later, remove the default security group and select only `lab03-alb-sg`.

## Lab 2 - Create the instance role

1. Open **IAM → Roles → Create role**.
2. Choose **AWS service → EC2**.
3. Attach `AmazonSSMManagedInstanceCore`.
4. Name the role `lab03-ec2-role` and create it.

This role permits Session Manager registration. Your console identity separately needs permission to start a session.

## Lab 3 - Create a launch template

A launch template records how Auto Scaling creates replacement instances.

1. Open **EC2 → Launch Templates → Create launch template**.
2. Name it `lab03-template`.
3. Select the standard **Amazon Linux 2023, x86_64** AMI and `t3.micro` instance type.
4. Do not select a key pair or a subnet. The group will choose subnets.
5. Select `lab03-web-sg`.
6. Root volume: 8 GiB gp3 with delete-on-termination enabled.
7. Add instance tag `Name=lab03-web`.
8. In **Advanced details**, select instance profile `lab03-ec2-role`, enable detailed CloudWatch monitoring, and require IMDSv2.
9. Under **Credit specification**, choose **Unlimited** for this bounded load demonstration. This allows newly launched T3 instances to exceed their CPU-credit baseline, but surplus CPU credits can incur charges. The script stops after 15 minutes; do not extend or repeatedly restart it. Standard mode with few credits can prevent the CPU threshold from being reached.
10. Paste this user data:

```bash
#!/bin/bash
set -euxo pipefail
dnf install -y httpd
printf '<h1>Auto Scaling lab</h1><p>Server: %s</p>\n' "$(hostname)" > /var/www/html/index.html
printf 'healthy\n' > /var/www/html/health.html
systemctl enable --now httpd
```

11. Create the template. Record its version number.

User data runs when a new instance first boots. Editing an existing template version does not update running instances; new template versions and instance refresh are separate operations.

## Lab 4 - Create the target group and ALB

1. Open **EC2 → Target Groups → Create**.
2. Target type **Instances**, name `lab03-tg`, HTTP port 80, VPC `lab03-vpc`.
3. Health check protocol HTTP; path `/health.html`. Keep the remaining defaults.
4. Do not register instances manually. Create the group.
5. Open **Load Balancers → Create → Application Load Balancer**.
6. Name `lab03-alb`; **Internet-facing**; **IPv4**.
7. Select `lab03-vpc`, both AZs and their respective public subnets.
8. Select only `lab03-alb-sg`.
9. Listener HTTP:80 → forward to `lab03-tg`.
10. Create the ALB. Initial target status will be empty until the Auto Scaling group launches instances.

## Lab 5 - Create the Auto Scaling group

1. Open **EC2 → Auto Scaling Groups → Create**.
2. Name `lab03-asg`; select `lab03-template` and the recorded version.
3. Choose `lab03-vpc` and both public subnets.
4. Under load balancing, choose **Attach to an existing load balancer → Choose from target groups**, then `lab03-tg`.
5. Enable **Elastic Load Balancing health checks** in addition to EC2 health checks.
6. Health check grace period: **300 seconds**.
7. Desired capacity **2**, minimum **2**, maximum **4**. Use ordinary On-Demand instances; do not configure Spot or a mixed-instances policy.
8. Initially choose no scaling policy. Create the group.
9. Open its **Details** and set **Default instance warmup** to **180 seconds** if it was not offered during creation.
10. Under **Instance management**, wait for two instances to become **InService**.
11. In `lab03-tg`, wait for both targets to become **Healthy**.

Open `http://YOUR-ALB-DNS-NAME/` in a browser. The page should show a server hostname. Repeated requests may show either host; strict alternation is not guaranteed.

**Checkpoint:** Two InService instances, two healthy targets, and a working ALB page. Opening an instance IP directly on HTTP should fail because only the ALB security group is allowed.

## Lab 6 - Demonstrate automatic replacement

1. Record both instance IDs and the group's desired capacity.
2. In **EC2 → Instances**, select exactly one instance belonging to `lab03-asg`.
3. Choose **Instance state → Terminate instance**. This deliberately destroys one disposable lab server.
4. Repeatedly open the ALB page. The remaining healthy server should continue responding after failed-target detection; requests during the transition can fail.
5. Open **Auto Scaling Groups → lab03-asg → Activity**.
6. Find the activity that launches a replacement to restore desired capacity.
7. Wait for two InService instances and two healthy targets again.
8. Compare instance IDs: one is new, and desired capacity remains two.

**Explanation:** Replacement maintains desired capacity. It is not load-driven scale-out.

## Lab 7 - Configure CPU target tracking

1. Open the group → **Automatic scaling → Create dynamic scaling policy**.
2. Policy type: **Target tracking**.
3. Name `lab03-cpu-target`.
4. Metric: **Average CPU utilization**; target value **40**.
5. Use the group's 180-second default warmup. Keep scale-in enabled.
6. Save. Auto Scaling creates and manages CloudWatch alarms for this policy. Do not edit those alarms manually.

## Lab 8 - Generate bounded CPU load

This is a synthetic CPU test, not a web-throughput benchmark. Run it on **both current instances** so the initial group average crosses the target.

1. Select the first instance → **Connect → Session Manager → Connect**.
2. Paste:

```bash
cat > /tmp/lab03-load.py <<'PY'
import multiprocessing
import time

def burn():
    end = time.monotonic() + 900
    value = 1
    while time.monotonic() < end:
        value = (value * 17 + 3) % 10000019

if __name__ == '__main__':
    workers = [multiprocessing.Process(target=burn)
               for _ in range(multiprocessing.cpu_count())]
    for worker in workers:
        worker.start()
    for worker in workers:
        worker.join()
PY
nohup python3 /tmp/lab03-load.py >/tmp/lab03-load.log 2>&1 &
echo "Load controller PID: $!"
```

3. Open a session on the second instance and run the same block.
4. Open each instance's **Monitoring → CPU utilization**, then the group's **Activity** and **Instance management**.
5. Allow several one-minute metric periods plus launch/warmup time. Record the first scaling activity, desired capacity and new instance IDs.
6. Verify the new targets become healthy and their hostnames can appear through the ALB.

Do not run the load program on newly launched instances. The load automatically ends after 15 minutes; verify with `pgrep -af '[l]ab03-load.py'` on the original instances. No output means it has stopped.

If you need to stop it early, use the following on each original instance:

```bash
pkill -f '^python3 /tmp/lab03-load.py$' || true
pgrep -af '[l]ab03-load.py' || true
```

The worker processes inherit the same command line and are stopped by this lab-specific match.

## Lab 9 - Observe scale-in

1. After load ends, watch average CPU fall.
2. Keep the group minimum at two. Do not manually reduce desired capacity during this observation.
3. Allow additional metric periods and conservative scale-in evaluation. Scale-in can take longer than scale-out.
4. Record a scale-in activity and verify the group eventually returns to two healthy instances.
5. If it does not scale in during your allotted time, record the current alarm state and group activity rather than claiming success. Proceed to cleanup to avoid ongoing charges.

| Event | Evidence to record |
|---|---|
| Replacement | Old/new IDs; desired capacity stayed 2 |
| Scale-out | Policy activity; desired capacity rose above 2 |
| Scale-in | Policy activity; desired capacity returned toward 2 |

## Troubleshooting

| Symptom | Check |
|---|---|
| Targets unhealthy | SSM: run `sudo systemctl status httpd`, `curl -i localhost/health.html`, and `sudo tail -n 60 /var/log/cloud-init-output.log`. Check SG source and subnet IGW routing. |
| Replacements repeatedly fail | Fix template networking/user data; publish a corrected template version, update the ASG version, then replace failed lab instances. |
| No scale-out | Check load on both instances, actual CPU, policy metric, max=4, warmup, suspended processes and Activity errors. |
| CPU stays low | Check the load process and T3 CPU-credit metrics. Confirm the instances use the template's Unlimited credit setting; Standard mode can throttle instances with depleted credits. Do not run unbounded load. |
| Launch fails | Read Activity for instance quota, capacity or role errors. |
| No scale-in | Confirm load stopped, minimum=2, scale-in enabled, no instance scale-in protection, and allow alarm evaluation time. |

## Cleanup

1. Stop any remaining load programs.
2. Delete `lab03-asg` and wait for its instances to terminate. Verify there are no orphaned instances or EBS volumes.
3. Delete `lab03-alb`, then `lab03-tg` after its listener dependency disappears.
4. Delete `lab03-template` and `lab03-ec2-role`/unused instance profile.
5. Verify policy-managed CloudWatch alarms were removed with the policy/group. Delete only any lab-created remnants.
6. Delete web SG, then ALB SG, once network interfaces disappear.
7. Delete both subnets and the custom route table. Detach/delete IGW, then delete VPC.

## Completion checklist

- [ ] Two-AZ web tier validated through the ALB.
- [ ] Failed instance automatically replaced.
- [ ] CPU policy caused scale-out, or a specific limitation was recorded.
- [ ] Load stopped; scale-in observed or its pending state recorded.
- [ ] All chargeable resources deleted.

## References

- [Target tracking scaling policies](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-target-tracking.html)
- [Auto Scaling health checks](https://docs.aws.amazon.com/autoscaling/ec2/userguide/health-checks-overview.html)
