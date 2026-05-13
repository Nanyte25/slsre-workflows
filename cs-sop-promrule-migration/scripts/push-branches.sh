#!/bin/bash
# scripts/push-branches.sh <ops-sop-path> <rhobs-configuration-path>
# Pushes both feature branches and prints GitHub PR creation URLs

set -euo pipefail

OPS_SOP="${1:?Usage: push-branches.sh <ops-sop-path> <rhobs-configuration-path>}"
RHOBS_CONFIG="${2:?}"

OPS_SOP_BRANCH="SLSLE-221-cs-sop-migration"
RHOBS_BRANCH="SLSRE-221-cs-promrules-rhobs-next"

echo "=== Pushing ops-sop branch ==="
cd "$OPS_SOP"
CURRENT=$(git branch --show-current)
if [ "$CURRENT" != "$OPS_SOP_BRANCH" ]; then
  echo "ERROR: ops-sop is not on branch $OPS_SOP_BRANCH (currently: $CURRENT)"
  exit 1
fi
git push origin "$OPS_SOP_BRANCH"
OPS_SOP_REMOTE=$(git remote get-url origin | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/\.git$//')
echo "Pushed: $OPS_SOP_REMOTE/tree/$OPS_SOP_BRANCH"

echo ""
echo "=== Pushing rhobs-configuration branch ==="
cd "$RHOBS_CONFIG"
CURRENT=$(git branch --show-current)
if [ "$CURRENT" != "$RHOBS_BRANCH" ]; then
  echo "ERROR: rhobs-configuration is not on branch $RHOBS_BRANCH (currently: $CURRENT)"
  exit 1
fi
git push origin "$RHOBS_BRANCH"
RHOBS_REMOTE=$(git remote get-url origin | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/\.git$//')
echo "Pushed: $RHOBS_REMOTE/tree/$RHOBS_BRANCH"

echo ""
echo "==================================================================="
echo "Both branches pushed. Open PRs at:"
echo ""
echo "  ops-sop PR:"
echo "  ${OPS_SOP_REMOTE}/compare/${OPS_SOP_BRANCH}?expand=1"
echo ""
echo "  rhobs-configuration PR:"
echo "  ${RHOBS_REMOTE}/compare/${RHOBS_BRANCH}?expand=1"
echo ""
echo "Use the PR descriptions in artifacts/pr-description-*.md"
echo "==================================================================="
