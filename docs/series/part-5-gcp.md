---
title: "Part 5: Google Cloud — GKE and GPUs"
subtitle: "Building AI Infrastructure · Chapter summary"
part: 5
---

**In one sentence:** the same platform on Google Cloud: a private GKE cluster, a GPU pool where Google installs the driver for you, and reliability targets written as code.

**Video length:** about 9 minutes · **Code:** [nawex-platform](https://github.com/Here2ServeU/nawex-platform), this repo's [`terraform/modules/gke`](../../terraform/modules/gke) and [`observability/slo`](../../observability/slo) · **Cost:** often covered by trial credit

## The 8 blocks on Google Cloud

| # | Block | On Google Cloud |
|:-:|---|---|
| 1 | Compute | Compute Engine: general pool + GPU pool (**NVIDIA T4**) |
| 2 | Data and storage | Cloud Storage; **Artifact Registry** for images |
| 3 | Networking | VPC-native network, private nodes, **Cloud NAT** |
| 4 | Orchestration | **GKE**, in Standard or Autopilot mode |
| 5 | MLOps | MLflow + Kubeflow (or Vertex AI) |
| 6 | Serving | KServe + vLLM on the GPU pool |
| 7 | Observability | Cloud Monitoring, Managed Prometheus, **SLOs** |
| 8 | Guardrails | IAM, Workload Identity, Secret Manager, budgets |

**VPC-native** means pods get real addresses from the network. **Private nodes** have no public IPs, and **Cloud NAT** lets them reach the internet on the way out only.

## Three things before you build

1. **Budget:** Billing → Budgets & alerts. Set one even if you have trial credit.
2. **Two GPU quotas.** Google needs both *NVIDIA T4 GPUs* (in your region) **and** *GPUs (all regions)*. Request at least 1 of each; people often miss the global one.
3. **Log in twice:** `gcloud auth login` (for you) and `gcloud auth application-default login` (for Terraform). Then run `gcloud config set project <id>`.

## Build it

```bash
cd nawex-platform
cp deploy/terraform/live/gcp/dev/terraform.tfvars.example deploy/terraform/live/gcp/dev/terraform.tfvars
export GCP_PROJECT=my-project-id
GPU_ENABLED=1 scripts/deploy.sh gcp dev plan
GPU_ENABLED=1 scripts/deploy.sh gcp dev apply
kubectl get nodes -L cloud.google.com/gke-nodepool -L nvidia.com/gpu.present
```

With this repo: `terraform -chdir=terraform/environments/staging plan -var gpu_enabled=true`.

## GPUs on GKE

The GPU pool sets `gpu_driver_version = DEFAULT`, so **GKE installs the NVIDIA driver at boot**. You still install the GPU Operator (with `driver.enabled=false`) for metrics and labels. Same vLLM manifest, same 0 → 1 → 0 behaviour.

**Standard vs. Autopilot:** in Autopilot, Google manages every node and bills per pod. It's simpler, but you get less control over GPUs. Standard is better for learning the full picture.

## The big idea: SLOs as code

An **SLO** is a promise about reliability. Instead of alerting on every error, you alert on how fast you're spending the error budget.

| Number | Meaning |
|---|---|
| **99.5%** | of requests succeed over 28 days: the availability SLO. That leaves a 0.5% **error budget**. |
| **14.4×** | burn rate over 1 hour: you'd spend about 2% of the month's budget in that hour. **Page someone now.** |
| **6×** | burn rate over 6 hours: a slow leak. **Open a ticket.** |

This is the multi-window, multi-burn-rate method from Google's SRE Workbook. In this repo the SLOs live in [`observability/slo/`](../../observability/slo) (Sloth format). The video's Terraform version is in express-reliability-platform-course v10.

## Cost and clean-up

GKE has a cluster management fee, but one zonal or Autopilot cluster per billing account falls under a free tier. You pay for nodes (GPUs most of all), Cloud NAT and the load balancer.

**Tear down:** `scripts/deploy.sh gcp dev destroy`. Then check for leftover **disks** and **forwarding rules**.

## Words to know

- **Cloud NAT:** lets private machines reach the internet without being reachable from it.
- **Autopilot:** a GKE mode where Google runs the nodes for you.
- **Error budget:** the failure an SLO allows (100% minus the target).
- **Burn rate:** how fast you're spending the budget, compared with "just on target".
- **Page vs. ticket:** wake someone now, vs. fix it during working hours.

## Check yourself

1. Which two GPU quotas does Google need?
2. Who installs the GPU driver on GKE?
3. With a 99.5% SLO, what's the error budget?
4. A 14.4× burn over 1 hour: page or ticket?

*Answers:* 1) NVIDIA T4 GPUs in your region, and GPUs (all regions). 2) GKE itself, at boot (`gpu_driver_version = DEFAULT`). 3) 0.5%. 4) Page.

**Next: Part 6, the same platform on your own hardware, in a data center.**
