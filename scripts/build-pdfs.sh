#!/usr/bin/env bash
# Builds one PDF per chapter from docs/series/part-*.md
# Output: docs/series/pdf/
# Needs: pandoc, and Google Chrome or Chromium (headless printing).
# Usage: make pdfs
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
src="$root/docs/series"
assets="$src/pdf-src"
out="$src/pdf"
mkdir -p "$out"

command -v pandoc >/dev/null || { echo "pandoc not found: https://pandoc.org/installing.html"; exit 1; }

chrome=${CHROME:-}
if [ -z "$chrome" ]; then
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
           "/Applications/Chromium.app/Contents/MacOS/Chromium" \
           google-chrome google-chrome-stable chromium chromium-browser; do
    if [ -x "$c" ] || command -v "$c" >/dev/null 2>&1; then chrome=$c; break; fi
  done
fi
[ -n "$chrome" ] || { echo "Chrome/Chromium not found. Set CHROME=/path/to/chrome"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -r "$tmp"' EXIT

for md in "$src"/part-*.md; do
  name=$(basename "$md" .md)
  html="$tmp/$name.html"
  pandoc "$md" \
    --from markdown+yaml_metadata_block \
    --to html5 \
    --template "$assets/template.html" \
    --lua-filter "$assets/links.lua" \
    --variable styles="$(cat "$assets/style.css")" \
    --output "$html"
  "$chrome" --headless=new --disable-gpu --no-pdf-header-footer \
    --print-to-pdf="$out/$name.pdf" "file://$html" >/dev/null 2>&1
  echo "  built docs/series/pdf/$name.pdf"
done
