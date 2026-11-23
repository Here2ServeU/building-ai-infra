---
title: "Part 2: The Foundation on Your Laptop"
subtitle: "Building AI Infrastructure · Chapter summary"
part: 2
---

**In one sentence:** run all 8 building blocks on your own laptop, for free, with the same tools you'll later use in every cloud.

**Video length:** about 10 minutes · **Code:** [`demo/`](../../demo/) in this repo · **Cost:** $0

## Why start on a laptop

The cloud charges you while you learn. On a laptop you can break things, rebuild them and break them again, and it costs nothing. Every tool here is the same one you'll use on AWS, Azure, Google Cloud and on-prem. Only the machines underneath change.

## The 8 blocks on a laptop

| # | Block | What plays the role locally |
|:-:|---|---|
| 1 | Compute | Your laptop's CPU (no GPU needed yet) |
| 2 | Data and storage | **MinIO** (speaks the same language as Amazon S3) + **Postgres** |
| 3 | Networking | kind's built-in network + port-forwards |
| 4 | Orchestration | **kind**: a real Kubernetes cluster running inside Docker |
| 5 | MLOps | **MLflow**: experiment tracking + model registry |
| 6 | Serving | **KServe** InferenceService |
| 7 | Observability | Prometheus, Grafana, Loki (logs), OpenTelemetry |
| 8 | Guardrails | Simple local passwords (admin/admin). Fine for practice, never for production |

## What you need

- **Docker Desktop** with **at least 6 CPUs and 10 GB of memory** (Docker settings → Resources). Install it from [docs.docker.com/get-docker](https://docs.docker.com/get-docker/).
- **git** and **make**. New to these? Watch: [Install Git on Windows](https://www.youtube.com/watch?v=f091sbQSv7I) · [Install Git on Mac](https://www.youtube.com/watch?v=8ZIiXg4XOY0).
- **kind, kubectl, helm, jq**. You don't need to install these one by one. The repo does it for you:

```bash
git clone https://github.com/Here2ServeU/building-ai-infra
cd building-ai-infra
make install-tools   # installs kind, kubectl, helm, jq; skips what you already have
make doctor          # checks everything; installs nothing
```

| Your computer | How `make install-tools` works |
|---|---|
| **Mac** | Uses [Homebrew](https://brew.sh). Install Homebrew first if you don't have it. |
| **Linux** | Downloads the official tools into `/usr/local/bin` (asks for your password once). |
| **Windows** | Use **WSL 2**: run `wsl --install` in PowerShell as admin and restart. In Docker Desktop, turn on Settings → Resources → WSL integration. Then open Ubuntu and run the commands above there. |

## Build it: one command

```bash
git clone https://github.com/Here2ServeU/building-ai-infra
cd building-ai-infra/demo
make up      # about 10 minutes the first time; watch each block report "ready"
make demo    # opens Grafana, Alertmanager, Prometheus and MLflow
```

### What you'll see

Each block prints a yellow `→` line when it starts and a green `✓` line when it's ready:

```text
→ creating the kind cluster (3 nodes)...
✓ kind cluster ready
→ starting MinIO + Postgres (first run downloads images, 2-5 min)...
✓ minio + postgres ready
✓ loki ready
✓ kube-prometheus-stack ready        # the longest step, 3-8 min
✓ otel gateway + agent ready
✓ mlflow ready
✓ kserve ready
✓ sample-app + load-generator
✓ inference service ready
Platform is up. Next: make demo
```

**It looks stuck?** It's usually downloading images. Leave it running. In a second terminal, `kubectl get pods -A` shows what's starting. Only act if it stops with a red `✗` or an error.

**Wait for `✓ inference service ready` before `make demo`.** If the cluster isn't up yet, `make demo` tells you so instead of opening broken pages.

`make up` is safe to run again. It reuses the cluster and picks up where it stopped.

### If something fails

| You see | What it means | Fix |
|---|---|---|
| `ports ... already in use ... used by container <name>-control-plane` | Another kind cluster is using the same ports | Pause it: `docker stop $(docker ps -q --filter label=io.x-k8s.kind.cluster=<name>)`. Or, if you don't need it, delete it: `kind delete cluster --name <name>`. Then `make up` again. |
| `port ... used by process ...` | Another app (a dev server, AirPlay on macOS) has the port | Stop that app, then `make up` again |
| A step times out, or pods stay `Pending` | Docker doesn't have enough memory or CPU | Docker settings → Resources: 10 GB / 6 CPUs, then `make up` again |
| `Docker is not running` | Docker Desktop is closed | Start it, wait for the whale icon to settle, then `make up` |
| `kubectl` talks to the wrong cluster | Another tool changed your kubeconfig | `make kubeconfig` |

To bring a paused cluster back later: `make down`, then `docker start $(docker ps -aq --filter label=io.x-k8s.kind.cluster=<name>)`.

## Tour: one stop per block

1. `kubectl get pods -A`: every block is just a group of pods.
2. **MLflow** at `localhost:5001`: runs, metrics and the model registry (the recipe book).
3. `kubectl get inferenceservice -A`: the model being served, and whether it's ready.
4. **Grafana** at `localhost:3000`: request rate, errors and latency, plus a model dashboard.
5. **Prometheus**: the raw numbers and the alert rules behind the dashboards.

## Break it on purpose (the SRE habit)

**SLO burn.** Run `make scenario-slo-burn`. Errors climb, the **error budget** (how much failure you're allowed this month) drops fast, and the fast-burn alert fires in about 2 minutes. Recover with `make scenario-slo-burn-stop`.

> You should only trust an alert you've actually watched fire.

**Data drift (unique to AI).** Run `make scenario-drift`. The incoming data stops looking like the training data, and the model quietly gets worse while nothing crashes. The **PSI** (population stability index) score rises, and the drift alert fires in 1 to 3 minutes. Respond by retraining, or roll back with `make scenario-rollback`.

## Laptop vs. the real thing

| Stays the same everywhere | Changes in the cloud |
|---|---|
| Kubernetes APIs and kubectl | Real GPUs, in a pool that scales to 0 |
| Helm charts | S3 / Blob / GCS instead of MinIO |
| MLflow, KServe | Load balancers, private networks |
| Prometheus, Grafana, OpenTelemetry | Real identity, secrets and budgets |

**Clean up:** `make down` deletes the cluster, and your laptop is back to normal.

## Words to know

- **kind:** "Kubernetes in Docker", a full cluster on your laptop.
- **Pod:** the smallest thing Kubernetes runs, made of one or more containers.
- **Error budget:** the amount of failure an SLO allows (99.5% success means a 0.5% budget).
- **Burn rate:** how fast you're spending the error budget compared with normal.
- **Data drift:** real-world input gradually differing from the training data.
- **PSI:** a score for how far today's data has moved from the training data.

## Check yourself

1. Which tool plays the role of Amazon S3 on a laptop?
2. Why fire alerts on purpose?
3. Why is data drift dangerous even though nothing crashes?
4. Name two things that change when you move to the cloud.

*Answers:* 1) MinIO. 2) So you know the alert works before a real outage. 3) The model silently gives worse answers. 4) Any two of: real GPUs that scale to zero, managed storage, load balancers and private networks, real identity, secrets and budgets.

**Next: Part 3, the same platform on AWS with EKS and GPUs. Set your AWS budget alert and request GPU quota now.**
