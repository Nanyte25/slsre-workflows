#!/bin/bash
# scripts/validate-rules.sh <rules-yaml>
# Runs promtool check rules and additional lint checks
# Produces artifacts/validation-report.txt

set -euo pipefail

RULES="${1:?Usage: validate-rules.sh <rules-yaml>}"
OUT="artifacts/validation-report.txt"
mkdir -p artifacts

PASS=0
FAIL=0

log_pass() { echo "  PASS: $1" | tee -a "$OUT"; ((PASS++)); }
log_fail() { echo "  FAIL: $1" | tee -a "$OUT"; ((FAIL++)); }

echo "# Validation Report: $(basename "$RULES")" > "$OUT"
echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$OUT"
echo "" >> "$OUT"

echo "## promtool check rules" | tee -a "$OUT"
if command -v promtool &>/dev/null; then
  if promtool check rules "$RULES" >> "$OUT" 2>&1; then
    log_pass "promtool check rules passed"
  else
    log_fail "promtool check rules FAILED — see above output"
  fi
else
  echo "  SKIP: promtool not found in PATH — install prometheus and re-run" | tee -a "$OUT"
fi

echo "" | tee -a "$OUT"
echo "## Jinja2 residue check" | tee -a "$OUT"
if grep -n '{{' "$RULES" >> "$OUT" 2>/dev/null; then
  log_fail "Jinja2 expression '{{' found — Jinja2 not fully rendered"
elif grep -n '{%' "$RULES" >> "$OUT" 2>/dev/null; then
  log_fail "Jinja2 block '{%' found — Jinja2 not fully rendered"
else
  log_pass "No Jinja2 residue found"
fi

echo "" | tee -a "$OUT"
echo "## Dynatrace reference check" | tee -a "$OUT"
if grep -ni 'dynatrace' "$RULES" >> "$OUT" 2>/dev/null; then
  log_fail "Dynatrace reference found"
else
  log_pass "No Dynatrace references found"
fi

echo "" | tee -a "$OUT"
echo "## Label correction check (GAP 2)" | tee -a "$OUT"
if grep -n 'uhc-clusters-service' "$RULES" >> "$OUT" 2>/dev/null; then
  log_fail "Old label 'uhc-clusters-service' found — GAP 2 not fully corrected"
else
  log_pass "No 'uhc-clusters-service' labels found"
fi

echo "" | tee -a "$OUT"
echo "## runbook_url coverage" | tee -a "$OUT"
ALERT_COUNT=$(grep -c '^\s*alert:' "$RULES" || true)
RUNBOOK_COUNT=$(grep -c 'runbook_url:' "$RULES" || true)
echo "  alert rules: $ALERT_COUNT  runbook_url entries: $RUNBOOK_COUNT" | tee -a "$OUT"
if [ "$ALERT_COUNT" -eq "$RUNBOOK_COUNT" ]; then
  log_pass "All alert rules have runbook_url"
else
  log_fail "$((ALERT_COUNT - RUNBOOK_COUNT)) alert(s) missing runbook_url"
fi

echo "" | tee -a "$OUT"
echo "## otel_collect label coverage" | tee -a "$OUT"
OTEL_COUNT=$(grep -c 'otel_collect' "$RULES" || true)
echo "  rules with otel_collect: $OTEL_COUNT" | tee -a "$OUT"
if [ "$OTEL_COUNT" -gt 0 ]; then
  log_pass "otel_collect label present"
else
  log_fail "otel_collect label missing from all rules"
fi

echo "" | tee -a "$OUT"
echo "## Summary" | tee -a "$OUT"
echo "  PASSED: $PASS  FAILED: $FAIL" | tee -a "$OUT"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Validation FAILED with $FAIL issue(s). Fix before Phase 3."
  exit 1
else
  echo ""
  echo "Validation PASSED. Ready for Phase 3."
fi
