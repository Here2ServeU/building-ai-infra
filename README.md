# Building AI Infrastructure: RAG Platform

> **Companion repo for the [Building AI Infrastructure](docs/series/README.md) video series**, 7 parts from "what is AI infrastructure?" to one platform across AWS, Azure, Google Cloud and on-prem.
>
> **New here? Open [START-HERE.md](START-HERE.md).** No cloud account needed: `make doctor`, then `make start`, then `make ask`.

### Chapter summaries (download)

| Part | Topic | PDF | Read online |
|:-:|---|---|---|
| 1 | The Building Blocks | [Download](docs/series/pdf/part-1-building-blocks.pdf) | [Web](docs/series/part-1-building-blocks.md) |
| 2 | The Foundation on Your Laptop | [Download](docs/series/pdf/part-2-laptop.pdf) | [Web](docs/series/part-2-laptop.md) |
| 3 | AWS: EKS and GPUs | [Download](docs/series/pdf/part-3-aws.pdf) | [Web](docs/series/part-3-aws.md) |
| 4 | Azure: AKS and GPUs | [Download](docs/series/pdf/part-4-azure.pdf) | [Web](docs/series/part-4-azure.md) |
| 5 | Google Cloud: GKE and GPUs | [Download](docs/series/pdf/part-5-gcp.pdf) | [Web](docs/series/part-5-gcp.md) |
| 6 | On-Premises: Your Data Center | [Download](docs/series/pdf/part-6-on-prem.pdf) | [Web](docs/series/part-6-on-prem.md) |
| 7 | One Platform Across All Four | [Download](docs/series/pdf/part-7-one-platform.pdf) | [Web](docs/series/part-7-one-platform.md) |

Each summary is 3–4 pages: key ideas in plain words, the 8 building blocks on that platform, commands, cost and clean-up, words to know, and check-yourself questions. Words you don't know are in the [glossary](docs/glossary.md).

> **About this repository.** This is a portfolio project by [Emmanuel Naweji](https://github.com/Here2ServeU) demonstrating production-shaped DevOps/MLOps for an enterprise AI/ML platform. It is not a deployed service — it is a working, lint-clean reference implementation showing how I architect multi-cloud Kubernetes, GitOps delivery, observability, and SRE tooling for RAG workloads. Recruiters and hiring teams: start with [ARCHITECTURE.md](ARCHITECTURE.md) for the system design, [docs/adr/](docs/adr/) for the decisions and trade-offs, and [docs/slo-policy.md](docs/slo-policy.md) for the reliability contract.

Production-shaped, cloud-native infrastructure for an enterprise RAG (Retrieval-Augmented Generation) platform. This repository implements the full operational stack — multi-cloud Kubernetes, GitOps delivery, observability, and SRE tooling — for serving large-scale AI/ML workloads.

## Highlights

- **Multi-cloud Kubernetes**: Terraform modules for **EKS** (AWS), **GKE** (GCP) and **AKS** (Azure), each with private control planes, IRSA/Workload Identity and autoscaling node pools. Optional **GPU pools that scale from 0** (`gpu_enabled`) and an AKS **Spot pool** (`spot_enabled`).
- **On-prem in the same fleet**: `onprem-openshift` reconciles from Git like the cloud clusters. The NVIDIA GPU Operator installs the driver there.
- **One set of rules and one cost view**: Kyverno policy as code (no root, no `:latest`, limits and cost labels required), OpenCost in every cluster, and idle-GPU alerts.
- **Recovery plan**: active-passive with written RTO/RPO and a drill schedule. See [docs/disaster-recovery.md](docs/disaster-recovery.md).
- **GitOps — FluxCD or ArgoCD** — every cluster is reconciled from `flux/clusters/<name>/` (default) or `argocd/clusters/<name>/` (alternative). Both consume the same Helm charts, so teams can pick the tool that fits their workflow without forking the platform. Bootstrapping is one command; promotion is a PR.
- **Helm charts** for the RAG API (Go), the document ingest worker (Python), and the vector database (Qdrant). Charts include HPA, PDB, NetworkPolicy, ServiceMonitor, and PrometheusRule resources.
- **Observability**: OpenTelemetry agent on every node plus a gateway per cluster, feeding Prometheus + Grafana + Loki + Tempo, SLOs defined as code with Sloth, golden-signal dashboards, and burn-rate alerts wired to PagerDuty/Slack.
- **SRE-first** — published SLOs, runbooks per alert, and self-healing automation for the most common production incidents.
- **Applications** — a Go retrieval API and a Python ingest worker integrated with **MLflow** for model tracking and **Airflow** for ingest orchestration.

## Layout

```
.
├── apps/                     # Service code (Go RAG API, Python ingest worker)
├── argocd/                   # ArgoCD GitOps configuration (alternative to flux/)
│   ├── clusters/             # Per-cluster app-of-apps roots
│   ├── infrastructure/       # Application manifests for shared platform components
│   ├── install/              # ArgoCD self-install kustomization
│   └── projects/             # AppProject definitions
├── docs/                     # Series guide, ADRs, runbooks, SLO policy, DR plan
├── flux/                     # FluxCD GitOps configuration (default)
│   ├── clusters/             # dev-eks, staging-gke, prod-aks, onprem-openshift
│   └── infrastructure/       # sources, controllers, policy, observability, telemetry, gpu
├── helm/charts/              # Helm charts for platform applications
├── kubernetes/               # Kustomize bases & overlays
├── observability/            # Prometheus rules, Grafana dashboards, SLO defs
├── scripts/                  # Bootstrap, chaos, self-healing tooling
└── terraform/
    ├── modules/              # Reusable IaC modules
    └── environments/         # dev / staging / prod root configurations
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the system design and [docs/](docs/) for runbooks, ADRs, and the SLO policy.

## Quick start

```bash
# 1. Provision a dev cluster (AWS EKS in us-east-1)
make tf-init ENV=dev
make tf-apply ENV=dev

# 2. Bootstrap GitOps against the new cluster — pick one of:
make flux-bootstrap   CLUSTER=dev-eks   # FluxCD (default)
make argocd-bootstrap CLUSTER=dev-eks   # ArgoCD (alternative)

# 3. Verify reconciliation
flux get kustomizations -A   # if Flux
argocd app list              # if ArgoCD
```

The cluster comes up with the platform stack (cert-manager, ingress-nginx, kube-prometheus-stack, Loki, Tempo) reconciled from `flux/clusters/dev-eks/` or `argocd/clusters/dev-eks/`. See [argocd/README.md](argocd/README.md) for the comparison and trade-offs.

## Local development

```bash
# Run the RAG API locally in stub mode (no cluster, embedder or vector DB needed)
make start
make ask Q="what is GitOps?"     # in a second terminal

# Run the ingest worker against a local Airflow + MLflow
make ingest-worker-up

# Lint everything (Go, Python, Terraform, Helm, YAML)
make lint
```

## Production readiness checklist

| Area | Status |
| --- | --- |
| Multi-cloud Terraform (EKS / GKE / AKS) | ✅ |
| GitOps continuous delivery (FluxCD or ArgoCD) | ✅ |
| Helm charts (HPA, PDB, NetworkPolicy, ServiceMonitor) | ✅ |
| Prometheus + Grafana + Loki + Tempo | ✅ |
| SLO-as-code (Sloth) and burn-rate alerts | ✅ |
| Runbooks for top alerts | ✅ |
| Self-healing automation | ✅ |
| Security: IRSA / Workload Identity / NetworkPolicy / PSA-restricted | ✅ |
| Supply chain: image scanning, SBOM, signed images | ✅ (signature *enforcement* policy pending: needs cosign key) |
| GPU pools 0 → N (EKS / AKS / GKE) + NVIDIA GPU Operator | Defined, opt-in |
| Policy as code (Kyverno) | Defined, `Audit` mode |
| Cost: OpenCost + idle-GPU alerts | Defined |
| On-prem cluster in the GitOps fleet | Defined |
| DR plan with RTO/RPO + drills | Documented; drills not yet recorded |
| Compliance scaffolding (SOC2-aligned controls in IaC) | ✅ |

## License

MIT — see [LICENSE](LICENSE).
