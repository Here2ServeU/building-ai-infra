#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-start}"

case "$ACTION" in
  start)
    echo "→ Setting sample-app ERROR_RATE_PCT=50 (will fire APIErrorBudgetBurnFast in ~2-3 min)"
    kubectl -n apps set env deployment/sample-app ERROR_RATE_PCT=50
    kubectl -n apps rollout status deployment/sample-app --timeout=60s
    cat <<EOF

✓ Error injection active.
  Watch the alert fire:
    open  http://localhost:9090/alerts            # Prometheus rule view
    open  http://localhost:9093                   # Alertmanager
  Watch the live alert viewer (webhook receivers):
    kubectl -n observability port-forward svc/alert-viewer 8080:8080
    open  http://localhost:8080

  Stop the injection:
    make scenario-slo-burn-stop
EOF
    ;;
  stop)
    echo "→ Recovering sample-app (ERROR_RATE_PCT=0)"
    kubectl -n apps set env deployment/sample-app ERROR_RATE_PCT=0
    kubectl -n apps rollout status deployment/sample-app --timeout=60s
    echo "✓ Recovered. Alert will resolve in 1–2 min."
    ;;
  *)
    echo "usage: $0 [start|stop]" >&2
    exit 2
    ;;
esac
