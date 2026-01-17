# PPI_CORE — LANES (CANONICAL)

Authority Level: Binding Lane Spec  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Role

PPI_CORE is the deterministic evaluator.

It receives:
- a PPI_REQUEST_V1
- a pinned PPI_POLICY_BUNDLE_V1 (version + hash)

It emits:
- a PPI_DECISION_RECORD_V1

PPI_CORE never executes actions.

## 2. Lane Definitions

### Lane: PPI_CORE_V1 (SPEC_ONLY)
Status: SPEC_ONLY

Rules:
- schema validation is mandatory
- missing required fields -> DENY_SCHEMA_INVALID
- missing required context keys -> DENY_MISSING_CONTEXT
- policy not found -> DENY_POLICY_NOT_FOUND
- policy conflict -> DENY_POLICY_CONFLICT unless conflict_mode resolves
- no enrichment, no inference, no external fetch
- decision record must include reason_codes and rule_path

Determinism:
- evaluation is a pure function of (request, policy_bundle, engine_version)
- timestamps are data fields only; they never influence decision

Refusal semantics:
- DENY is a correct outcome
- refusal is success

Git is law.
