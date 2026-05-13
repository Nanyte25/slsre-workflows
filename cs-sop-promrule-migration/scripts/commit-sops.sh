#!/bin/bash
# scripts/commit-sops.sh <ops-sop-path>
# Creates branch SLSLE-221-cs-sop-migration and commits all new/changed SOP files

set -euo pipefail

OPS_SOP="${1:?Usage: commit-sops.sh <ops-sop-path>}"
BRANCH="SLSLE-221-cs-sop-migration"

cd "$OPS_SOP"

# Check we are on a clean base
if ! git diff --quiet; then
  echo "ERROR: ops-sop working tree has uncommitted changes. Stash or reset before running."
  exit 1
fi

# Create or switch to branch
if git show-ref --quiet "refs/heads/$BRANCH"; then
  echo "Branch $BRANCH already exists — switching to it"
  git checkout "$BRANCH"
else
  git checkout -b "$BRANCH"
  echo "Created branch $BRANCH"
fi

# Stage all changes under hypershift/alerts/
git add hypershift/alerts/

# Show what will be committed
echo ""
echo "=== Files staged for commit ==="
git status --short hypershift/alerts/
echo ""

CHANGED=$(git diff --cached --name-only | wc -l)
if [ "$CHANGED" -eq 0 ]; then
  echo "Nothing to commit — no SOP files were changed or added."
  exit 0
fi

git commit -m "SLSLE-221: Migrate Cluster Service SOPs from app-interface to ops-sop

Port CS runbooks from docs/tenant-services/uhc/sop/cs/ in app-interface
to hypershift/alerts/ to align with RHOBS.next on-call onboarding.

Changes applied to each runbook:
- Dynatrace dashboard links removed
- Metric label corrected: uhc-clusters-service -> clusters-service (GAP 2)
- RHOBS.next Grafana links added
- Standard RHOBS.next metric source footer appended

Relates-to: SLSRE-221 SLSRE-634"

echo ""
echo "Committed. Now push with:"
echo "  git push origin $BRANCH"
echo ""
echo "PAUSE: Do not proceed to Phase 2 until this branch is pushed."
echo "The runbook_url values in the PrometheusRules depend on this branch being stable."
