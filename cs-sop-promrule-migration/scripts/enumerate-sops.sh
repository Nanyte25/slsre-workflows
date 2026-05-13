#!/bin/bash
# scripts/enumerate-sops.sh <app-interface-path>
# Produces artifacts/sop-inventory.txt

set -euo pipefail

APP_INTERFACE="${1:?Usage: enumerate-sops.sh <app-interface-path>}"
OUT="artifacts/sop-inventory.txt"
mkdir -p artifacts

echo "# CS SOP Inventory" > "$OUT"
echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$OUT"
echo "" >> "$OUT"

echo "## CS-specific SOPs (docs/tenant-services/uhc/sop/cs/)" >> "$OUT"
find "$APP_INTERFACE/docs/tenant-services/uhc/sop/cs" -name "*.md" 2>/dev/null | sort | while read -r f; do
  # Try to extract alert name from H1, fall back to filename
  alert=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //' || true)
  [ -z "$alert" ] && alert=$(basename "$f" .md)
  echo "  file=$(basename "$f")  alert=$alert  path=$f" >> "$OUT"
done

echo "" >> "$OUT"
echo "## UHC-level SOPs (docs/tenant-services/uhc/sop/ depth=1)" >> "$OUT"
find "$APP_INTERFACE/docs/tenant-services/uhc/sop" -maxdepth 1 -name "*.md" 2>/dev/null | sort | while read -r f; do
  alert=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //' || true)
  [ -z "$alert" ] && alert=$(basename "$f" .md)
  echo "  file=$(basename "$f")  alert=$alert  path=$f" >> "$OUT"
done

echo ""
echo "SOP inventory written to $OUT"
cat "$OUT"
