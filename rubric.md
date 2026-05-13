# Migration Quality Rubric

## SOP Coverage (1-5)

Score 1: Fewer than 50% of CS alerts have a runbook in ops-sop after the workflow completes.
Score 2: 50-74% coverage. Several alerts left without runbooks.
Score 3: 75-89% coverage. Most alerts covered; a few gaps documented with a reason.
Score 4: 90-99% coverage. One or two gaps explicitly tracked in the PR description.
Score 5: 100% coverage or all gaps have a filed follow-up ticket with justification.

## Rule Correctness (1-5)

Score 1: `promtool check rules` fails on the output file.
Score 2: Rules pass syntax check but use incorrect label selectors (e.g. `uhc-clusters-service` instead of `clusters-service`).
Score 3: Rules pass and use correct selectors, but Jinja2 syntax (`{{ }}`) remains in the output.
Score 4: Rules are syntactically valid, labels correct, no Jinja2 residue. Minor style issues.
Score 5: Rules pass promtool, labels correct, no Jinja2 residue, `hypershift_cluster_alerts_disabled` inhibition present on all alerts, `otel_collect: "true"` label on all rules.

## Runbook URL Integrity (1-5)

Score 1: Runbook URLs still point at app-interface paths (internal GitLab).
Score 2: URLs point at ops-sop but paths do not match actual filenames created.
Score 3: URLs are correctly formed but reference the main branch (risky if files aren't merged yet).
Score 4: URLs reference the PR branch path. Noted in PR description that URLs will resolve post-merge.
Score 5: URLs reference the final merged path AND the PR description explains they become live on merge of the ops-sop PR.

## Dynatrace References Removed (1-5)

Score 1: Dynatrace dashboard URLs remain in output SOPs or rule annotations.
Score 3: DT links removed from rules but remain in one or more SOP files.
Score 5: No string matching `dynatrace.com`, `dt-tenant`, or `uhc-clusters-service` (old label) exists in any output artifact.

## PR Readiness (1-5)

Score 1: No branch created. Output files only exist locally.
Score 2: Branch created but commit message is generic. No PR description generated.
Score 3: Branch and commit created with correct message. PR description missing key sections.
Score 4: Branch, commit, and PR description complete. Missing link between ops-sop PR and rhobs-configuration PR.
Score 5: Both PRs have descriptions that cross-reference each other, explain the GAP 2 label correction, note the OTEL receiver MR dependency, and list the Jira ticket (SLSRE-221).
