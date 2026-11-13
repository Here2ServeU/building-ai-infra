# Building AI Infrastructure: companion guide

This repository is the code companion for **Building AI Infrastructure**, a 7-part video series by [Emmanuel Naweji](https://emmanuelnaweji.com) ([transformed2succeed.com](https://transformed2succeed.com)). Every part builds the same layered platform. Only the bottom layer changes, from a laptop to AWS, Azure, Google Cloud and your own data center.

> In earlier versions of the decks this repo is called `nawex-ai-ml-infrastructure`. That name now redirects here.

## Chapter summaries

Short, beginner-friendly summaries of each part (3–4 pages each), in PDF and on the web:

| Part | PDF | Web |
|:-:|---|---|
| 1 | [part-1-building-blocks.pdf](pdf/part-1-building-blocks.pdf) | [Read](part-1-building-blocks.md) |
| 2 | [part-2-laptop.pdf](pdf/part-2-laptop.pdf) | [Read](part-2-laptop.md) |
| 3 | [part-3-aws.pdf](pdf/part-3-aws.pdf) | [Read](part-3-aws.md) |
| 4 | [part-4-azure.pdf](pdf/part-4-azure.pdf) | [Read](part-4-azure.md) |
| 5 | [part-5-gcp.pdf](pdf/part-5-gcp.pdf) | [Read](part-5-gcp.md) |
| 6 | [part-6-on-prem.pdf](pdf/part-6-on-prem.pdf) | [Read](part-6-on-prem.md) |
| 7 | [part-7-one-platform.pdf](pdf/part-7-one-platform.pdf) | [Read](part-7-one-platform.md) |

To edit a summary, change the `.md` file and run `make pdfs`. The PDF styling lives in [`pdf-src/`](pdf-src/).

## The parts

| Part | Title | What you build | Where the code is |
| :-: | --- | --- | --- |
| 1 | The Building Blocks | No code: the 8 blocks, explained as a restaurant kitchen | [The 8 building blocks](#the-8-building-blocks) below |
| 2 | The Foundation on Your Laptop | All 8 blocks on kind, for free | [nawex-observability-case-study](https://github.com/Here2ServeU/nawex-observability-case-study) `demo/` |
| 3 | AWS: EKS and GPUs | VPC + EKS + GPU node group that scales 0 to N | [nawex-platform](https://github.com/Here2ServeU/nawex-platform), or here: [`terraform/modules/eks`](../../terraform/modules/eks) (`gpu_enabled`) |
| 4 | Azure: AKS and GPUs | VNet + AKS with system, Spot and GPU pools; Workload Identity | nawex-platform, or here: [`terraform/modules/aks`](../../terraform/modules/aks) (`spot_enabled`, `gpu_enabled`) |
| 5 | Google Cloud: GKE and GPUs | Private GKE, Google-managed GPU driver, SLOs as code | nawex-platform, or here: [`terraform/modules/gke`](../../terraform/modules/gke) (`gpu_enabled`); SLOs: express-reliability-platform-course v10 |
| 6 | On-Premises: Your Data Center | OpenShift, NFD + NVIDIA GPU Operator, air-gapped installs | nawex-platform `deploy/ansible`, [openshift-k8s-ai-infra](https://github.com/Here2ServeU/openshift-k8s-ai-infra) `platform/openshift`; fleet entry here: [`flux/clusters/onprem-openshift`](../../flux/clusters/onprem-openshift) |
| 7 | One Platform Across All Four | GitOps fleet, one observability pipeline, policy, cost, recovery | **This repo** (see [Part 7 map](#part-7-map)) |

## The 8 building blocks

Part 1's map, with what plays each role on each platform and where it lives in this repo.

| # | Block (kitchen) | Laptop (P2) | AWS (P3) | Azure (P4) | GCP (P5) | On-prem (P6) | In this repo |
| :-: | --- | --- | --- | --- | --- | --- | --- |
| 1 | Compute (stove) | Laptop CPU | EC2 + g5.xlarge GPU group | System / Spot / NC4as T4 v3 pools | Compute Engine + T4 pool | GPU + CPU servers | `terraform/modules/{eks,aks,gke}` |
| 2 | Data and storage (pantry) | MinIO + Postgres | S3, ECR | Blob / Data Lake, ACR | Cloud Storage, Artifact Registry | Ceph / ODF + MinIO | `helm/charts/vector-db`, storage classes per cluster |
| 3 | Networking (hallways, doors) | kind network | VPC, private subnets, ALB | VNet, LB | VPC-native, Cloud NAT | VLANs, firewall, MetalLB | `terraform/modules/vpc-aws`, ingress-nginx |
| 4 | Orchestration (head chef) | kind | EKS | AKS | GKE | OpenShift | `flux/`, `argocd/` |
| 5 | MLOps (recipe book) | MLflow | MLflow + Kubeflow | MLflow + Kubeflow | MLflow + Kubeflow | MLflow + Kubeflow / OpenShift AI | `apps/ingest-worker` (MLflow, Airflow) |
| 6 | Serving (serving window) | KServe | KServe + vLLM | KServe + vLLM | KServe + vLLM | KServe + vLLM | `apps/rag-api`; GPU Operator in `flux/infrastructure/gpu` |
| 7 | Observability (inspector) | Prometheus, Grafana, Loki, OTel | + CloudWatch | + Azure Monitor | + Cloud Monitoring | + Splunk | `observability/`, `flux/infrastructure/telemetry` |
| 8 | Guardrails (locks, keys, budget) | admin/admin (practice only) | IAM + IRSA, Secrets Manager, Budgets | Entra ID, Workload Identity, Key Vault | IAM, Workload Identity, Secret Manager | LDAP/AD, Vault, RBAC, OpenCost | `flux/infrastructure/policy`, External Secrets, OpenCost |

## Parts 3 to 5 in this repo: GPU pools that scale from zero

Each cloud module has a GPU pool that is **off by default**. When it's on, the pool has a minimum of 0 nodes and is tainted `nvidia.com/gpu=present:NoSchedule`, so only pods that ask for a GPU land there.

Before you turn it on, every time:

1. Set a budget alert on the account (for example $10/month, with alerts at 50/90/100%).
2. Request GPU quota a few days ahead:
   - AWS: "Running On-Demand G and VT instances" (g5.xlarge needs 4 vCPUs).
   - Azure: "Standard NCASv3_T4 Family vCPUs" (NC4as T4 v3 needs 4). Check that your region offers the size.
   - GCP: "NVIDIA T4 GPUs" in your region **and** "GPUs (all regions)".
3. Plan before you apply, then destroy the same day.

```bash
# AWS (dev-eks)
terraform -chdir=terraform/environments/dev plan -var gpu_enabled=true -out=plan.tfplan
# Azure (prod-aks): add the Spot pool for retryable batch work
terraform -chdir=terraform/environments/prod plan -var gpu_enabled=true -var spot_enabled=true -out=plan.tfplan
# GCP (staging-gke): GKE installs the driver (gpu_driver_version = DEFAULT)
terraform -chdir=terraform/environments/staging plan -var gpu_enabled=true -out=plan.tfplan
```

Then turn on the GPU Operator for that cluster by uncommenting the `infra-gpu` block in `flux/clusters/<cluster>/infrastructure.yaml`. In the cloud it runs with `driver.enabled=false`, because the EKS NVIDIA AMI, AKS and GKE all supply the driver. On-prem, the operator installs the driver itself.

To serve an LLM with vLLM and watch the pool go 0 → 1 → 0, use the manifest in nawex-platform `deploy/k8s/ml-serving`.

Tear down with `make tf-destroy ENV=<env>`. Then check the console for leftover load balancers, disks and public IPs, plus the `MC_*` resource group on Azure and forwarding rules on GCP.

## Part 7 map

The five things that make it one platform, and where each one lives:

| Slide | What | Where |
| --- | --- | --- |
| GitOps | Every cluster pulls its desired state from Git; promotion is a PR; drift is reverted | `flux/clusters/{dev-eks,staging-gke,prod-aks,onprem-openshift}`, or the same under `argocd/clusters/` |
| One observability | OTel agent on every node, a gateway per cluster, then Tempo / Loki / Prometheus; same SLOs and runbooks everywhere | `flux/infrastructure/telemetry`, `observability/slo`, `docs/runbooks` |
| One identity and policy | No root, no `:latest`, limits required, team/cost-center labels; workload identity on all three clouds; External Secrets | `flux/infrastructure/policy` (Kyverno), `terraform/modules/*` |
| One cost view | OpenCost in every cluster, cost labels enforced, idle-GPU alerts | `flux/infrastructure/controllers/opencost.yaml`, `observability/prometheus/gpu-cost-rules.yaml` |
| Recovery plan | Active-passive first, written RTO/RPO, tested by drill | [`docs/disaster-recovery.md`](../disaster-recovery.md) |

## Honest status

Following the series rule, only say "running" for what you have actually deployed.

- **Defined in code, linted, not deployed by this repo's CI:** the GPU pools, Spot pool, GPU Operator, Kyverno policies, OpenCost, OTel collectors and the on-prem cluster folder.
- **Kyverno policies start in `Audit`.** Switch each one to `Enforce` once its policy report is clean.
- **Image signature verification** (only signed images can run) is not yet a policy here. It needs your cosign public key. Add a `verifyImages` ClusterPolicy once images are signed in CI.
- **The Argo CD path** installs Kyverno, the policies and OpenCost. The OTel collectors and Prometheus rules are Flux-only for now.
