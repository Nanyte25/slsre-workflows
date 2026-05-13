# __ALERT_NAME__

> ⚠️ **Stub runbook** — this file was created during the SLSRE-221 CS SOP migration.
> The full runbook content needs to be authored. See the original app-interface SOP
> at `docs/tenant-services/uhc/sop/cs/` if one exists.

## Alert Description

<!-- Describe what this alert means and what service/component it covers -->

## Impact

<!-- What is the user-facing or SLO impact when this alert fires? -->

## Triage Steps

1. Check the RHOBS.next Central ROSA HCP Dashboard for the affected cluster
2. Identify the affected cluster ID from alert labels (`_mc_id`, `managed_cluster_id`)
3. Log into the relevant cluster via `ocm backplane login <cluster-id>`
4. Check pod status in the `uhc-production` namespace:
   ```bash
   oc get pods -n uhc-production -l service=clusters-service
   ```

## Escalation

<!-- Who to escalate to if triage doesn't resolve the issue -->

- **OCM CS team Slack:** `#service-development-cluster-service`
- **On-call SRE:** PagerDuty escalation policy `rhobs-hcp-critical-<region>`

---

## Metric Source

This alert fires from metrics collected via OTEL from the `uhc-production` namespace
on `app-sre-prod-04`, forwarded to the RHOBS `hcp` tenant.

Metric selector: `{namespace="uhc-production", service="clusters-service"}`

RHOBS tenant: `hcp` (UUID: `EFD08939-FE1D-41A1-A28A-BE9A9BC68003`)

## Related Alerts

<!-- List related CS alert runbooks with links -->

## Related Jira

[SLSRE-221](https://issues.redhat.com/browse/SLSRE-221) — OCM CS observability and on-call onboarding
