# CS SOP & PrometheusRule Migration Workflow

You are executing a three-phase migration of Cluster Service (CS) observability from the
Dynatrace/app-interface stack to RHOBS.next. Work methodically through each phase. Do not
skip phases or run them out of order. Present a summary and diff to the user before raising
any PR.

---

## Slash Commands

| Command | Action |
|---------|--------|
| `/help` | Show this command list |
| `/start` | Run full workflow Phase 1 → 2 → 3 sequentially |
| `/phase1` | SOP audit and migration only |
| `/phase2` | PrometheusRule transformation only |
| `/phase3` | PR creation only (requires Phase 1 and 2 complete) |
| `/status` | Show what has been completed in this session |
| `/validate` | Run promtool check on transformed rules |
| `/diff` | Show all pending diffs before PR creation |

---

## Critical Facts — Memorise These

```
RHOBS tenant:         hcp  (UUID: EFD08939-FE1D-41A1-A28A-BE9A9BC68003)
                      No 'ocm' or 'cs' tenant exists. Do not create one.

CS metric selector:   {namespace="uhc-production", service="clusters-service"}
                      NOT "uhc-clusters-service" — that is the old incorrect label (GAP 2).

Target rules path:    rhobs-configuration/resources/tenant-rules/hcp/clusters-service.yaml

Target SOP path:      openshift/ops-sop/hypershift/alerts/<AlertName>.md

Runbook URL format:   https://github.com/openshift/ops-sop/blob/master/hypershift/alerts/<AlertName>.md

Source rules (app-interface):
  - resources/observability/prometheusrules/uhc-clusters-service-unified.prometheusrules.yaml.j2
  - resources/observability/prometheusrules/uhc-clusters-service-production.prometheusrules.yaml

Source SOPs (app-interface):
  - docs/tenant-services/uhc/sop/cs/
  - docs/tenant-services/uhc/sop/  (UHC-level SOPs that may cover CS alerts)

OTEL receiver dependency:
  CS metrics do NOT exist in RHOBS today. The transformed rules will not fire until
  the app-interface MR adding the OTEL CS receiver to
  resources/services/rhobs/otel/ocm-rhobs-app-sre-prod-04.yaml is merged.
  State this clearly in all PR descriptions.
```

---

## Phase 1 — SOP Audit and Migration

### 1.1 Enumerate source SOPs

```bash
bash scripts/enumerate-sops.sh <app-interface-path>
```

Produces `artifacts/sop-inventory.txt` listing all `.md` files under
`docs/tenant-services/uhc/sop/cs/` and `docs/tenant-services/uhc/sop/` (depth 1),
with the alert name each file covers (extracted from H1 or filename).

### 1.2 Enumerate alert names from source PrometheusRules

```bash
bash scripts/extract-alert-names.sh <app-interface-path>
```

Produces `artifacts/alert-names.txt` — one alert name per line from the `alert:` fields
in both source rule files.

### 1.3 Cross-reference SOPs against alerts

For each alert name in `artifacts/alert-names.txt`, check:
- Does a matching SOP exist in `artifacts/sop-inventory.txt`?
- Does a runbook already exist in `<ops-sop-path>/hypershift/alerts/<AlertName>.md`?

Produce `artifacts/sop-gap-report.md` with three sections:
```
## Covered — SOP exists in app-interface and runbook exists in ops-sop (update check needed)
## Needs migration — SOP exists in app-interface but missing from ops-sop
## No SOP — alert exists with no SOP anywhere (flag for follow-up, create stub)
```

**Present this report to the user before proceeding.**

### 1.4 Transform and write SOPs

For each SOP in the "Needs migration" or "Covered" categories:

```bash
bash scripts/transform-sop.sh \
  <source-sop-path> \
  <ops-sop-path>/hypershift/alerts/<AlertName>.md \
  <alert-name>
```

Transformation rules:
- Remove all URLs containing `dynatrace.com`
- Replace `uhc-clusters-service` label references with `clusters-service`
- Replace old Grafana datasource URLs with RHOBS.next equivalents
- Append the standard footer block from `templates/sop-rhobs-footer.md`
- Preserve all triage logic, escalation paths, root cause categories unchanged

For alerts with "No SOP": create a stub from `templates/sop-stub.md` and flag in PR description.

Show diff for each file and confirm before writing: "Apply this SOP? [y/n/edit]"

### 1.5 Commit SOPs

```bash
bash scripts/commit-sops.sh <ops-sop-path>
```

Branch: `SLSLE-221-cs-sop-migration`

**PAUSE — do not proceed to Phase 2 until user confirms branch is pushed.**
The runbook_url values written in Phase 2 depend on this branch being stable.

---

## Phase 2 — PrometheusRule Transformation

### 2.1 Read and merge source rules

```bash
bash scripts/read-source-rules.sh <app-interface-path>
```

Produces `artifacts/source-rules-merged.yaml`. The `.j2` template is the source of truth
for intent; the static production file is used to resolve Jinja2 variables.

Jinja2 variable resolution table:

| Variable | Production value |
|----------|-----------------|
| `{{ environment }}` | `production` |
| `{{ namespace }}` | `uhc-production` |
| `{{ service }}` | `clusters-service` |
| `{{ severity_page }}` | `critical` |
| `{{ severity_ticket }}` | `warning` |
| `{{ runbook_base_url }}` | `https://github.com/openshift/ops-sop/blob/master/hypershift/alerts` |
| Any remaining `{{ ... }}` | **Stop — ask user for value. Do not guess.** |

### 2.2 Transform rules

```bash
bash scripts/transform-rules.sh \
  artifacts/source-rules-merged.yaml \
  artifacts/clusters-service.yaml
```

Transformations:

**Metric label correction (GAP 2):**
- `service="uhc-clusters-service"` → `service="clusters-service"` in all PromQL

**Add to every alert expr:**
```promql
and on(_mc_id) (absent(hypershift_cluster_alerts_disabled))
```

**Add to every rule's labels block:**
```yaml
labels:
  otel_collect: "true"
  service: clusters-service
```

**Update runbook_url in every alert:**
```yaml
annotations:
  runbook_url: "https://github.com/openshift/ops-sop/blob/master/hypershift/alerts/<AlertName>.md"
```

**Remove from every rule:**
- Labels containing `dynatrace`, `dt_`, or `uhc-clusters-service`
- Annotations containing Dynatrace dashboard URLs
- Jinja2 block syntax (`{% %}`)

**Output file envelope:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: clusters-service
  namespace: rhobs-production
  labels:
    tenant: hcp
    prometheus: rhobs
    role: alert-rules
spec:
  groups:
    - name: clusters-service.alerts
      interval: 1m
      rules: []
    - name: clusters-service.recording
      interval: 1m
      rules: []
```

### 2.3 Validate

```bash
bash scripts/validate-rules.sh artifacts/clusters-service.yaml
```

Checks:
- `promtool check rules` passes
- No `{{` or `{%` strings remaining
- No URL containing `dynatrace.com`
- No label value `uhc-clusters-service`
- Every alert has `runbook_url`
- Every rule has `otel_collect: "true"`

Fix all findings before proceeding.

### 2.4 Write to rhobs-configuration

```bash
bash scripts/write-to-rhobs-config.sh \
  artifacts/clusters-service.yaml \
  <rhobs-configuration-path>/resources/tenant-rules/hcp/clusters-service.yaml
```

Always show full diff and confirm before writing.

---

## Phase 3 — PR Creation

Prerequisites:
- `artifacts/sop-gap-report.md` exists
- `artifacts/clusters-service.yaml` exists and passed validation
- ops-sop branch `SLSLE-221-cs-sop-migration` is pushed

### 3.1 Create rhobs-configuration branch and commit

```bash
bash scripts/commit-rules.sh <rhobs-configuration-path>
```

Branch: `SLSRE-221-cs-promrules-rhobs-next`

Commit message:
```
SLSRE-221: Add Cluster Service PrometheusRules for RHOBS.next hcp tenant

Transform uhc-clusters-service-unified.prometheusrules.yaml.j2 from
app-interface into plain YAML for the RHOBS hcp tenant.

- Jinja2 templating removed, production values resolved statically
- Label corrected: uhc-clusters-service → clusters-service (GAP 2 fix)
- hypershift_cluster_alerts_disabled inhibition added to all alerts
- runbook_url updated to openshift/ops-sop hypershift/alerts/
- otel_collect: "true" label added for RHOBS ingestion pipeline
- Dynatrace annotations removed

Note: rules will not fire until the OTEL CS receiver MR is merged to
resources/services/rhobs/otel/ocm-rhobs-app-sre-prod-04.yaml in app-interface.

Companion PR: openshift/ops-sop SLSLE-221-cs-sop-migration
Relates-to: SLSRE-221 SLSRE-634
```

### 3.2 Generate PR descriptions

```bash
bash scripts/generate-pr-descriptions.sh
```

Writes `artifacts/pr-description-ops-sop.md` and
`artifacts/pr-description-rhobs-config.md`. Each must include:
- Summary of changes
- Link to companion PR
- OTEL receiver dependency statement
- GAP 2 label correction explanation
- Jira: SLSRE-221

### 3.3 Push branches

```bash
bash scripts/push-branches.sh <ops-sop-path> <rhobs-configuration-path>
```

Pushes both branches and prints GitHub PR URLs. Does NOT open PRs automatically.

**STOP — present both PR descriptions to the user for review before they open the PRs.**

---

## Error Handling

| Situation | Action |
|-----------|--------|
| `promtool` not found | Note in artifacts, continue, flag in PR description |
| SOP has no matching alert in rules | Include in gap report as "orphaned SOP", do not migrate |
| Alert has no SOP anywhere | Create stub from `templates/sop-stub.md`, flag in PR |
| Unknown Jinja2 variable | Stop, show variable, ask user for value |
| Git push fails (auth) | Show the manual command for the user to run |
| Target file already exists | Always show diff, never overwrite without confirmation |

---

## Artefact Index

| File | Phase | Description |
|------|-------|-------------|
| `artifacts/sop-inventory.txt` | 1 | All source SOPs found |
| `artifacts/alert-names.txt` | 1 | All alert names from source rules |
| `artifacts/sop-gap-report.md` | 1 | Coverage cross-reference |
| `artifacts/source-rules-merged.yaml` | 2 | Merged deduplicated source rules |
| `artifacts/clusters-service.yaml` | 2 | Transformed rules ready for rhobs-configuration |
| `artifacts/validation-report.txt` | 2 | promtool and lint results |
| `artifacts/pr-description-ops-sop.md` | 3 | PR description for ops-sop |
| `artifacts/pr-description-rhobs-config.md` | 3 | PR description for rhobs-configuration |
