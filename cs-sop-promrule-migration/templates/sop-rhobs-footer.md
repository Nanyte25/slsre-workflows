## Metric Source (RHOBS.next)

This alert fires from metrics collected via OTEL from the `uhc-production` namespace
on `app-sre-prod-04`, forwarded to the RHOBS `hcp` tenant.

| Property | Value |
|----------|-------|
| Metric selector | `{namespace="uhc-production", service="clusters-service"}` |
| RHOBS tenant | `hcp` (UUID: `EFD08939-FE1D-41A1-A28A-BE9A9BC68003`) |
| Credential | `rhobs-ocm-ingestion-prod` on `app-sre-prod-04` |
| Dashboard | [RHOBS.next Central ROSA HCP](https://grafana.stage.devshift.net/d/af21gznl6zl6oc/rhobs-next-central-rosa-hcp-dashboard) |

## Related Jira

[SLSRE-221](https://issues.redhat.com/browse/SLSRE-221) — OCM CS observability and on-call onboarding
