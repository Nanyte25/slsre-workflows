#!/bin/bash
# scripts/transform-sop.sh <source-sop-path> <target-path> <alert-name>
# Applies RHOBS.next transformation rules to a single SOP file

set -euo pipefail

SOURCE="${1:?Usage: transform-sop.sh <source> <target> <alert-name>}"
TARGET="${2:?}"
ALERT_NAME="${3:?}"
FOOTER_TEMPLATE="templates/sop-rhobs-footer.md"

mkdir -p "$(dirname "$TARGET")"

# Work on a temp file
TMP=$(mktemp)
cp "$SOURCE" "$TMP"

# 1. Remove Dynatrace URLs (full lines containing dynatrace.com)
sed -i '/dynatrace\.com/d' "$TMP"

# 2. Correct old metric label
sed -i 's/uhc-clusters-service/clusters-service/g' "$TMP"

# 3. Replace old Grafana datasource references
sed -i 's|hypershift-observatorium-stage|rhobs-next|g' "$TMP"
sed -i 's|hypershift-observatorium-production|rhobs-next|g' "$TMP"

# 4. Replace generic runbook URL pattern if present
sed -i "s|docs/tenant-services/uhc/sop/cs/${ALERT_NAME}|hypershift/alerts/${ALERT_NAME}|g" "$TMP"

# 5. Append RHOBS.next footer if template exists
if [ -f "$FOOTER_TEMPLATE" ]; then
  echo "" >> "$TMP"
  echo "---" >> "$TMP"
  # Replace __ALERT_NAME__ placeholder in footer
  sed "s/__ALERT_NAME__/${ALERT_NAME}/g" "$FOOTER_TEMPLATE" >> "$TMP"
fi

# Show diff
echo "=== DIFF for $ALERT_NAME ==="
diff "$SOURCE" "$TMP" || true
echo "=== END DIFF ==="
echo ""

# Prompt for confirmation
read -r -p "Apply this SOP to $TARGET? [y/n/edit] " CHOICE
case "$CHOICE" in
  y|Y)
    cp "$TMP" "$TARGET"
    echo "Written: $TARGET"
    ;;
  e|edit)
    "${EDITOR:-vi}" "$TMP"
    cp "$TMP" "$TARGET"
    echo "Written (after edit): $TARGET"
    ;;
  *)
    echo "Skipped: $TARGET"
    ;;
esac

rm -f "$TMP"
