#!/usr/bin/env bash
# Installs the command-line tools the laptop demo (Part 2) needs: kind, kubectl, helm, jq.
# Skips anything you already have. Docker Desktop is the one thing you install by hand.
#
#   macOS:    uses Homebrew (https://brew.sh)
#   Linux:    downloads the official binaries into /usr/local/bin (asks for sudo once)
#   Windows:  run this inside WSL 2 (Ubuntu), with Docker Desktop's WSL integration on
#
# Usage: make install-tools   (or: bash scripts/install-tools.sh)
set -euo pipefail

green=$'\033[32m'; yellow=$'\033[33m'; red=$'\033[31m'; bold=$'\033[1m'; reset=$'\033[0m'
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
KIND_VERSION="${KIND_VERSION:-v0.27.0}"

have() { command -v "$1" >/dev/null 2>&1; }
ok()   { printf "  ${green}✓${reset} %s\n" "$1"; }
step() { printf "  ${yellow}→${reset} %s\n" "$1"; }

os=$(uname -s)
case "$(uname -m)" in
  x86_64|amd64) arch=amd64 ;;
  arm64|aarch64) arch=arm64 ;;
  *) printf "${red}Unsupported CPU: %s${reset}\n" "$(uname -m)"; exit 1 ;;
esac

echo
echo "${bold}Installing the Part 2 tools (kind, kubectl, helm, jq)${reset}"

if [ "$os" = Darwin ]; then
  if ! have brew; then
    printf "${red}Homebrew is needed first.${reset} Install it from https://brew.sh, then run this again.\n"
    exit 1
  fi
  for t in kind kubectl helm jq; do
    pkg=$t; [ "$t" = kubectl ] && pkg=kubernetes-cli
    if have "$t"; then ok "$t already installed"; else step "brew install $pkg"; brew install "$pkg" >/dev/null; ok "$t installed"; fi
  done

elif [ "$os" = Linux ]; then
  SUDO=""
  if [ ! -w "$INSTALL_DIR" ]; then SUDO="sudo"; fi
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

  if have kind; then ok "kind already installed"; else
    step "downloading kind $KIND_VERSION"
    curl -fsSLo "$tmp/kind" "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${arch}"
    $SUDO install -m 0755 "$tmp/kind" "$INSTALL_DIR/kind"; ok "kind installed"
  fi

  if have kubectl; then ok "kubectl already installed"; else
    step "downloading kubectl (latest stable)"
    kv=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
    curl -fsSLo "$tmp/kubectl" "https://dl.k8s.io/release/${kv}/bin/linux/${arch}/kubectl"
    $SUDO install -m 0755 "$tmp/kubectl" "$INSTALL_DIR/kubectl"; ok "kubectl $kv installed"
  fi

  if have helm; then ok "helm already installed"; else
    step "installing helm (official installer)"
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o "$tmp/get-helm-3"
    HELM_INSTALL_DIR="$INSTALL_DIR" USE_SUDO="$([ -n "$SUDO" ] && echo true || echo false)" bash "$tmp/get-helm-3" >/dev/null
    ok "helm installed"
  fi

  if have jq; then ok "jq already installed"; else
    step "installing jq"
    if have apt-get; then $SUDO apt-get install -y -qq jq >/dev/null
    elif have dnf; then $SUDO dnf install -y -q jq
    elif have yum; then $SUDO yum install -y -q jq
    else
      curl -fsSLo "$tmp/jq" "https://github.com/jqlang/jq/releases/latest/download/jq-linux-${arch}"
      $SUDO install -m 0755 "$tmp/jq" "$INSTALL_DIR/jq"
    fi
    ok "jq installed"
  fi

else
  printf "${yellow}Windows detected (%s).${reset} The demo runs inside WSL 2:\n" "$os"
  echo "  1. In PowerShell (as admin): wsl --install      then restart"
  echo "  2. Install Docker Desktop and turn on Settings → Resources → WSL integration for Ubuntu"
  echo "  3. Open Ubuntu, clone the repo there, and run: make install-tools"
  exit 1
fi

echo
if have docker; then
  if docker info >/dev/null 2>&1; then ok "docker is installed and running"
  else printf "  ${yellow}!${reset} docker is installed but not running. Start Docker Desktop.\n"; fi
else
  printf "  ${yellow}!${reset} Docker is the one tool to install yourself: https://docs.docker.com/get-docker/\n"
  echo "    Then give it at least 6 CPUs and 10 GB of memory (Settings → Resources)."
fi
echo
echo "${green}${bold}Done.${reset} Check everything with: ${bold}make doctor${reset}, then: ${bold}cd demo && make up${reset}"
echo
