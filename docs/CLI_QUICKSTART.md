# Covenant Gate CLI Quickstart

## Purpose

Covenant Gate is a deterministic governance and policy evaluation engine.

Use it when you need:
- explicit allow and deny behavior
- signed policy bundle verification
- deterministic evidence generation
- reproducible governance runs
- strict machine-readable contracts

---

## Open the repo root

cd C:\dev\covenant-gate

---

## Canonical full-green command

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File .\scripts\_RUN_cg_full_green_v1.ps1 `
  -RepoRoot .

Expected success output:

FULL_GREEN_BUNDLE: <bundle path>
COVENANT_GATE_FULL_GREEN_OK

---

## Conversation layer selftest

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File .\scripts\_selftest_cg_conversation_layer_v1.ps1 `
  -RepoRoot .

Expected:

CG_CONVERSATION_LAYER_SELFTEST_OK

---

## Negative stress selftest

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File .\scripts\selftest_cg_stress_negative_v1.ps1 `
  -RepoRoot .

Expected:

SELFTEST_CG_STRESS_NEGATIVE_OK

---

## Vector tests

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File .\scripts\cg_run_test_vectors_v1.ps1 `
  -RepoRoot .

Expected:

DETERMINISM_OK
TESTS_DONE_OK

---

## Evidence output

proofs\receipts\cg_full_green\
proofs\receipts\
proofs\_tmp\

---

## Release requirements

All must be true:
- conversation selftest green
- negative stress green
- vector tests green
- full green runner passes
- commit completed
- tag created AFTER commit
- tag pushed

---

## Canonical release order

RUN TESTS
FULL GREEN
COMMIT
TAG
PUSH
VERIFY TAGS

---

## Troubleshooting

STEP_FAIL:
A sub-step failed. Inspect bundle output.

POLICY_SIG_MISSING:
Expected failure token for negative tests.

RUNNER_NOT_FOUND:
Wrong directory or missing script.

PARSE_GATE_FAIL:
Script is not valid PowerShell.

---

## Operator rule

The CLI is the authoritative operator layer.

All other layers must call into this.
