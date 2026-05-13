#!/bin/bash
# scripts/generate-pr-descriptions.sh
# Writes artifacts/pr-description-ops-sop.md and artifacts/pr-description-rhobs-config.md
# Reads artifacts/sop-gap-report.md and artifacts/validation-report.txt as inputs

set -euo pipefail

mkdir -p artifacts

GAP_REPORT="artifacts/sop-gap-report.md"
VALIDATION="artifacts/validation-report.txt"

MIGRATED_COUNT=$(grep -c '^  file=' artifacts/sop-inventory.txt 2>/dev/null || echo "N/A")
ALERT_COUNT=$(wc -l < artifacts/alert-names.txt 2>/dev/null || echo "N/A")
NO_SOP_COUNT=$(grep -c '^- ' <(grep -A9999 '## No SOP' "$GAP_REPORT" 2>/dev/null) 2>/dev/null || echo "0")

# ── ops-sop PR description ──────────────────────────────────────────────────
cat > artifacts/pr-description-ops-sop.md << EOF
## Summary

Migrate Cluster Service (CS) runbooks from \`app-interface/docs/tenant-services/uhc/sop/cs/\`
to \`hypershift/alerts/\` as part of the RHOBS.next on-call onboarding for OCM Cluster Service.

This is part of [SLSRE-221 — OCM CS observability and on-call onboarding](https://issues.redhat.com/browse/SLSRE-221).

## Changes

- **SOPs migrated:** See gap report below
- **Dynatrace links removed** from all migrated runbooks
- **Metric label corrected:** \`uhc-clusters-service\` → \`clusters-service\` throughout
  (this is the GAP 2 correction identified in SLSRE-634)
- **RHOBS.next Grafana links** added where Dynatrace dashboard links were removed
- **Standard RHOBS.next footer** appended to each runbook (metric source, tenant, collection context)

## SOP Coverage

$(cat "$GAP_REPORT" 2>/dev/null || echo "_Gap report not yet generated_")

## Dependencies

The companion PrometheusRules PR is in \`rhobs/configuration\`:
> **[SLSRE-221-cs-promrules-rhobs-next]** (link to be added after push)

Note: the alert rules in that PR will not fire in production until the OTEL CS receiver
MR is merged to \`app-interface\`:
- Target file: \`resources/services/rhobs/otel/ocm-rhobs-app-sre-prod-04.yaml\`
- Credential: \`rhobs-ocm-ingestion-prod\` (no new secret needed)

## Jira

[SLSRE-221](https://issues.redhat.com/browse/SLSRE-221) —
[SLSRE-634](https://issues.redhat.com/browse/SLSRE-634)
EOF

echo "Written: artifacts/pr-description-ops-sop.md"

# ── rhobs-configuration PR description ─────────────────────────────────────
cat > artifacts/pr-description-rhobs-config.md << EOF
## Summary

Add Cluster Service PrometheusRules to the \`hcp\` tenant in \`rhobs-configuration\`.

This transforms \`uhc-clusters-service-unified.prometheusrules.yaml.j2\` from
\`app-interface\` into plain YAML suitable for evaluation by Thanos Ruler in the
RHOBS.next \`hcp\` tenant.

Part of [SLSRE-221 — OCM CS observability and on-call onboarding](https://issues.redhat.com/browse/SLSRE-221).

## What Changed vs Source

| Change | Detail |
|--------|--------|
| Jinja2 removed | All \`{{ }}\` expressions resolved to production values statically |
| GAP 2 label fix | \`service="uhc-clusters-service"\` → \`service="clusters-service"\` in all PromQL |
| Inhibition added | \`hypershift_cluster_alerts_disabled\` suppression on all alert exprs |
| Runbook URLs | Updated to \`openshift/ops-sop/hypershift/alerts/<AlertName>.md\` |
| OTEL label | \`otel_collect: "true"\` added to all rules |
| Dynatrace removed | All DT annotations and labels removed |

## Tenant Routing

- Tenant: \`hcp\` (UUID: \`EFD08939-FE1D-41A1-A28A-BE9A9BC68003\`)
- No \`ocm\` or \`cs\` tenant exists. CS metrics are scoped within hcp by
  \`service="clusters-service"\`.
- Metric selector: \`{namespace="uhc-production", service="clusters-service"}\`

## Validation

$(cat "$VALIDATION" 2>/dev/null || echo "_Validation report not yet generated_")

## ⚠️ Activation Dependency

These rules will **not fire** until the OTEL CS receiver MR is merged in \`app-interface\`:
- File: \`resources/services/rhobs/otel/ocm-rhobs-app-sre-prod-04.yaml\`
- Credential: \`rhobs-ocm-ingestion-prod\` (reuse, no new secret needed)
- 57 CS metric series confirmed in \`uhc-production\` (service="clusters-service")
- Confirmed NOT in RHOBS today — confirmed 2026-04-17

Merging this PR ahead of the OTEL receiver MR is safe — rules will simply return
no data until the metrics start flowing.

## Companion PR

Runbooks for all alerts in this file are in:
> **openshift/ops-sop** branch \`SLSLE-221-cs-sop-migration\` (link to be added after push)

## Jira

[SLSRE-221](https://issues.redhat.com/browse/SLSRE-221) —
[SLSRE-634](https://issues.redhat.com/browse/SLSRE-634)
EOF

echo "Written: artifacts/pr-description-rhobs-config.md"
echo ""
echo "Review both PR descriptions in artifacts/ before opening PRs."
