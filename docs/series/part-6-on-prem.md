---
title: "Part 6: On-Premises — Your Data Center"
subtitle: "Building AI Infrastructure · Chapter summary"
part: 6
---

**In one sentence:** leave the cloud and run the same platform on hardware you own. The top layers stay the same, and every layer underneath becomes your job.

**Video length:** about 8 minutes · **Code:** nawex-platform `deploy/ansible`, [openshift-k8s-ai-infra](https://github.com/Here2ServeU/openshift-k8s-ai-infra) `platform/openshift`, this repo's [`flux/clusters/onprem-openshift`](../../flux/clusters/onprem-openshift) · **Cost:** hardware you already own

## Why AI runs on-prem

Banks, hospitals, defense and government often can't or won't send data to a public cloud. And if GPUs run all day, every day, owning them can cost less than renting them.

## The 8 blocks on-prem

| # | Block | On your own hardware |
|:-:|---|---|
| 1 | Compute | GPU servers (for example NVIDIA HGX-class) + CPU servers |
| 2 | Data and storage | **Ceph** / OpenShift Data Foundation, with **MinIO** for an S3-compatible API |
| 3 | Networking | VLANs, firewall, internal DNS, **MetalLB** (load balancer IPs on bare metal) |
| 4 | Orchestration | **OpenShift** (or RKE2 / kubeadm) |
| 5 | MLOps | MLflow + Kubeflow, or OpenShift AI |
| 6 | Serving | KServe + vLLM on GPU worker nodes |
| 7 | Observability | Prometheus, Grafana, OpenTelemetry, often Splunk |
| 8 | Guardrails | Active Directory / LDAP, **Vault**, RBAC, OpenCost |

## The honest trade

| Now your job | What you gain | What you trade |
|---|---|---|
| Buy, rack, power and cool servers | Data never leaves the building | No scaling to zero on hardware you own |
| Install and patch the OS and drivers | Fixed cost for GPUs running 24/7 | Months to buy GPUs, not minutes |
| Networking and load balancers | Full control, air-gap options | You need the skills in-house |
| Storage, backups, spare parts | Meets strict regulators | Capacity planning matters |

## From bare metal to serving: 5 steps

1. **Baseline the OS** with Ansible: patching, time sync and hardening (nawex-platform has a RHEL baseline playbook).
2. **Install OpenShift**, or a lighter Kubernetes such as RKE2.
3. **Storage and network:** ODF/Ceph for storage, and MetalLB so services get load balancer IPs.
4. **GPU operators:** **Node Feature Discovery** first, then the **NVIDIA GPU Operator with the driver turned on**, because there's no cloud image to provide it.
5. **The platform itself** with Helm: MLflow, KServe and vLLM. In this repo, `make flux-bootstrap CLUSTER=onprem-openshift` adds the cluster to the GitOps fleet.

## Air-gapped and regulated

Many on-prem sites have **no internet at all**:

- Mirror container images to an internal registry.
- Mirror Helm charts and OS packages too.
- Bring model weights in through a reviewed, approved path.

Regulators need proof:

- Every change goes through Git and a review.
- Audit logs are kept and protected from editing.
- Access is tied to named people, not shared accounts.

> If you can't show who changed what, and when, it didn't pass the audit.

## Capacity: you can't scale to zero

The hardware is there whether you use it or not, so the goal is to use every GPU well:

- **MIG** splits one big GPU into isolated slices for several small models.
- **Time-slicing** shares a GPU for notebooks and light work.
- **Quotas per team** stop one group from taking every GPU.
- **Measure weekly** with DCGM metrics. This repo's `GPUWeeklyUtilizationLow` alert does it for you.

## Words to know

- **Bare metal:** physical servers with no cloud layer.
- **OpenShift:** Red Hat's enterprise Kubernetes distribution.
- **MetalLB:** gives Kubernetes load balancer addresses on bare metal.
- **Node Feature Discovery (NFD):** detects hardware such as GPUs and labels the nodes.
- **Air-gapped:** fully disconnected from the internet.
- **MIG:** Multi-Instance GPU, one physical GPU split into isolated slices.

## Check yourself

1. Why is the GPU Operator's driver turned **on** here but off in the clouds?
2. What does MetalLB replace?
3. Name two things you must mirror for an air-gapped install.
4. Why measure GPU usage every week on-prem?

*Answers:* 1) No cloud image provides the driver on your own servers. 2) The cloud's managed load balancer. 3) Any two of: container images, Helm charts, OS packages, model weights. 4) Buying more GPUs takes months, so you have to see shortages coming.

**Next: Part 7, the finale: one platform across all four.**
