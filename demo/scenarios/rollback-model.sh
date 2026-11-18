#!/usr/bin/env bash
set -euo pipefail

# Roll the doc-classifier InferenceService back one version.
# MLflow holds v1 and v2 (v2 is current). Rolling back = pointing the
# InferenceService at the previous version, then letting KServe roll the pods.
# Run it again to roll forward to v2.

NS=mlops
ISVC=doc-classifier

CURRENT=$(kubectl -n "$NS" get inferenceservice "$ISVC" \
  -o jsonpath='{.spec.predictor.containers[0].env[?(@.name=="MODEL_VERSION")].value}')
echo "→ ${ISVC} is serving ${CURRENT}"

if [[ "${CURRENT}" == "v2" ]]; then
  TARGET="v1"; WHAT="Rolling back"
else
  TARGET="v2"; WHAT="Rolling forward"
fi

echo "→ ${WHAT} to ${TARGET}"
IDX=$(kubectl -n "$NS" get inferenceservice "$ISVC" -o json \
  | jq '[.spec.predictor.containers[0].env[].name] | index("MODEL_VERSION")')
kubectl -n "$NS" patch inferenceservice "$ISVC" --type=json \
  -p "[{\"op\":\"replace\",\"path\":\"/spec/predictor/containers/0/env/${IDX}/value\",\"value\":\"${TARGET}\"}]"

echo "  waiting for KServe to roll the predictor (about 60-90s):"
sleep 5
kubectl -n "$NS" rollout status deployment/"${ISVC}"-predictor --timeout=180s
kubectl -n "$NS" wait inferenceservice/"$ISVC" --for=condition=Ready --timeout=180s > /dev/null

echo
kubectl get inferenceservice -n "$NS" "$ISVC"
echo
echo "✓ ${ISVC} is now serving ${TARGET}."
echo "  Verify: kubectl -n ${NS} port-forward svc/${ISVC}-predictor 8080:80"
echo "          curl -s http://localhost:8080/v1/models/${ISVC}"
