# Local demo: all 8 building blocks on your laptop

This is the code for **Part 2: The Foundation on Your Laptop**. One command builds a real
Kubernetes cluster in Docker with storage, MLOps, model serving and full observability. It costs $0.

| # | Block | What plays the role locally |
|:-:|---|---|
| 1 | Compute | Your laptop's CPU (no GPU needed) |
| 2 | Data and storage | **MinIO** (S3-compatible) + **Postgres** |
| 3 | Networking | kind's network + NodePorts mapped to `localhost` |
| 4 | Orchestration | **kind**: a 3-node Kubernetes cluster inside Docker |
| 5 | MLOps | **MLflow**: experiment tracking + model registry |
| 6 | Serving | **KServe** InferenceService (`doc-classifier`) |
| 7 | Observability | Prometheus, Grafana, Alertmanager, Loki, OpenTelemetry |
| 8 | Guardrails | Local passwords (admin/admin). Fine for practice, never for production |

## What you need

- Docker Desktop with **at least 6 CPUs and 10 GB of memory** (Settings → Resources).
- `kind`, `kubectl`, `helm`, `jq`, `curl`, `git`. Run `make doctor` from the repo root to check.
- Internet access the first time (images and Helm charts are downloaded).

## Run it

```bash
git clone https://github.com/Here2ServeU/building-ai-infra
cd building-ai-infra/demo
make up      # ~10 minutes the first time
make demo    # opens Grafana, Alertmanager, Prometheus and MLflow
```

`make up` prints one line per block as it becomes ready:

```text
✓ kind cluster ready
✓ minio + postgres ready
✓ loki ready
✓ kube-prometheus-stack ready
✓ otel gateway + agent ready
✓ mlflow ready
✓ kserve ready
✓ sample-app + load-generator
✓ inference service ready
```

`make up` is safe to run again. It reuses the cluster and picks up where it stopped.

## Endpoints

| What | URL | Login |
|---|---|---|
| Grafana | http://localhost:3000 | admin / admin |
| Alertmanager | http://localhost:9093 | |
| Prometheus | http://localhost:9090 | |
| MLflow | http://localhost:5001 | |
| MinIO console | http://localhost:9001 | minioadmin / minioadmin |
| Loki | Grafana → Explore → Loki | |

## Tour: one stop per block

1. `make topology`: every block is just a group of pods.
2. **MLflow** (`make tab-mlflow`): the `doc-classifier` experiment and two registered versions.
3. `kubectl get inferenceservice -A`: the model being served, and whether it's Ready.
4. **Grafana** (`make tab-grafana`): cluster overview, API RED, model serving and model drift dashboards.
5. **Prometheus** (`make tab-prometheus`): the raw numbers and the alert rules behind the dashboards.

## Break it on purpose

| Command | What happens | Alert |
|---|---|---|
| `make scenario-slo-burn` | sample-app returns 500 for 50% of requests | `APIErrorBudgetBurnFast` in ~2 min |
| `make scenario-slo-burn-stop` | back to 0% errors | resolves in 1–2 min |
| `make scenario-drift` | input features drift away from training data, PSI rises | `FeatureDriftWarningFast` / `FeatureDriftCriticalFast` in ~1–3 min |
| `make scenario-drift-stop` | PSI back near 0 | resolves in ~1 min |
| `make scenario-rollback` | flips the InferenceService between model v1 and v2 | watch `kubectl -n mlops get pods -w` |

To watch alerts arrive at the "pager" (a small webhook viewer standing in for PagerDuty):

```bash
kubectl -n observability port-forward svc/alert-viewer 8080:8080   # then open http://localhost:8080
```

## Clean up

```bash
make down    # deletes the cluster; your laptop is back to normal
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| A step times out or pods sit in `Pending` | Docker needs more memory/CPU. Raise to 10 GB / 6 CPU, then `make up` again. |
| `ports ... already in use ... used by container <name>-control-plane` | Another kind cluster has the ports. Pause it: `docker stop $(docker ps -q --filter label=io.x-k8s.kind.cluster=<name>)`, or delete it: `kind delete cluster --name <name>`. |
| It seems stuck after a `→` line | It is downloading images. Leave it; `kubectl get pods -A` in another terminal shows progress. |
| `address already in use` on 3000, 5001, 9000, 9001, 9090, 9093, 4317 or 4318 | Find it with `lsof -nP -iTCP:<port> -sTCP:LISTEN`, stop it, or change `hostPort` in `kind/cluster.yaml`, then `make down && make up`. |
| `kubectl` talks to `localhost:8080` or the wrong cluster | `make kubeconfig` |
| Linux: OTel agent or other pods show `too many open files` | `sudo sysctl fs.inotify.max_user_watches=524288 fs.inotify.max_user_instances=512` |
| `inference service` step fails | `kubectl -n mlops describe isvc doc-classifier` and `kubectl -n kserve logs deploy/kserve-controller-manager` |
| A Helm chart's newest release breaks something | Pin it, e.g. `make up KPS_VERSION=65.1.1` (also `LOKI_VERSION`, `OTEL_VERSION`, `MLFLOW_VERSION`). |
| MLflow seeding was skipped | `make seed-mlflow` once MLflow is up. |

## Laptop vs. the real thing

| Stays the same everywhere | Changes in the cloud |
|---|---|
| Kubernetes APIs and kubectl | Real GPUs, in a pool that scales to 0 |
| Helm charts | S3 / Blob / GCS instead of MinIO |
| MLflow, KServe | Load balancers, private networks |
| Prometheus, Grafana, OpenTelemetry | Real identity, secrets and budgets |
