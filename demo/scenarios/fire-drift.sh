#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-start}"

case "$ACTION" in
  start)
    LEVEL="${2:-crit}"   # warn or crit
    echo "→ Setting drift-simulator DRIFT_MODE=${LEVEL}"
    kubectl -n mlops set env deployment/drift-simulator DRIFT_MODE="${LEVEL}"
    kubectl -n mlops rollout status deployment/drift-simulator --timeout=60s
    cat <<EOF

✓ Drift injection active (DRIFT_MODE=${LEVEL}).
  The model now sees data that no longer looks like its training data.
  The PSI drift score rises on the model drift dashboard and the drift alert
  fires in about 3 min.

  Watch:
    open  http://localhost:3000/d/model-drift/model-drift-training-health
    open  http://localhost:9093

  Respond: retrain, or roll back the model:
    make scenario-rollback

  Stop:
    make scenario-drift-stop
EOF
    ;;
  stop)
    echo "→ Recovering drift-simulator (DRIFT_MODE=none)"
    kubectl -n mlops set env deployment/drift-simulator DRIFT_MODE=none
    kubectl -n mlops rollout status deployment/drift-simulator --timeout=60s
    echo "✓ Recovered. Drift alerts will resolve in ~1 min."
    ;;
  *)
    echo "usage: $0 [start [warn|crit]|stop]" >&2
    exit 2
    ;;
esac
