#!/bin/bash
# scripts/extract-alert-names.sh <app-interface-path>
# Extracts all alert: names from both CS PrometheusRule source files
# Produces artifacts/alert-names.txt

set -euo pipefail

APP_INTERFACE="${1:?Usage: extract-alert-names.sh <app-interface-path>}"
OUT="artifacts/alert-names.txt"
mkdir -p artifacts

UNIFIED="$APP_INTERFACE/resources/observability/prometheusrules/uhc-clusters-service-unified.prometheusrules.yaml.j2"
PROD="$APP_INTERFACE/resources/observability/prometheusrules/uhc-clusters-service-production.prometheusrules.yaml"

for f in "$UNIFIED" "$PROD"; do
  if [ ! -f "$f" ]; then
    echo "WARNING: source file not found: $f" >&2
  fi
done

# Extract alert names from both files, deduplicate, sort
{
  grep -h '^\s*alert:' "$UNIFIED" "$PROD" 2>/dev/null \
    | sed 's/^\s*alert:\s*//' \
    | sed "s/[\"']//g" \
    | tr -d ' '
} | sort -u > "$OUT"

COUNT=$(wc -l < "$OUT")
echo "Found $COUNT unique alert names:"
cat "$OUT"
echo ""
echo "Written to $OUT"
