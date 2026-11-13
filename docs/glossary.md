# Glossary

Plain-language definitions for words used in the series and this repo. The number in brackets is the part where the word first matters.

| Word | What it means |
|---|---|
| **Active-passive** [7] | One site serves traffic, and a standby takes over if it fails. |
| **Air-gapped** [6] | A network with no internet connection at all. |
| **Autoscaler (cluster)** [3] | Adds machines when pods are waiting and removes idle ones. |
| **Bare metal** [6] | Physical servers with no cloud layer. |
| **Burn rate** [2, 5] | How fast you're using up the error budget, compared with normal. |
| **Canary release** [1] | Sending a small share of traffic (for example 10%) to a new version first. |
| **Chart (Helm)** [2] | A package that installs an app on Kubernetes. |
| **Cluster** [1] | A group of machines that Kubernetes manages as one. |
| **Container** [1] | An app packed with everything it needs, so it runs the same everywhere. |
| **CPU / GPU** [1] | General-purpose processor / processor built for massively parallel math (ideal for AI). |
| **Data drift** [2] | Real-world input slowly no longer looking like the training data. |
| **DCGM** [3] | NVIDIA's GPU metrics (utilization, memory, temperature). |
| **Drift (GitOps)** [7] | A cluster no longer matching what Git says it should be. |
| **EKS / AKS / GKE** [3–5] | Managed Kubernetes on AWS / Azure / Google Cloud. |
| **Embedding** | A list of numbers that captures the meaning of text, used to find similar text. |
| **Error budget** [2, 5] | The amount of failure an SLO allows (a 99.5% target means a 0.5% budget). |
| **GitOps** [7] | Running infrastructure through pull requests; clusters pull their state from Git. |
| **GPU Operator** [3] | Installs everything Kubernetes needs to use NVIDIA GPUs. |
| **Helm** [2] | The package manager for Kubernetes. |
| **IRSA / Workload Identity** [3–5] | Gives each pod its own cloud permissions using short-lived tokens, with no passwords. |
| **kind** [2] | "Kubernetes in Docker", a real cluster on your laptop. |
| **Kubernetes** [1] | Software that runs containers across many machines, restarts them and scales them. |
| **Kyverno** [7] | A policy engine that checks every change against your rules. |
| **Least privilege** [1] | Give each person or app only the access it needs. |
| **Load balancer** [1] | The front door that spreads requests across healthy servers. |
| **MIG / time-slicing** [6] | Ways to share one GPU between several workloads. |
| **MLflow** [2] | Tracks experiments and keeps a registry of model versions. |
| **MLOps** [1] | Training, tracking and releasing models the same way every time. |
| **Node / node pool** [3] | A machine in the cluster / a group of identical machines. |
| **Object storage** [1] | Cheap, nearly unlimited storage for files (S3, Blob, GCS, MinIO). |
| **OpenCost** [7] | Shows what each team and app costs inside Kubernetes. |
| **OpenTelemetry (OTel)** [2, 7] | One standard way to collect metrics, logs and traces. |
| **Pod** [2] | The smallest thing Kubernetes runs: one or more containers. |
| **RAG** | Retrieval-augmented generation: find relevant documents, then use them to answer. |
| **RTO / RPO** [7] | Max downtime you accept / max data you can afford to lose. |
| **SBOM** [7] | A list of everything inside a container image. |
| **SLO** [1, 5] | A measurable reliability promise, such as "99.9% of requests succeed". |
| **Spot VM** [4] | Discounted spare capacity the cloud can take back at any time. |
| **Taint / toleration** [3] | A "keep out" sign on a node, and the pass a pod needs to get past it. |
| **Terraform** [3] | Builds cloud infrastructure from code; `plan` shows changes before `apply` makes them. |
| **Vector database** | Stores embeddings and finds the most similar ones quickly (this repo uses Qdrant). |
| **vLLM** [3] | A fast server for large language models. |
| **VPC / VNet** [1] | Your private network in the cloud (AWS and Google / Azure). |
