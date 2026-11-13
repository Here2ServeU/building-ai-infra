---
title: "Part 4: Azure — AKS and GPUs"
subtitle: "Building AI Infrastructure · Chapter summary"
part: 4
---

**In one sentence:** the same platform on Microsoft Azure: an AKS cluster with system, Spot and GPU pools, and pods that reach Azure services with no passwords at all.

**Video length:** about 9 minutes · **Code:** [nawex-platform](https://github.com/Here2ServeU/nawex-platform), or this repo's [`terraform/modules/aks`](../../terraform/modules/aks) · **Cost:** a few dollars if you destroy the same day

## Why Azure

Many companies in finance, healthcare and government already live in the Microsoft world, so knowing how to build AI infrastructure on Azure is a real career advantage.

## The 8 blocks on Azure

| # | Block | On Azure |
|:-:|---|---|
| 1 | Compute | VMs in three pools: system, **Spot**, GPU (**NC4as T4 v3**, 1× NVIDIA T4) |
| 2 | Data and storage | Blob Storage / Data Lake; **ACR** for images |
| 3 | Networking | VNet, subnets, Azure load balancer |
| 4 | Orchestration | **AKS**, managed Kubernetes |
| 5 | MLOps | MLflow + Kubeflow (or Azure Machine Learning) |
| 6 | Serving | KServe + vLLM on the GPU pool |
| 7 | Observability | Azure Monitor + Prometheus + Grafana |
| 8 | Guardrails | **Entra ID**, **Workload Identity**, **Key Vault**, Cost Management |

## Three things before you build

1. **Budget:** Cost Management → Budgets, set on your subscription, with alerts at 50%, 90% and 100%.
2. **GPU quota:** Quotas → Compute → *Standard NCASv3_T4 Family vCPUs*. Request 4, and check that your region offers that size.
3. **Tools:** Azure CLI, Terraform (1.6+), kubectl and helm. Run `az login`, then check you're in the right subscription with `az account show`.

## Three pools, three jobs

- **System pool:** runs Kubernetes' own services.
- **Spot pool:** spare Azure capacity at a big discount. Azure can take these machines back at short notice, so use it **only for work that can be retried**, such as batch or training jobs.
- **GPU pool:** min 0, with the same `nvidia.com/gpu` taint as on AWS.

> Put the right work on the right machine: training on Spot, serving on the GPU pool.

## The big idea: pods with identity, no passwords

The old way puts a password in the app's configuration. It leaks, nobody rotates it, and one day it ends up on GitHub. The new way is **Workload Identity**:

1. Terraform creates a **managed identity** in Azure.
2. That identity is set to trust tokens from your AKS cluster (its OIDC issuer).
3. A Kubernetes **service account** is annotated with the identity's client ID.
4. Any pod that uses the service account gets a **short-lived token automatically**.
5. The pod reads Key Vault or Blob Storage with exactly the permissions you gave it, and nothing more.

AWS calls the same idea **IRSA**, and Google calls it **Workload Identity**.

## Build it

```bash
cd nawex-platform
cp deploy/terraform/live/azure/dev/terraform.tfvars.example deploy/terraform/live/azure/dev/terraform.tfvars
GPU_ENABLED=1 scripts/deploy.sh azure dev plan
GPU_ENABLED=1 scripts/deploy.sh azure dev apply
kubectl get nodes -L agentpool -L nvidia.com/gpu.present
kubectl get sa -A -o yaml | grep azure.workload.identity
```

Notice it's the same script as AWS: only the word `aws` changed to `azure`. With this repo: `terraform -chdir=terraform/environments/prod plan -var gpu_enabled=true -var spot_enabled=true`.

## GPUs on AKS

Use the same GPU Operator chart with `driver.enabled=false`, because AKS GPU nodes ship with the driver. Use the same vLLM manifest too. The pod goes Pending, the pool grows 0 → 1, the model serves, and when you delete it the pool shrinks back to 0.

## Cost and clean-up

You pay for running VMs (GPUs most of all), the load balancer and public IPs, and any disks you leave behind. The AKS free tier doesn't charge for the control plane, but paid tiers do.

**Tear down:** `scripts/deploy.sh azure dev destroy`. Then check for the extra resource group AKS creates, whose name starts with **`MC_`**.

## Words to know

- **VNet:** Azure's private network (the same idea as a VPC).
- **Spot VM:** discounted spare capacity that Azure can take back at any time.
- **Managed identity:** an Azure identity for software, with no password to manage.
- **Workload Identity:** lets a pod use a managed identity through short-lived tokens.
- **Key Vault:** Azure's secret store.
- **Entra ID:** Azure's identity service for people (formerly Azure AD).

## Check yourself

1. What kind of work belongs on the Spot pool, and why?
2. In Workload Identity, what does the pod receive instead of a password?
3. What's the AWS name for the same idea?
4. Which leftover resource group should you check after destroying?

*Answers:* 1) Retryable batch or training work, because Azure can take Spot machines back. 2) A short-lived token, issued automatically. 3) IRSA. 4) The `MC_*` resource group.

**Next: Part 5, Google Cloud with GKE, plus SLOs as code.**
