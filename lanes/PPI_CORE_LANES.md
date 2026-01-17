# PPI_CORE — LANES (CANONICAL)

Authority Level: Binding Lane Spec  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## Lane: PPI_CORE_V1 (SPEC_ONLY)

Purpose: deterministic evaluation of a PPI_REQUEST against a pinned policy bundle.

Inputs:
- PPI_REQUEST_V1 (schemas/PPI_REQUEST_V1.schema.json)
- policy bundle (schemas/PPI_POLICY_BUNDLE_V1.schema.json)

Outputs:
- PPI_DECISION_RECORD_V1 (schemas/PPI_DECISION_RECORD_V1.schema.json)

Determinism:
- No hidden state
- No inference
- No “closest match”
- Missing context -> DENY (CTX_MISSING) unless an explicit rule matches first

Rule ordering:
- If conflict_resolution.mode=deny_on_conflict: conflicting matches -> DENY (POLICY_CONFLICT_NO_RESOLUTION)
- If conflict_resolution.mode=explicit_priority_only: resolve by priority_order list only; if unresolved -> DENY

Terminal decisions:
ALLOW | DENY | ESCALATE | REQUIRE_ATTESTATION

Status:
SPEC_ONLY until runtime exists + tests exist.

Git is law.
