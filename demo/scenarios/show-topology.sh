#!/usr/bin/env bash
set -euo pipefail

# One block per namespace: every building block is just a group of pods.
section() {
  printf '\nnamespace: %s  (%s)\n' "$1" "$2"
  kubectl -n "$1" get pods --no-headers 2>/dev/null \
    | awk '{printf "  %-55s %s\n", $1, $3}' || true
}

printf '\nkind cluster: obs-demo\n'
section storage       "MinIO = S3 stand-in, Postgres = MLflow backend"
section observability "Prometheus, Grafana, Alertmanager, Loki, OpenTelemetry"
section mlops         "MLflow, KServe InferenceService, drift simulator"
section apps          "sample app + load generator"
section kserve        "KServe controller"
section cert-manager  "certificates for KServe webhooks"

printf '\nInferenceServices:\n'
kubectl get inferenceservice -A 2>/dev/null | sed 's/^/  /' || echo "  (KServe not installed)"

cat <<'TXT'

Endpoints:
  Grafana       http://localhost:3000   admin / admin
  Alertmanager  http://localhost:9093
  Prometheus    http://localhost:9090
  MLflow        http://localhost:5001
  MinIO         http://localhost:9001   minioadmin / minioadmin

TXT
