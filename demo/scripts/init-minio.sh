#!/usr/bin/env bash
set -euo pipefail

# Create the buckets the platform expects: log-archive, and mlflow-artifacts with
# versioning (stands in for object-lock locally). The MinIO image has no shell or
# mc, so this runs as a one-off Job using the MinIO client image. Safe to re-run.

kubectl -n storage delete job minio-init --ignore-not-found >/dev/null

kubectl apply -f - >/dev/null <<'YAML'
apiVersion: batch/v1
kind: Job
metadata:
  name: minio-init
  namespace: storage
spec:
  backoffLimit: 6
  ttlSecondsAfterFinished: 600
  template:
    spec:
      restartPolicy: OnFailure
      initContainers:
        - name: log-archive
          image: cgr.dev/chainguard/minio-client:latest
          args: ["mb", "--ignore-existing", "local/log-archive"]
          env: &mc
            - name: MC_HOST_local
              value: http://minioadmin:minioadmin@minio.storage.svc:9000
            - name: MC_CONFIG_DIR
              value: /tmp/mc
        - name: mlflow-artifacts
          image: cgr.dev/chainguard/minio-client:latest
          args: ["mb", "--ignore-existing", "local/mlflow-artifacts"]
          env: *mc
      containers:
        - name: versioning
          image: cgr.dev/chainguard/minio-client:latest
          args: ["version", "enable", "local/mlflow-artifacts"]
          env: *mc
YAML

kubectl -n storage wait --for=condition=complete job/minio-init --timeout=300s >/dev/null
echo "buckets ready: log-archive, mlflow-artifacts"
