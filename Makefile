.DEFAULT_GOAL := help
SHELL := bash

ENV ?= dev
CLUSTER ?= dev-eks
TF_DIR := terraform/environments/$(ENV)

.PHONY: help
help: ## Show this help
	@printf "\nNew here? Run: make doctor, then make start, then make ask   (guide: START-HERE.md)\n"
	@awk 'BEGIN{FS=":.*##"} /^## -+ / {t=$$0; gsub(/^## -+ /,"",t); gsub(/ -+$$/,"",t); printf "\n\033[1m%s\033[0m\n", t} /^[a-zA-Z_-]+:.*?##/ {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo

## ---------- Beginners: start here ----------
.PHONY: doctor
doctor: ## Check which tools you have (read-only, installs nothing)
	@bash scripts/check-prereqs.sh

.PHONY: start
start: ## Run the demo RAG API on your laptop (no cloud, no Docker). Ctrl+C stops it
	@echo "Starting the API in stub mode on http://localhost:8080 ..."
	@echo "In a second terminal, run: make ask"
	cd apps/rag-api && RAG_STUB=1 go run ./cmd/server

Q ?= What is a GPU node pool that scales to zero?
export Q
.PHONY: ask
ask: ## Ask the running API a question, e.g. make ask Q="what is GitOps?"
	@bash scripts/ask.sh

.PHONY: pdfs
pdfs: ## Rebuild the chapter PDFs in docs/series/pdf (needs pandoc and Chrome)
	@bash scripts/build-pdfs.sh

## ---------- Terraform ----------
.PHONY: tf-init
tf-init: ## Initialize Terraform for the selected ENV
	terraform -chdir=$(TF_DIR) init

.PHONY: tf-plan
tf-plan: ## Run terraform plan
	terraform -chdir=$(TF_DIR) plan -out=plan.tfplan

.PHONY: tf-apply
tf-apply: ## Apply terraform plan
	terraform -chdir=$(TF_DIR) apply plan.tfplan

.PHONY: tf-destroy
tf-destroy: ## Destroy the selected ENV (series rule: build, learn, destroy the same day)
	terraform -chdir=$(TF_DIR) destroy

.PHONY: tf-fmt
tf-fmt: ## Format all Terraform files
	terraform fmt -recursive terraform/

.PHONY: tf-validate
tf-validate: ## Validate all Terraform configs
	@for d in terraform/environments/*/; do \
		echo "==> Validating $$d"; \
		terraform -chdir=$$d init -backend=false >/dev/null && terraform -chdir=$$d validate; \
	done

## ---------- Flux (default GitOps) ----------
.PHONY: flux-bootstrap
flux-bootstrap: ## Bootstrap FluxCD against $CLUSTER
	flux bootstrap git \
		--url=ssh://git@github.com/Here2ServeU/building-ai-infra \
		--branch=main \
		--path=flux/clusters/$(CLUSTER) \
		--components-extra=image-reflector-controller,image-automation-controller

.PHONY: flux-reconcile
flux-reconcile: ## Force a reconciliation pass on the active cluster
	flux reconcile source git flux-system && flux reconcile kustomization flux-system

## ---------- ArgoCD (alternative GitOps) ----------
.PHONY: argocd-bootstrap
argocd-bootstrap: ## Install ArgoCD and apply the $CLUSTER root Application
	kubectl apply -k argocd/install/
	kubectl -n argocd rollout status deploy/argocd-server --timeout=5m
	kubectl apply -f argocd/projects/rag-platform.yaml
	kubectl apply -f argocd/clusters/$(CLUSTER)/root-app.yaml

.PHONY: argocd-sync
argocd-sync: ## Force a sync of the $CLUSTER root Application
	argocd app sync rag-platform-$(CLUSTER)

## ---------- Helm ----------
.PHONY: helm-lint
helm-lint: ## Lint all Helm charts
	@for c in helm/charts/*/; do echo "==> Linting $$c"; helm lint $$c; done

.PHONY: helm-template
helm-template: ## Render all charts (smoke test)
	@for c in helm/charts/*/; do echo "==> Templating $$c"; helm template smoke $$c >/dev/null; done

## ---------- App: rag-api (Go) ----------
.PHONY: rag-api-build
rag-api-build: ## Build rag-api binary
	cd apps/rag-api && go build -o bin/rag-api ./cmd/server

.PHONY: rag-api-test
rag-api-test: ## Run rag-api tests
	cd apps/rag-api && go test -race -count=1 ./...

.PHONY: rag-api-run
rag-api-run: ## Run rag-api against real deps (EMBEDDER_ENDPOINT, VECTOR_DB_ADDRESS). For stub mode use make start
	cd apps/rag-api && go run ./cmd/server

## ---------- App: ingest-worker (Python) ----------
.PHONY: ingest-worker-test
ingest-worker-test: ## Run python tests
	cd apps/ingest-worker && python -m pytest -q

.PHONY: ingest-worker-up
ingest-worker-up: ## Run ingest worker docker-compose stack (Airflow + MLflow + Qdrant)
	cd apps/ingest-worker && docker compose up --build

## ---------- Lint everything ----------
.PHONY: lint
lint: tf-fmt tf-validate helm-lint ## Lint all configs and code
	cd apps/rag-api && go vet ./... && gofmt -l . | (! grep .)
	cd apps/ingest-worker && ruff check . && ruff format --check .

## ---------- Cleanup ----------
.PHONY: clean
clean: ## Remove local build artifacts
	rm -rf apps/rag-api/bin apps/rag-api/coverage.out
	find . -name '__pycache__' -prune -exec rm -rf {} +
	find . -name '*.tfplan' -delete
