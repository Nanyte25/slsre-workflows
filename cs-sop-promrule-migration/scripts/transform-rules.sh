#!/bin/bash
# scripts/transform-rules.sh <source-yaml> <output-yaml>
# Applies all RHOBS.next transformations to the merged source rules

set -euo pipefail

SOURCE="${1:?Usage: transform-rules.sh <source-yaml> <output-yaml>}"
OUTPUT="${2:?}"
ENVELOPE="templates/clusters-service-envelope.yaml"

mkdir -p artifacts "$(dirname "$OUTPUT")"

if [ ! -f "$SOURCE" ]; then
  echo "ERROR: source file not found: $SOURCE"
  echo "Run read-source-rules.sh first."
  exit 1
fi

TMP=$(mktemp)
cp "$SOURCE" "$TMP"

echo "Applying transformations to $(basename "$SOURCE")..."

# 1. GAP 2 label correction
echo "  [1/6] Correcting service label: uhc-clusters-service -> clusters-service"
sed -i 's/uhc-clusters-service/clusters-service/g' "$TMP"

# 2. Remove Dynatrace annotations and labels
echo "  [2/6] Removing Dynatrace references"
sed -i '/dynatrace\.com/d' "$TMP"
sed -i '/dt_tenant/d' "$TMP"
sed -i '/dt_environment/d' "$TMP"

# 3. Update runbook_url base path
echo "  [3/6] Updating runbook_url base path"
OLD_BASE="https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/docs/tenant-services/uhc/sop"
NEW_BASE="https://github.com/openshift/ops-sop/blob/master/hypershift/alerts"
sed -i "s|${OLD_BASE}[^ ]*|${NEW_BASE}|g" "$TMP"
# Also handle any other runbook_url patterns pointing at app-interface
sed -i "s|runbook_url:.*app-interface.*|runbook_url: ${NEW_BASE}|g" "$TMP"

# 4. Add otel_collect label to every rule's labels block
# This is a best-effort sed — complex rules may need manual review
echo "  [4/6] Adding otel_collect: true label"
# Insert after any existing 'labels:' block that doesn't already have otel_collect
python3 - "$TMP" << 'PYEOF'
import sys
import re

path = sys.argv[1]
with open(path) as f:
    content = f.read()

# Add otel_collect under each labels: block if not already present
# Pattern: find 'labels:' blocks inside rules and insert otel_collect
lines = content.split('\n')
out = []
i = 0
while i < len(lines):
    line = lines[i]
    out.append(line)
    # If we see a labels: line inside a rule (indented), check next lines
    if re.match(r'^\s{6,}labels:\s*$', line):
        # Look ahead — if otel_collect not already in the next few label lines, add it
        indent = len(line) - len(line.lstrip())
        label_lines = []
        j = i + 1
        while j < len(lines) and (lines[j].strip() == '' or len(lines[j]) - len(lines[j].lstrip()) > indent):
            label_lines.append(lines[j])
            j += 1
        if not any('otel_collect' in l for l in label_lines):
            # Insert otel_collect at the right indent level
            out.append(' ' * (indent + 2) + 'otel_collect: "true"')
    i += 1

with open(path, 'w') as f:
    f.write('\n'.join(out))
print("    otel_collect labels inserted")
PYEOF

# 5. Add service: clusters-service label to every rule
echo "  [5/6] Adding service: clusters-service label"
python3 - "$TMP" << 'PYEOF'
import sys
import re

path = sys.argv[1]
with open(path) as f:
    content = f.read()

lines = content.split('\n')
out = []
i = 0
while i < len(lines):
    line = lines[i]
    out.append(line)
    if re.match(r'^\s{6,}labels:\s*$', line):
        indent = len(line) - len(line.lstrip())
        label_lines = []
        j = i + 1
        while j < len(lines) and (lines[j].strip() == '' or len(lines[j]) - len(lines[j].lstrip()) > indent):
            label_lines.append(lines[j])
            j += 1
        if not any('service:' in l for l in label_lines):
            out.append(' ' * (indent + 2) + 'service: clusters-service')
    i += 1

with open(path, 'w') as f:
    f.write('\n'.join(out))
print("    service labels inserted")
PYEOF

# 6. Wrap in PrometheusRule envelope
echo "  [6/6] Wrapping in PrometheusRule envelope"
HEADER=$(cat << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: clusters-service
  namespace: rhobs-production
  labels:
    tenant: hcp
    prometheus: rhobs
    role: alert-rules
  annotations:
    # Source: app-interface uhc-clusters-service-unified.prometheusrules.yaml.j2
    # Migrated by: SLSRE-221 CS SOP & PrometheusRule Migration workflow
    # OTEL dependency: rules will not fire until ocm-rhobs-app-sre-prod-04.yaml MR is merged
EOF
)

# Check if the source already has a PrometheusRule envelope
if grep -q 'kind: PrometheusRule' "$TMP"; then
  # Already wrapped — just copy
  cp "$TMP" "$OUTPUT"
else
  # Prepend envelope header and indent spec content
  echo "$HEADER" > "$OUTPUT"
  echo "spec:" >> "$OUTPUT"
  sed 's/^/  /' "$TMP" >> "$OUTPUT"
fi

rm -f "$TMP"

echo ""
echo "Transformed rules written to: $OUTPUT"
echo ""
echo "Next: run validate-rules.sh $OUTPUT"
