#!/usr/bin/env bash
set -euo pipefail

# Create an MLflow experiment + run + registered model so the demo has something
# to point at. Uses kubectl exec into a Python pod so we don't need MLflow CLI on host.

echo "→ Seeding MLflow with doc-classifier model registration..."

kubectl -n mlops run mlflow-seed --rm -i --restart=Never \
  --image=python:3.12-slim \
  --env="MLFLOW_TRACKING_URI=http://mlflow.mlops.svc:5000" \
  --env="MLFLOW_S3_ENDPOINT_URL=http://minio.storage.svc:9000" \
  --env="AWS_ACCESS_KEY_ID=minioadmin" \
  --env="AWS_SECRET_ACCESS_KEY=minioadmin" \
  --env="AWS_DEFAULT_REGION=us-east-1" \
  --command -- sh -c '
    pip install --quiet mlflow boto3
    python <<EOF
import mlflow
from mlflow.tracking import MlflowClient

mlflow.set_experiment("doc-classifier")
with mlflow.start_run(run_name="initial-training") as run:
    mlflow.log_params({"max_depth": 8, "n_estimators": 200, "min_samples_split": 4})
    mlflow.log_metrics({"f1": 0.94, "precision": 0.93, "recall": 0.95, "accuracy": 0.94})
    mlflow.set_tag("trained_by", "demo-bootstrap")
    mlflow.set_tag("stage", "initial")
    run_id = run.info.run_id

client = MlflowClient()
try:
    client.create_registered_model("doc-classifier")
except Exception:
    pass

mv = client.create_model_version(
    name="doc-classifier",
    source=f"runs:/{run_id}/model",
    run_id=run_id,
)
client.transition_model_version_stage(
    name="doc-classifier",
    version=mv.version,
    stage="Production",
)
print(f"Registered doc-classifier v{mv.version} as Production")

# Second version so the rollback scenario has something to roll back to.
with mlflow.start_run(run_name="retrained") as run2:
    mlflow.log_params({"max_depth": 10, "n_estimators": 300, "min_samples_split": 4})
    mlflow.log_metrics({"f1": 0.95, "precision": 0.94, "recall": 0.96, "accuracy": 0.95})
    mlflow.set_tag("trained_by", "demo-bootstrap")
    run_id2 = run2.info.run_id

mv2 = client.create_model_version(
    name="doc-classifier",
    source=f"runs:/{run_id2}/model",
    run_id=run_id2,
)
client.transition_model_version_stage(
    name="doc-classifier",
    version=mv2.version,
    stage="Production",
    archive_existing_versions=False,
)
print(f"Registered doc-classifier v{mv2.version} as Production (current)")
EOF
  ' > /dev/null

echo "  doc-classifier v1 + v2 in MLflow registry."
