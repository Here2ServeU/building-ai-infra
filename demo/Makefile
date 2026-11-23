SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

CLUSTER_NAME := obs-demo
KIND_CONFIG  := kind/cluster.yaml
CTX          := kind-$(CLUSTER_NAME)
HOST_PORTS   := 3000 4317 4318 5001 9000 9001 9090 9093

# Pinned so a fresh clone behaves the same next month as it does today.
CERT_MANAGER_VERSION ?= v1.16.2
KSERVE_VERSION       ?= v0.13.0

# Optional Helm chart pins. Empty = latest. Example: make up KPS_VERSION=65.1.1
KPS_VERSION    ?=
LOKI_VERSION   ?=
OTEL_VERSION   ?=
MLFLOW_VERSION ?=
ver = $(if $(1),--version $(1),)

# A release left "failed" or "pending" by an interrupted run blocks 'helm upgrade';
# remove it so the next install starts clean.
define helm_reset
	@st=$$(helm status $(1) -n $(2) -o json 2>/dev/null | jq -r '.info.status' 2>/dev/null || true); \
	if [ -n "$$st" ] && [ "$$st" != "deployed" ]; then \
		printf "  removing $(1) release left in state '$$st'\n"; helm uninstall $(1) -n $(2) --wait >/dev/null 2>&1 || true; \
	fi
endef

G := \033[1;32m
Y := \033[1;33m
R := \033[1;31m
N := \033[0m

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "Lifecycle:"
	@echo "  make up                    Bring the whole platform up (~10 min first run)"
	@echo "  make demo                  Open Grafana, Alertmanager, Prometheus and MLflow"
	@echo "  make status                Pods + endpoints"
	@echo "  make down                  Delete the kind cluster"
	@echo ""
	@echo "Tour:"
	@echo "  make topology              Pods grouped by namespace"
	@echo "  make tab-grafana | tab-grafana-drift | tab-alertmanager | tab-prometheus | tab-mlflow | tab-minio"
	@echo ""
	@echo "Break it on purpose:"
	@echo "  make scenario-slo-burn     Inject 5xx errors -> fast-burn alert (~2 min)"
	@echo "  make scenario-slo-burn-stop"
	@echo "  make scenario-drift        Push drifted features -> PSI alert (~1-3 min)"
	@echo "  make scenario-drift-stop"
	@echo "  make scenario-rollback     Roll the InferenceService to the other model version"

# ─── Lifecycle ─────────────────────────────────────────────────────────────────

.PHONY: up
up: preflight cluster bootstrap helm-repos loki prometheus-stack otel mlflow kserve apps inference load-dashboards seed-mlflow
	@printf "\n$(G)Platform is up.$(N) Next: $(Y)make demo$(N)   (or make status for endpoints)\n\n"

.PHONY: preflight
preflight:
	@missing=""; for t in docker kind kubectl helm jq curl; do \
		command -v $$t >/dev/null 2>&1 || missing="$$missing $$t"; \
	done; \
	if [ -n "$$missing" ]; then \
		printf "$(R)✗ missing tools:$$missing$(N)  (install them with 'make install-tools' from the repo root)\n"; exit 1; \
	fi
	@docker info >/dev/null 2>&1 || { printf "$(R)✗ Docker is not running. Start Docker Desktop and retry.$(N)\n"; exit 1; }
	@if ! kind get clusters 2>/dev/null | grep -qx "$(CLUSTER_NAME)"; then \
		busy=""; for p in $(HOST_PORTS); do \
			who=$$(docker ps --format '{{.Names}} {{.Ports}}' | grep -E "[:.]$$p->" | awk '{print "container " $$1}' | head -1 || true); \
			if [ -z "$$who" ] && command -v lsof >/dev/null; then \
				who=$$(lsof -nP -iTCP:$$p -sTCP:LISTEN 2>/dev/null | awk 'NR==2{print "process " $$1 " (pid " $$2 ")"}' || true); \
			fi; \
			if [ -n "$$who" ]; then busy="$$busy\n  port $$p is used by $$who"; fi; \
		done; \
		if [ -n "$$busy" ]; then \
			printf "$(R)✗ These ports are needed by the demo but already in use:$$busy$(N)\n"; \
			printf "  Stop them (e.g. 'docker stop <name>' or 'kind delete cluster --name <name>') and run 'make up' again.\n"; \
			exit 1; \
		fi; \
	fi
	@mem=$$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0); \
	if [ "$$mem" -lt 8000000000 ]; then \
		printf "$(Y)⚠  Docker has $$((mem/1024/1024/1024)) GB memory. 10 GB+ is recommended (Docker settings → Resources).$(N)\n"; \
	fi

.PHONY: cluster
cluster:
	@printf "$(Y)→ creating the kind cluster (3 nodes)...$(N)\n"
	@if kind get clusters 2>/dev/null | grep -qx "$(CLUSTER_NAME)"; then \
		echo "  cluster $(CLUSTER_NAME) already exists, reusing"; \
	else \
		kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG) --wait 120s; \
	fi
	@$(MAKE) -s kubeconfig
	@kubectl wait --for=condition=Ready nodes --all --timeout=180s >/dev/null
	@printf "$(G)✓ kind cluster ready$(N)\n"

# Restore the kind context if something rewrote ~/.kube/config.
.PHONY: kubeconfig
kubeconfig:
	@kind get clusters 2>/dev/null | grep -qx "$(CLUSTER_NAME)" || { \
		printf "$(R)✗ kind cluster '$(CLUSTER_NAME)' is not running. Run 'make up'.$(N)\n"; exit 1; }
	@kind export kubeconfig --name $(CLUSTER_NAME) >/dev/null 2>&1
	@kubectl config use-context $(CTX) >/dev/null

.PHONY: bootstrap
bootstrap:
	@printf "$(Y)→ starting MinIO + Postgres (first run downloads images, 2-5 min)...$(N)\n"
	@kubectl apply -f bootstrap/ >/dev/null
	@# A StatefulSet pod stuck on an old, unpullable image is not replaced on its own.
	@if kubectl -n storage get pod minio-0 -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null \
		| grep -qE 'ImagePullBackOff|ErrImagePull'; then kubectl -n storage delete pod minio-0 --wait=false >/dev/null; fi
	@kubectl -n storage rollout status statefulset/minio --timeout=300s >/dev/null
	@kubectl -n storage rollout status statefulset/postgres --timeout=300s >/dev/null
	@./scripts/init-minio.sh >/dev/null
	@printf "$(G)✓ minio + postgres ready$(N)\n"

.PHONY: helm-repos
helm-repos:
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update >/dev/null
	@helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts --force-update >/dev/null
	@helm repo add community-charts https://community-charts.github.io/helm-charts --force-update >/dev/null
	@helm repo add grafana https://grafana.github.io/helm-charts --force-update >/dev/null
	@helm repo update >/dev/null

.PHONY: loki
loki:
	@printf "$(Y)→ installing Loki (logs)...$(N)\n"
	$(call helm_reset,loki,observability)
	@helm upgrade --install loki grafana/loki $(call ver,$(LOKI_VERSION)) \
		--namespace observability --values values/loki.yaml --timeout 10m >/dev/null
	@kubectl -n observability rollout status statefulset/loki --timeout=10m >/dev/null
	@printf "$(G)✓ loki ready$(N)\n"

.PHONY: prometheus-stack
prometheus-stack:
	@printf "$(Y)→ installing Prometheus, Grafana, Alertmanager (largest step, 3-8 min)...$(N)\n"
	$(call helm_reset,kube-prometheus-stack,observability)
	@helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack $(call ver,$(KPS_VERSION)) \
		--namespace observability --values values/kube-prometheus-stack.yaml --wait --timeout 15m >/dev/null
	@kubectl apply -f rules/ >/dev/null
	@printf "$(G)✓ kube-prometheus-stack ready$(N)\n"

.PHONY: otel
otel:
	@printf "$(Y)→ installing OpenTelemetry gateway + agent (~300 MB image)...$(N)\n"
	$(call helm_reset,otel-collector-gateway,observability)
	@helm upgrade --install otel-collector-gateway open-telemetry/opentelemetry-collector $(call ver,$(OTEL_VERSION)) \
		--namespace observability --values values/otel-gateway.yaml --timeout 10m >/dev/null
	$(call helm_reset,otel-agent,observability)
	@helm upgrade --install otel-agent open-telemetry/opentelemetry-collector $(call ver,$(OTEL_VERSION)) \
		--namespace observability --values values/otel-agent.yaml --timeout 10m >/dev/null
	@kubectl -n observability rollout status deploy/otel-collector-gateway-opentelemetry-collector --timeout=10m >/dev/null
	@kubectl -n observability rollout status daemonset/otel-agent-opentelemetry-collector-agent --timeout=10m >/dev/null
	@printf "$(G)✓ otel gateway + agent ready$(N)\n"

.PHONY: mlflow
mlflow:
	@printf "$(Y)→ installing MLflow...$(N)\n"
	$(call helm_reset,mlflow,mlops)
	@helm upgrade --install mlflow community-charts/mlflow $(call ver,$(MLFLOW_VERSION)) \
		--namespace mlops --values values/mlflow.yaml --timeout 10m >/dev/null
	@# Pin the NodePort so http://localhost:5001 always works, whatever the chart defaults to.
	@kubectl -n mlops patch svc mlflow --type=json \
		-p '[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"add","path":"/spec/ports/0/nodePort","value":30500}]' >/dev/null
	@kubectl -n mlops rollout status deploy/mlflow --timeout=10m >/dev/null
	@printf "$(G)✓ mlflow ready$(N)\n"

# KServe needs cert-manager for its webhook certificates. We run it in
# RawDeployment mode (plain Deployments + Services) so Knative and Istio are not needed.
.PHONY: kserve
kserve: cert-manager
	@printf "$(Y)→ installing KServe (RawDeployment mode)...$(N)\n"
	@for i in $$(seq 1 20); do \
		kubectl apply --server-side --force-conflicts \
			-f https://github.com/kserve/kserve/releases/download/$(KSERVE_VERSION)/kserve.yaml >/dev/null 2>&1 && break; \
		[ $$i -eq 20 ] && { printf "$(R)✗ could not apply kserve.yaml$(N)\n"; exit 1; }; sleep 6; \
	done
	@kubectl -n kserve get cm inferenceservice-config -o json \
		| jq '.data.deploy  |= (fromjson | .defaultDeploymentMode = "RawDeployment" | tojson) \
		    | .data.ingress |= (fromjson | .disableIngressCreation = true | tojson)' \
		| kubectl apply -f - >/dev/null
	@kubectl -n kserve rollout restart deploy/kserve-controller-manager >/dev/null
	@kubectl -n kserve rollout status deploy/kserve-controller-manager --timeout=5m >/dev/null
	@printf "$(G)✓ kserve ready$(N)\n"

.PHONY: cert-manager
cert-manager:
	@printf "$(Y)→ installing cert-manager (needed by KServe)...$(N)\n"
	@kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/$(CERT_MANAGER_VERSION)/cert-manager.yaml >/dev/null
	@kubectl -n cert-manager wait --for=condition=Available deploy --all --timeout=5m >/dev/null

.PHONY: apps
apps:
	@printf "$(Y)→ starting sample-app, load generator, drift simulator...$(N)\n"
	@kubectl apply -f apps/00-sample-app.yaml -f apps/01-load-generator.yaml \
		-f apps/02-alert-viewer.yaml -f apps/11-drift-simulator.yaml -f apps/12-demo-overrides.yaml >/dev/null
	@kubectl -n apps rollout status deploy/sample-app --timeout=5m >/dev/null
	@kubectl -n apps rollout status deploy/load-generator --timeout=3m >/dev/null
	@kubectl -n mlops rollout status deploy/drift-simulator --timeout=3m >/dev/null
	@printf "$(G)✓ sample-app + load-generator$(N)\n"

# The KServe webhook can take a few seconds to accept requests after the controller restarts.
.PHONY: inference
inference:
	@printf "$(Y)→ deploying the doc-classifier InferenceService...$(N)\n"
	@for i in $$(seq 1 20); do \
		kubectl apply -f apps/10-inference-service.yaml >/dev/null 2>&1 && break; \
		[ $$i -eq 20 ] && { kubectl apply -f apps/10-inference-service.yaml; exit 1; }; sleep 6; \
	done
	@kubectl -n mlops wait --for=condition=Ready inferenceservice/doc-classifier --timeout=10m >/dev/null || { \
		printf "$(R)✗ doc-classifier not Ready. Check: kubectl -n mlops describe isvc doc-classifier$(N)\n"; exit 1; }
	@printf "$(G)✓ inference service ready$(N)\n"

.PHONY: load-dashboards
load-dashboards:
	@printf "$(Y)→ loading Grafana dashboards...$(N)\n"
	@for f in dashboards/*.json; do \
		name=$$(basename $$f .json); \
		kubectl -n observability create configmap "grafana-$$name" --from-file="$$f" \
			--dry-run=client -o yaml \
		| kubectl label --local -f - grafana_dashboard=1 -o yaml \
		| kubectl apply -f - >/dev/null; \
	done

# Nice to have, not required: a failure here warns instead of stopping 'make up'.
.PHONY: seed-mlflow
seed-mlflow:
	@printf "$(Y)→ registering demo models in MLflow (~1 min)...$(N)\n"
	@./scripts/seed-mlflow.sh >/dev/null 2>&1 \
		|| printf "$(Y)⚠  MLflow seeding skipped (retry later with: make seed-mlflow)$(N)\n"

.PHONY: status
status: kubeconfig
	@printf "\n$(Y)Pods:$(N)\n"
	@kubectl get pods -A --no-headers | awk '{printf "  %-16s %-55s %s\n", $$1, $$2, $$4}'
	@printf "\n$(G)Endpoints:$(N)\n"
	@printf "  Grafana       http://localhost:3000   admin / admin\n"
	@printf "  Alertmanager  http://localhost:9093\n"
	@printf "  Prometheus    http://localhost:9090\n"
	@printf "  MLflow        http://localhost:5001\n"
	@printf "  MinIO         http://localhost:9001   minioadmin / minioadmin\n"
	@printf "  Loki          Grafana → Explore → Loki\n\n"

.PHONY: down
down:
	-@kind delete cluster --name $(CLUSTER_NAME)
	@printf "$(G)✓ down$(N)\n"

.PHONY: clean
clean: down

# ─── Scenarios ─────────────────────────────────────────────────────────────────

.PHONY: scenario-slo-burn scenario-slo-burn-stop scenario-drift scenario-drift-stop scenario-rollback topology
scenario-slo-burn: kubeconfig ; @./scenarios/fire-slo-burn.sh start
scenario-slo-burn-stop: kubeconfig ; @./scenarios/fire-slo-burn.sh stop
scenario-drift: kubeconfig ; @./scenarios/fire-drift.sh start
scenario-drift-stop: kubeconfig ; @./scenarios/fire-drift.sh stop
scenario-rollback: kubeconfig ; @./scenarios/rollback-model.sh
topology: kubeconfig ; @./scenarios/show-topology.sh

# ─── Tabs ──────────────────────────────────────────────────────────────────────

.PHONY: ready-check
ready-check:
	@kind get clusters 2>/dev/null | grep -qx "$(CLUSTER_NAME)" || { \
		printf "$(R)✗ The demo cluster is not running, so there is nothing to open. Run 'make up' first.$(N)\n"; exit 1; }
	@curl -fs -o /dev/null --max-time 5 http://localhost:3000/api/health || { \
		printf "$(R)✗ Grafana is not answering on localhost:3000 yet. Check 'make status', or re-run 'make up'.$(N)\n"; exit 1; }

.PHONY: demo tab-grafana tab-grafana-drift tab-alertmanager tab-prometheus tab-mlflow tab-minio
OPEN := $(shell command -v open || command -v xdg-open || command -v wslview || echo echo)

demo: ready-check tab-grafana tab-alertmanager tab-prometheus tab-mlflow
	@printf "\n$(G)Opened:$(N)\n"
	@printf "  Grafana       http://localhost:3000/d/k8s-cluster-overview   admin / admin\n"
	@printf "  Alertmanager  http://localhost:9093\n"
	@printf "  Prometheus    http://localhost:9090/alerts\n"
	@printf "  MLflow        http://localhost:5001\n\n"
	@printf "Try: make scenario-slo-burn   make scenario-drift   make scenario-rollback\n\n"

tab-grafana:       ; @$(OPEN) http://localhost:3000/d/k8s-cluster-overview >/dev/null 2>&1 || true
tab-grafana-drift: ; @$(OPEN) http://localhost:3000/d/model-drift >/dev/null 2>&1 || true
tab-alertmanager:  ; @$(OPEN) http://localhost:9093 >/dev/null 2>&1 || true
tab-prometheus:    ; @$(OPEN) http://localhost:9090/alerts >/dev/null 2>&1 || true
tab-mlflow:        ; @$(OPEN) http://localhost:5001 >/dev/null 2>&1 || true
tab-minio:         ; @$(OPEN) http://localhost:9001 >/dev/null 2>&1 || true
