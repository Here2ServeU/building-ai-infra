# Part 2: The Foundation on Your Laptop

All 8 building blocks running locally, for free. This folder is the code for Part 2 of the **Building AI Infrastructure** series. Everything runs from here: `building-ai-infra/demo`.

Every tool you install here is the same tool used on AWS, Azure, Google Cloud and on-prem in Parts 3 to 6. Only the machines underneath change.

## The 8 blocks on a laptop

| # | Block | What plays the role locally | Where it lives in this folder |
|:-:|---|---|---|
| 1 | Compute | Your laptop's CPU (no GPU needed yet) | `kind/cluster.yaml` (1 control plane + 2 workers) |
| 2 | Data & storage | MinIO (S3-compatible) + Postgres | `bootstrap/01-minio.yaml`, `bootstrap/02-postgres.yaml` |
| 3 | Networking | kind's built-in network + port-forwards | `kind/cluster.yaml` (`extraPortMappings`) |
| 4 | Orchestration | kind: Kubernetes inside Docker | `kind/cluster.yaml` |
| 5 | MLOps | MLflow: tracking + model registry | `values/mlflow.yaml`, `scripts/seed-mlflow.sh` |
| 6 | Serving | KServe InferenceService | `apps/10-inference-service.yaml` |
| 7 | Observability | Prometheus, Grafana, Loki, OpenTelemetry | `values/`, `rules/`, `dashboards/` |
| 8 | Guardrails | Local only, admin/admin: practice, not production | `bootstrap/03-secrets.yaml` |

## What you need

- **Machine:** Docker Desktop with at least **6 CPUs and 10 GB RAM** for Docker (Settings → Resources). Mac, Windows (WSL2) or Linux.
- **Tools:** kind, kubectl, helm, jq, curl, git, docker compose v2.
- **Code:** this repo, [github.com/Here2ServeU/building-ai-infra](https://github.com/Here2ServeU/building-ai-infra). Everything runs from `demo/`.

Check:

```bash
kind version && kubectl version --client && helm version && docker compose version
```

(`make check` runs the same check, plus jq, curl and git.)

## One command brings it all up

```bash
git clone https://github.com/Here2ServeU/building-ai-infra
cd building-ai-infra/demo
make up      # about 5 minutes the first time
```

Watch the checklist. Each block reports ready:

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

Then:

```bash
make demo    # opens Grafana, Alertmanager, Prometheus, MLflow
```

If something fails, the most common cause is not enough memory for Docker. Raise it and run `make up` again.

## Tour: one stop per block

| # | Stop | How |
|:-:|---|---|
| 1 | Kubernetes | `kubectl get pods -A`: every block is a set of pods (or `make topology`) |
| 2 | MLflow | [localhost:5001](http://localhost:5001): runs, metrics, the model registry (`doc-classifier` v1 and v2) |
| 3 | KServe | `kubectl get inferenceservice -A`: the model being served |
| 4 | Grafana | [localhost:3000](http://localhost:3000) (admin / admin): dashboards for the app and the model |
| 5 | Prometheus | [localhost:9090](http://localhost:9090): raw metrics and the alert rules behind the dashboards |

Also available: Alertmanager at [localhost:9093](http://localhost:9093), MinIO console at [localhost:9001](http://localhost:9001) (minioadmin / minioadmin), and Loki logs in Grafana → Explore → Loki.

## Break it on purpose: an SLO burn

1. **Inject errors:** `make scenario-slo-burn`
2. **Errors rise:** 5xx responses climb in Grafana.
3. **Budget burns:** the SLO error budget drops fast.
4. **Alert fires:** the fast-burn alert fires in about 2 min.
5. **Recover:** `make scenario-slo-burn-stop`

You only trust an alert you have watched fire.

## Break the model: data drift

1. **Shift the data:** `make scenario-drift`
2. **Model sees new data:** inputs no longer look like training.
3. **PSI rises:** the drift score climbs on the model drift dashboard (`make tab-grafana-drift`).
4. **Alert fires:** in about 3 min.
5. **Respond:** retrain or roll back the model. Stop the drift with `make scenario-drift-stop`.

**Roll back:** `make scenario-rollback` moves the inference service back one version (v2 → v1). Run it again to roll forward.

## Laptop vs. the real thing

| Same everywhere | Changes in the cloud |
|---|---|
| Kubernetes APIs and kubectl | Real GPUs, in a pool that scales to 0 |
| Helm charts | S3 / Blob / GCS instead of MinIO |
| MLflow, KServe | Load balancers, private networks |
| Prometheus, Grafana, OTel | Real identity, secrets, budgets |

## Clean up

```bash
make down    # removes the cluster; your laptop is back to normal
```

## Folder map

```text
demo/
├── Makefile               make up / demo / scenario-* / down
├── kind/cluster.yaml      the cluster and its port mappings
├── bootstrap/             namespaces, MinIO, Postgres, local secrets
├── values/                Helm values: Loki, kube-prometheus-stack, OTel gateway + agent, MLflow
├── rules/                 Prometheus alert rules (SLO burn, platform, drift)
├── dashboards/            Grafana dashboards (cluster, API RED, model serving, model drift, log volume)
├── apps/                  sample app, load generator, alert viewer, drift simulator, InferenceService
├── scenarios/             fire-slo-burn.sh, fire-drift.sh, rollback-model.sh, show-topology.sh
└── scripts/               init-minio.sh, seed-mlflow.sh
```

## Troubleshooting

- **A step times out on first run.** Image pulls are slow the first time. Run `make up` again; every step is safe to repeat.
- **`kubectl` talks to `localhost:8080`.** Something rewrote your kubeconfig. Run `make kubeconfig`.
- **Pods stuck in `Pending`.** Docker is short on CPU or memory. Give it at least 6 CPUs and 10 GB.
- **Port already in use (3000, 5001, 9090, 9093, 9000, 9001).** Stop whatever is using it, then `make down && make up`. MLflow uses 5001 because macOS AirPlay takes 5000.
