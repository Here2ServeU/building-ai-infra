#!/usr/bin/env bash
set -euo pipefail

# Register doc-classifier v1 + v2 in MLflow so the demo has a model registry to show.
# Runs inside the cluster, so no MLflow CLI is needed on your laptop. Safe to re-run.

kubectl -n mlops delete pod mlflow-seed --ignore-not-found >/dev/null

kubectl -n mlops run mlflow-seed --rm -i --restart=Never --quiet \
  --image=python:3.12-slim \
  --env="MLFLOW_TRACKING_URI=http://mlflow.mlops.svc:5000" \
  --env="MLFLOW_S3_ENDPOINT_URL=http://minio.storage.svc:9000" \
  --env="AWS_ACCESS_KEY_ID=minioadmin" \
  --env="AWS_SECRET_ACCESS_KEY=minioadmin" \
  --env="AWS_DEFAULT_REGION=us-east-1" \
  --command -- sh -c '
pip install --quiet --no-cache-dir mlflow-skinny boto3 >/dev/null 2>&1
python - <<EOF
import mlflow
from mlflow.tracking import MlflowClient

client = MlflowClient()
try:
    if client.search_model_versions("name=\"doc-classifier\""):
        print("doc-classifier already registered; nothing to do")
        raise SystemExit(0)
except mlflow.exceptions.MlflowException:
    pass

mlflow.set_experiment("doc-classifier")
try:
    client.create_registered_model("doc-classifier")
except Exception:
    pass

runs = [
    ("initial-training", {"max_depth": 8,  "n_estimators": 200}, {"f1": 0.94, "precision": 0.93, "recall": 0.95, "accuracy": 0.94}),
    ("retrained",        {"max_depth": 10, "n_estimators": 300}, {"f1": 0.95, "precision": 0.94, "recall": 0.96, "accuracy": 0.95}),
]
for name, params, metrics in runs:
    with mlflow.start_run(run_name=name) as run:
        mlflow.log_params(params)
        mlflow.log_metrics(metrics)
        mlflow.set_tag("trained_by", "demo-bootstrap")
    mv = client.create_model_version("doc-classifier", f"runs:/{run.info.run_id}/model", run.info.run_id)
    try:
        client.set_registered_model_alias("doc-classifier", "production", mv.version)
    except Exception:
        pass
    print(f"registered doc-classifier v{mv.version}")
EOF
'
