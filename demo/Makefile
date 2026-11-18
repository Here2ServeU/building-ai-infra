SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:

# Part 2: The Foundation on Your Laptop.
# All 8 building blocks on kind, for free. Run everything from this folder:
#   make up  →  make demo  →  make scenario-slo-burn / scenario-drift  →  make down

CLUSTER_NAME := ai-infra-laptop
KIND_CONFIG  := kind/cluster.yaml

CERT_MANAGER_VERSION := v1.15.3
KSERVE_VERSION       := v0.13.0

# ANSI colors
G := \033[1;32m
Y := \033[1;33m
R := \033[1;31m
N := \033[0m

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "Part 2: The Foundation on Your Laptop"
	@echo ""
	@echo "Lifecycle:"
	@echo "  make check                 Check your tools (kind, kubectl, helm, docker compose, jq, curl, git)"
	@echo "  make up                    Bring all 8 blocks up (about 5 min the first time)"
	@echo "  make status                Show pods and endpoints"
	@echo "  make down                  Delete the cluster. Your laptop is back to normal"
	@echo ""
	@echo "Tour:"
	@echo "  make demo                  Open Grafana, Alertmanager, Prometheus and MLflow"
	@echo "  make topology              Every block as a group of pods"
	@echo "  make tab-grafana-drift     Open the model drift dashboard"
	@echo ""
	@echo "Break it on purpose:"
	@echo "  make scenario-slo-burn        Inject 5xx errors → fast-burn alert in about 2 min"
	@echo "  make scenario-slo-burn-stop   Recover"
	@echo "  make scenario-drift           Push drifted data → PSI drift alert in about 3 min"
	@echo "  make scenario-drift-stop      Recover"
	@echo "  make scenario-rollback        Move the inference service back one version"

.PHONY: check
check:
	@kind version && kubectl version --client && helm version && docker compose version
	@for t in jq curl git; do command -v $$t > /dev/null && echo "$$t: ok" || { printf "$(R)✗ $$t is missing$(N)\n"; exit 1; }; done
	@printf "$(G)✓ tools ready$(N)\n"

.PHONY: up
up: cluster bootstrap helm-repos loki prometheus-stack otel mlflow kserve apps inference-service status

.PHONY: cluster
cluster:
	@printf "$(Y)→ Creating kind cluster $(CLUSTER_NAME)...$(N)\n"
	@if kind get clusters | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "  cluster already exists, reusing"; \
	else \
		kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG); \
	fi
	@$(MAKE) -s kubeconfig
	@kubectl cluster-info --context kind-$(CLUSTER_NAME) > /dev/null
	@printf "$(G)✓ kind cluster ready$(N)\n"

# Restore the kind context. Run this if kubectl complains about localhost:8080.
.PHONY: kubeconfig
kubeconfig:
	@if ! kind get clusters | grep -q "^$(CLUSTER_NAME)$$"; then \
		printf "$(R)✗ kind cluster '$(CLUSTER_NAME)' is not running. Run 'make up'.$(N)\n"; \
		exit 1; \
	fi
	@kind export kubeconfig --name $(CLUSTER_NAME) > /dev/null
	@kubectl config use-context kind-$(CLUSTER_NAME) > /dev/null

.PHONY: bootstrap
bootstrap:
	@printf "$(Y)→ Applying bootstrap manifests (namespaces, MinIO, Postgres)...$(N)\n"
	@kubectl apply -f bootstrap/00-namespaces.yaml
	@kubectl apply -f bootstrap/01-minio.yaml
	@kubectl apply -f bootstrap/02-postgres.yaml
	@kubectl apply -f bootstrap/03-secrets.yaml
	@kubectl -n storage rollout status statefulset/minio --timeout=180s
	@kubectl -n storage rollout status statefulset/postgres --timeout=180s
	@./scripts/init-minio.sh
	@printf "$(G)✓ minio + postgres ready$(N)\n"

.PHONY: helm-repos
helm-repos:
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null 2>&1 || true
	@helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts > /dev/null 2>&1 || true
	@helm repo add community-charts https://community-charts.github.io/helm-charts > /dev/null 2>&1 || true
	@helm repo add grafana https://grafana.github.io/helm-charts > /dev/null 2>&1 || true
	@helm repo update > /dev/null

.PHONY: loki
loki:
	@printf "$(Y)→ Installing Loki (logs)...$(N)\n"
	@helm upgrade --install loki grafana/loki \
		--namespace observability \
		--values values/loki.yaml \
		--timeout 5m
	@kubectl -n observability rollout status statefulset/loki --timeout=5m
	@printf "$(G)✓ loki ready$(N)\n"

.PHONY: prometheus-stack
prometheus-stack:
	@printf "$(Y)→ Installing kube-prometheus-stack (Prometheus, Alertmanager, Grafana)...$(N)\n"
	@helm upgrade --install kube-prometheus-stack \
		prometheus-community/kube-prometheus-stack \
		--namespace observability \
		--values values/kube-prometheus-stack.yaml \
		--timeout 15m
	@kubectl apply -f rules/
	@$(MAKE) -s load-dashboards
	@printf "$(G)✓ kube-prometheus-stack ready$(N)\n"

.PHONY: load-dashboards
load-dashboards:
	@for f in dashboards/*.json; do \
		name=$$(basename $$f .json); \
		kubectl create configmap "grafana-$$name" \
			--from-file="$$(basename $$f)=$$f" \
			-n observability \
			--dry-run=client -o yaml | \
		kubectl label --local -f - grafana_dashboard=1 -o yaml | \
		kubectl apply -f - > /dev/null; \
	done
	@echo "  dashboards loaded"

.PHONY: otel
otel:
	@printf "$(Y)→ Installing OpenTelemetry gateway + agent (first image pull can take a few minutes)...$(N)\n"
	@helm upgrade --install otel-collector-gateway \
		open-telemetry/opentelemetry-collector \
		--namespace observability \
		--values values/otel-gateway.yaml \
		--timeout 10m
	@helm upgrade --install otel-agent \
		open-telemetry/opentelemetry-collector \
		--namespace observability \
		--values values/otel-agent.yaml \
		--timeout 10m
	@kubectl -n observability rollout status deploy/otel-collector-gateway-opentelemetry-collector --timeout=10m
	@kubectl -n observability rollout status daemonset/otel-agent-opentelemetry-collector-agent --timeout=10m
	@printf "$(G)✓ otel gateway + agent ready$(N)\n"

.PHONY: mlflow
mlflow:
	@printf "$(Y)→ Installing MLflow (tracking + model registry, backed by MinIO and Postgres)...$(N)\n"
	@helm upgrade --install mlflow community-charts/mlflow \
		--namespace mlops \
		--values values/mlflow.yaml \
		--timeout 5m
	@kubectl -n mlops rollout status deploy/mlflow --timeout=10m
	@./scripts/seed-mlflow.sh
	@printf "$(G)✓ mlflow ready$(N)\n"

# KServe needs cert-manager for its webhook certificates.
.PHONY: kserve
kserve:
	@printf "$(Y)→ Installing KServe $(KSERVE_VERSION) (RawDeployment mode, with cert-manager)...$(N)\n"
	@kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/$(CERT_MANAGER_VERSION)/cert-manager.yaml > /dev/null
	@kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=180s
	@kubectl apply --server-side -f https://github.com/kserve/kserve/releases/download/$(KSERVE_VERSION)/kserve.yaml > /dev/null
	@kubectl -n kserve rollout status deploy/kserve-controller-manager --timeout=300s
	@kubectl apply --server-side -f https://github.com/kserve/kserve/releases/download/$(KSERVE_VERSION)/kserve-cluster-resources.yaml > /dev/null
	@printf "$(G)✓ kserve ready$(N)\n"

.PHONY: apps
apps:
	@printf "$(Y)→ Deploying sample app, load generator, drift simulator, alert viewer...$(N)\n"
	@kubectl apply -f apps/00-sample-app.yaml -f apps/01-load-generator.yaml -f apps/02-alert-viewer.yaml -f apps/11-drift-simulator.yaml -f apps/12-demo-overrides.yaml
	@kubectl -n apps rollout status deploy/sample-app --timeout=120s
	@kubectl -n apps rollout status deploy/load-generator --timeout=60s
	@kubectl -n mlops rollout status deploy/drift-simulator --timeout=60s
	@printf "$(G)✓ sample-app + load-generator$(N)\n"

.PHONY: inference-service
inference-service:
	@printf "$(Y)→ Serving doc-classifier with a KServe InferenceService...$(N)\n"
	@kubectl apply -f apps/10-inference-service.yaml
	@kubectl -n mlops wait inferenceservice/doc-classifier --for=condition=Ready --timeout=300s > /dev/null
	@printf "$(G)✓ inference service ready$(N)\n"

.PHONY: status
status:
	@if ! kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		printf "$(R)✗ kind cluster '$(CLUSTER_NAME)' is not running. Run 'make up'.$(N)\n"; exit 1; \
	fi
	@$(MAKE) -s kubeconfig
	@printf "\n$(Y)Cluster pods:$(N)\n"
	@kubectl get pods -A --no-headers 2>/dev/null | awk '{printf "  %-20s %-50s %s\n", $$1, $$2, $$4}'
	@NOT_READY=$$(kubectl get pods -A --no-headers 2>/dev/null | awk '$$4 != "Running" && $$4 != "Completed" {c++} END {print c+0}'); \
	if [ "$$NOT_READY" -gt 0 ]; then \
		printf "\n$(Y)⚠  $$NOT_READY pod(s) not yet Running.$(N)\n"; \
	else \
		printf "\n$(G)✓ All pods Running.$(N)\n"; \
	fi
	@printf "\n$(G)Endpoints:$(N)\n"
	@printf "  Grafana       http://localhost:3000   admin / admin\n"
	@printf "  Alertmanager  http://localhost:9093\n"
	@printf "  Prometheus    http://localhost:9090\n"
	@printf "  MLflow        http://localhost:5001\n"
	@printf "  MinIO         http://localhost:9001   minioadmin / minioadmin\n"
	@printf "  Loki          in-cluster: Grafana → Explore → Loki\n\n"
	@printf "Next: make demo\n\n"

.PHONY: down
down:
	@printf "$(Y)→ Deleting the kind cluster...$(N)\n"
	-@kind delete cluster --name $(CLUSTER_NAME)
	@printf "$(G)✓ down. Your laptop is back to normal.$(N)\n"

# ─── Break it on purpose ───────────────────────────────────────────────────────

.PHONY: scenario-slo-burn
scenario-slo-burn: kubeconfig
	@./scenarios/fire-slo-burn.sh start

.PHONY: scenario-slo-burn-stop
scenario-slo-burn-stop: kubeconfig
	@./scenarios/fire-slo-burn.sh stop

.PHONY: scenario-drift
scenario-drift: kubeconfig
	@./scenarios/fire-drift.sh start

.PHONY: scenario-drift-stop
scenario-drift-stop: kubeconfig
	@./scenarios/fire-drift.sh stop

.PHONY: scenario-rollback
scenario-rollback: kubeconfig
	@./scenarios/rollback-model.sh

.PHONY: topology
topology: kubeconfig
	@./scenarios/show-topology.sh

# ─── Browser tabs ──────────────────────────────────────────────────────────────

.PHONY: demo tab-grafana tab-alertmanager tab-prometheus tab-mlflow tab-grafana-drift

OPEN := $(shell command -v open || command -v xdg-open || echo true)

demo: tab-grafana tab-alertmanager tab-prometheus tab-mlflow
	@printf "Opened Grafana, Alertmanager, Prometheus and MLflow.\n"

tab-grafana:
	@$(OPEN) http://localhost:3000/d/k8s-cluster-overview/kubernetes-cluster-overview > /dev/null 2>&1 || true

tab-grafana-drift:
	@$(OPEN) http://localhost:3000/d/model-drift/model-drift-training-health > /dev/null 2>&1 || true

tab-alertmanager:
	@$(OPEN) http://localhost:9093 > /dev/null 2>&1 || true

tab-prometheus:
	@$(OPEN) http://localhost:9090/alerts > /dev/null 2>&1 || true

tab-mlflow:
	@$(OPEN) http://localhost:5001 > /dev/null 2>&1 || true
