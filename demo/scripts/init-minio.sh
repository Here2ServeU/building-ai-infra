#!/usr/bin/env bash
set -euo pipefail

# Create the buckets the platform expects: log archive (with versioning to simulate
# object-lock locally) and mlflow artifacts.
echo "→ Creating MinIO buckets..."

kubectl -n storage exec statefulset/minio -- sh -c '
  mc alias set local http://localhost:9000 minioadmin minioadmin > /dev/null 2>&1 || true
  mc mb -p local/log-archive 2>/dev/null || true
  mc mb -p local/mlflow-artifacts 2>/dev/null || true
  mc version enable local/mlflow-artifacts 2>/dev/null || true
  mc ls local
'
