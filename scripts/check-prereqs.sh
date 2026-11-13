#!/usr/bin/env bash
# Checks which tools you have, grouped by what you want to do.
# Usage: make doctor   (or: bash scripts/check-prereqs.sh)
# It only reads; it never installs or changes anything.
set -uo pipefail

green=$'\033[32m'; yellow=$'\033[33m'; dim=$'\033[2m'; bold=$'\033[1m'; reset=$'\033[0m'
missing_local=0
missing_cloud=0

check() { # check <level> <command> <why> <install hint>
  local level=$1 cmd=$2 why=$3 hint=$4
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  ${green}✓${reset} %-10s %s\n" "$cmd" "${dim}${why}${reset}"
  else
    printf "  ${yellow}✗${reset} %-10s %s\n      ${dim}install: %s${reset}\n" "$cmd" "$why" "$hint"
    if [ "$level" = local ]; then missing_local=$((missing_local + 1)); else missing_cloud=$((missing_cloud + 1)); fi
  fi
}

echo
echo "${bold}Step 1: run the demo API on your laptop (free, no cloud)${reset}"
check local git  "download the code"            "https://git-scm.com/downloads"
check local go   "run the Go API (make start)"  "https://go.dev/dl/  (or: brew install go)"
check local make "run the shortcuts in Makefile" "macOS: xcode-select --install · Linux: apt install make"
check local curl "send a question to the API"   "usually pre-installed"

echo
echo "${bold}Step 2: Parts 2 to 7 (Kubernetes, laptop cluster, clouds)${reset}"
check cloud docker    "containers and the kind laptop cluster (Part 2)" "https://docs.docker.com/get-docker/"
check cloud kind      "Kubernetes inside Docker (Part 2)"               "https://kind.sigs.k8s.io/  (or: brew install kind)"
check cloud kubectl   "talk to any Kubernetes cluster"                  "https://kubernetes.io/docs/tasks/tools/"
check cloud helm      "install packaged apps (charts)"                  "https://helm.sh/docs/intro/install/"
check cloud terraform "build cloud infrastructure from code (Parts 3-5)" "https://developer.hashicorp.com/terraform/install"

if command -v terraform >/dev/null 2>&1; then
  tfv=$(terraform version -json 2>/dev/null | sed -n 's/.*"terraform_version": *"\([0-9.]*\)".*/\1/p')
  if [ -n "$tfv" ] && [ "$(printf '%s\n1.6.0\n' "$tfv" | sort -V | head -1)" != "1.6.0" ]; then
    printf "      ${yellow}! terraform %s is too old; this repo needs 1.6 or newer${reset}\n" "$tfv"
  fi
fi

echo
echo "${bold}Cloud command lines (you only need the one for the cloud you pick)${reset}"
for c in "aws:AWS, Part 3:https://aws.amazon.com/cli/" "az:Azure, Part 4:https://learn.microsoft.com/cli/azure/install-azure-cli" "gcloud:Google Cloud, Part 5:https://cloud.google.com/sdk/docs/install"; do
  IFS=: read -r cmd why url rest <<<"$c"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  ${green}✓${reset} %-10s %s\n" "$cmd" "${dim}${why}${reset}"
  else
    printf "  ${dim}- %-10s %s (optional) %s:%s${reset}\n" "$cmd" "$why" "$url" "$rest"
  fi
done

echo
if [ "$missing_local" -eq 0 ]; then
  echo "${green}${bold}You're ready for Step 1.${reset} Run: ${bold}make start${reset}, then in a second terminal: ${bold}make ask${reset}"
else
  echo "${yellow}Install the ${missing_local} missing Step 1 tool(s) above, then run make doctor again.${reset}"
fi
if [ "$missing_cloud" -gt 0 ]; then
  echo "${dim}Step 2 tools can wait until you reach Part 2.${reset}"
fi
echo
exit 0
