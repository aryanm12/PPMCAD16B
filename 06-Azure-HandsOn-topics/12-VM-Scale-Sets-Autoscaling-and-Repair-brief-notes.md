# 12 - VM Scale Sets, Autoscaling and Repair: Brief Notes

**Learning interface:** Use the Azure portal for this topic’s resource settings, monitoring and cleanup. The companion hands-on gives the exact pages and values. Supplied guest scripts run through the VM’s portal Run command page to install or test software inside the VM.

**Read before:** [Lab 12 - VM Scale Sets](12-VM-Scale-Sets-Autoscaling-and-Repair.md)  
**Reading time:** 5–7 minutes. Review [web architecture notes](02-Application-Gateway-and-Web-Architecture-brief-notes.md) for VMs, networks and health checks.

## Three mechanisms work together

**Load balancing** selects a usable backend for a connection. **Autoscaling** changes capacity as demand changes. **Automatic repair** recovers an unhealthy instance. You need separate evidence for all three.

```text
Users → Load Balancer → VM Scale Set instances
                         ↑ capacity rules / health-based repairs
```

## Scale-set vocabulary

| Term | Meaning |
|---|---|
| VM Scale Set (VMSS) | A managed group of VM instances deployed from a shared configuration |
| Model | The configuration used to create/update instances: image, size, extensions and more |
| Instance | One VM belonging to that scale set |
| Orchestration mode | How the scale set manages its VMs; this lab uses Flexible so each instance can be managed through a regular VM portal page |
| Capacity | The number of instances |
| Minimum / maximum | Lower/upper bounds for configured autoscaling |
| Scale out / in | Add/remove instances |
| Scale up / down | Change the size/capability of an instance |
| Upgrade policy | How model changes are applied to existing instances |

The lab uses **Manual** upgrade policy, so adding an extension to the model is not enough: existing instances must receive the update. A newly launched instance must also get the web-server setup automatically, which is why the guide uses cloud-init.

## The load balancer is different from Application Gateway

Azure Standard Load Balancer handles layer-4 traffic, such as TCP connections. It does not provide the same HTTP host/path routing features as Application Gateway. Backend selection can be connection-hash based, so repeated requests need not alternate between server names.

A **health probe** checks backend availability. The **Application Health extension** reports health from inside the VM for the scale-set repair workflow used here. Both check a small HTTP health path, but they serve different control decisions. See [Application Health extension](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-health-extension).

## Why scaling takes time

The policy evaluates a metric over a **time window**, then decides whether a threshold has been crossed. A **cooldown** separates scaling actions. VM creation, package installation and becoming healthy take additional time. Capacity cannot appear instantly when the first busy request arrives.

Different scale-out and scale-in thresholds reduce repeated up/down changes, often called **flapping**. Average CPU can hide uneven load: one hot server does not necessarily make the whole group average high.

The lab runs bounded CPU work on the original instances, uses non-burstable VMs and leaves new instances idle. This creates a measurable signal without endlessly increasing demand. It is not a benchmark proving the application can serve a specific request rate.

## What replacement means for data

The selected repair action is **Replace**, not merely restart nginx. A replacement can receive a different underlying VM identity even if an instance number is reused. Record VM identity/provisioning information, not only a display name.

Application VMs should not hold the only copy of bookings, uploads or other durable state. **Stateless** means instances can be replaced without losing unique required application state; it does not mean the entire system has no database.

**Grace period** gives a new/changed instance time before repair decisions apply. A failed backend may stop receiving new traffic before its replacement finishes.

## AWS comparison

VMSS has similarities to EC2 Auto Scaling with a launch template. Model updates, orchestration modes, health extensions and repair policies differ. Do not assume deleting any standalone Azure VM will make Azure recreate it: the configured group/repair behavior matters.

## Check your understanding

1. A backend is removed from traffic. Has its VM necessarily been repaired?
2. Does changing the scale-set model always change current instances immediately?
3. Why does the group have a maximum of four?

**Answers:** (1) No; routing and repair are separate. (2) No; it depends on upgrade policy/application. (3) To bound this demonstration's capacity/cost, not because four is a universal production limit.

**Ready for the lab:** You can distinguish scaling, routing and repair events and know what evidence proves each.

Further reading: [VMSS autoscale](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-autoscale-overview), [automatic repairs](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-instance-repairs).
