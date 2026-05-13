#!/bin/bash
# scripts/commit-rules.sh <rhobs-configuration-path>
# Copies artifacts/clusters-service.yaml into rhobs-configuration and commits

set -euo pipefail

RHOBS_CONFIG="${1:?Usage: commit-rules.sh <rhobs-configuration-path>}"
SOURCE="artifacts/clusters-service.yaml"
TARGET="$RHOBS_CONFIG/resources/tenant-rules/hcp/clusters-service.yaml"
BRANCH="SLSRE-221-cs-promrules-rhobs-next"

if [ ! -f "$SOURCE" ]; then
  echo "ERROR: $SOURCE not found. Run transform-rules.sh and validate-rules.sh first."
  exit 1
fi

cd "$RHOBS_CONFIG"

# Check working tree is clean
if ! git diff --quiet; then
  echo "ERROR: rhobs-configuration working tree has uncommitted changes."
  exit 1
fi

# Create or switch to branch
if git show-ref --quiet "refs/heads/$BRANCH"; then
  echo "Branch $BRANCH already exists — switching"
  git checkout "$BRANCH"
else
  git checkout -b "$BRANCH"
  echo "Created branch $BRANCH"
fi

cd - > /dev/null

# Show diff before writing
echo "=== DIFF: $TARGET ==="
if [ -f "$TARGET" ]; then
  diff "$TARGET" "$SOURCE" || true
else
  echo "(new file)"
  cat "$SOURCE"
fi
echo "=== END DIFF ==="
echo ""

read -r -p "Write this file to $TARGET and commit? [y/n] " CHOICE
if [[ "$CHOICE" != "y" && "$CHOICE" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

cp "$SOURCE" "$TARGET"

cd "$RHOBS_CONFIG"
git add "resources/tenant-rules/hcp/clusters-service.yaml"

git commit -m "SLSRE-221: Add Cluster Service PrometheusRules for RHOBS.next hcp tenant

Transform uhc-clusters-service-unified.prometheusrules.yaml.j2 from
app-interface into plain YAML for the RHOBS hcp tenant.

- Jinja2 templating removed, production values resolved statically
- Label corrected: uhc-clusters-service -> clusters-service (GAP 2 fix)
- hypershift_cluster_alerts_disabled inhibition added to all alerts
- runbook_url updated to openshift/ops-sop hypershift/alerts/
- otel_collect: true label added for RHOBS ingestion pipeline
- Dynatrace annotations removed

Note: rules will not fire until the OTEL CS receiver MR is merged to
resources/services/rhobs/otel/ocm-rhobs-app-sre-prod-04.yaml in app-interface.

Companion PR: openshift/ops-sop SLSLE-221-cs-sop-migration
Relates-to: SLSRE-221 SLSRE-634"

echo ""
echo "Committed. Now push with:"
echo "  cd $RHOBS_CONFIG && git push origin $BRANCH"
