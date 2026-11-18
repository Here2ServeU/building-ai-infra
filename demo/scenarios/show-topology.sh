#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'

┌──────────────────────────────────────────────────────────────────────────────┐
│                           kind cluster (ai-infra-laptop)                             │
├──────────────────────────────────────────────────────────────────────────────┤

namespace: storage
EOF
kubectl -n storage get pods -o wide --no-headers | awk '{printf "  %-30s %s\n", $1, $3}'

cat <<'EOF'

namespace: observability
EOF
kubectl -n observability get pods --no-headers | awk '{printf "  %-50s %s\n", $1, $3}'

cat <<'EOF'

namespace: mlops
EOF
kubectl -n mlops get pods --no-headers | awk '{printf "  %-50s %s\n", $1, $3}'

cat <<'EOF'

namespace: apps
EOF
kubectl -n apps get pods --no-headers | awk '{printf "  %-50s %s\n", $1, $3}'

cat <<'EOF'

namespace: kserve (controller)
EOF
kubectl -n kserve get pods --no-headers 2>/dev/null | awk '{printf "  %-50s %s\n", $1, $3}' || echo "  (not installed)"

cat <<'EOF'

inference services (KServe)
EOF
kubectl get inferenceservice -A --no-headers 2>/dev/null | awk '{printf "  %-20s %-30s ready=%s\n", $1, $2, $4}' || echo "  (none)"

cat <<'EOF'

──────────────────────────────────────────────────────────────────────────────
endpoints:
  Grafana       http://localhost:3000   admin / admin
  Alertmanager  http://localhost:9093
  Prometheus    http://localhost:9090
  MLflow        http://localhost:5001
  MinIO         http://localhost:9001   minioadmin / minioadmin

EOF
