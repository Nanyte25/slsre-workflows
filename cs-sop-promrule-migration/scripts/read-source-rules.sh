#!/bin/bash
# scripts/read-source-rules.sh <app-interface-path>
# Reads both CS rule source files, strips Jinja2, merges into artifacts/source-rules-merged.yaml

set -euo pipefail

APP_INTERFACE="${1:?Usage: read-source-rules.sh <app-interface-path>}"
UNIFIED="$APP_INTERFACE/resources/observability/prometheusrules/uhc-clusters-service-unified.prometheusrules.yaml.j2"
PROD="$APP_INTERFACE/resources/observability/prometheusrules/uhc-clusters-service-production.prometheusrules.yaml"
OUT="artifacts/source-rules-merged.yaml"
UNKNOWN_VARS="artifacts/unknown-jinja2-vars.txt"

mkdir -p artifacts

echo "Reading source files..."
for f in "$UNIFIED" "$PROD"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: source file not found: $f"
    exit 1
  fi
  echo "  found: $f"
done

# --- Jinja2 variable resolution table (production values) ---
# If a variable is NOT in this table, it is written to unknown-vars.txt
declare -A JINJA_VARS=(
  ["environment"]="production"
  ["namespace"]="uhc-production"
  ["service"]="clusters-service"
  ["severity_page"]="critical"
  ["severity_ticket"]="warning"
  ["runbook_base_url"]="https://github.com/openshift/ops-sop/blob/master/hypershift/alerts"
)

# Use the .j2 template as primary source, resolve variables
TMP=$(mktemp)
cp "$UNIFIED" "$TMP"

# Apply known variable substitutions
for var in "${!JINJA_VARS[@]}"; do
  val="${JINJA_VARS[$var]}"
  sed -i "s|{{ ${var} }}|${val}|g" "$TMP"
  sed -i "s|{{${var}}}|${val}|g" "$TMP"
done

# Remove Jinja2 block statements ({% if %}, {% for %}, {% endif %} etc.)
sed -i '/^{%/d' "$TMP"
sed -i '/^\s*{%/d' "$TMP"

# Check for remaining unknown Jinja2 variables
grep -n '{{' "$TMP" > "$UNKNOWN_VARS" 2>/dev/null || true

if [ -s "$UNKNOWN_VARS" ]; then
  echo ""
  echo "WARNING: Unknown Jinja2 variables remain after substitution:"
  cat "$UNKNOWN_VARS"
  echo ""
  echo "These must be resolved before proceeding."
  echo "Add them to the JINJA_VARS table in this script or provide values manually."
  echo "Unknown vars written to $UNKNOWN_VARS"
  exit 1
fi

cp "$TMP" "$OUT"
rm -f "$TMP"

ALERT_COUNT=$(grep -c '^\s*alert:' "$OUT" || true)
RECORD_COUNT=$(grep -c '^\s*record:' "$OUT" || true)

echo ""
echo "Source rules merged:"
echo "  alert rules:     $ALERT_COUNT"
echo "  recording rules: $RECORD_COUNT"
echo "  output:          $OUT"
echo ""
echo "Review $OUT before running transform-rules.sh"
