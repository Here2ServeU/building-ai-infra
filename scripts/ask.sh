#!/usr/bin/env bash
# Sends one question to the local RAG API (started with: make start).
# Usage: make ask Q="what is GitOps?"
set -euo pipefail

q=${Q:-"What is a GPU node pool that scales to zero?"}
url=${RAG_API_URL:-http://localhost:8080}

# Build the JSON body safely (escape backslashes and quotes).
esc=${q//\\/\\\\}
esc=${esc//\"/\\\"}
body=$(printf '{"query":"%s","top_k":2}' "$esc")

if ! resp=$(curl -sS -m 5 -X POST "$url/v1/query" -H 'content-type: application/json' -d "$body" 2>/dev/null); then
  echo "Could not reach the API at $url."
  echo "Start it first in another terminal with: make start"
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  echo "$resp" | jq -r '.documents[]? | "\n[\(.score | tostring | .[0:4])] \(.metadata.title)\n\(.text)"'
  echo "$resp" | jq -e '.documents | length > 0' >/dev/null 2>&1 || echo "$resp"
else
  echo "$resp"
fi
echo
