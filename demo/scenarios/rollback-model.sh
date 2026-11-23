#!/usr/bin/env bash
set -euo pipefail

# Demo rollback: flip MODEL_VERSION on the doc-classifier InferenceService and watch
# KServe roll the predictor. In production you would change storageUri to point at a
# previous MLflow registry version; the rollout mechanics are the same.

NS=mlops
ISVC=doc-classifier

CURRENT=$(kubectl -n "$NS" get inferenceservice "$ISVC" \
  -o jsonpath='{.spec.predictor.containers[0].env[?(@.name=="MODEL_VERSION")].value}')
echo "→ Current MODEL_VERSION on ${ISVC}: ${CURRENT}"

if [[ "${CURRENT}" == "v1" ]]; then TARGET="v2"; else TARGET="v1"; fi

# Find the env index for MODEL_VERSION so the JSON patch is exact.
IDX=$(kubectl -n "$NS" get inferenceservice "$ISVC" -o json \
  | jq '.spec.predictor.containers[0].env | map(.name) | index("MODEL_VERSION")')

echo "→ Rolling ${ISVC} to MODEL_VERSION=${TARGET}"
kubectl -n "$NS" patch inferenceservice "$ISVC" --type=json \
  -p "[{\"op\":\"replace\",\"path\":\"/spec/predictor/containers/0/env/${IDX}/value\",\"value\":\"${TARGET}\"}]"

echo "  watching rollout (~60-90s):"
sleep 3
kubectl -n "$NS" rollout status deployment/${ISVC}-predictor --timeout=180s
kubectl -n "$NS" wait --for=condition=Ready inferenceservice/${ISVC} --timeout=180s >/dev/null

echo
echo "✓ ${ISVC} is now serving version ${TARGET}."
echo "  Verify: kubectl -n ${NS} port-forward svc/${ISVC}-predictor 8080:80"
echo "          curl -s http://localhost:8080/v1/models/doc-classifier"
