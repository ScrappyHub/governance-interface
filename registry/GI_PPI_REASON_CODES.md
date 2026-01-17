# GI / PPI — REASON CODES (CANONICAL)

Authority Level: Binding Reason Code Registry  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

Reason codes explain *why* a decision occurred.
They do not explain *how to fix it*.

---

## DECISION REASON CODES

### ALLOW
- ALLOW_POLICY_MATCH
- ALLOW_EXPLICIT_OVERRIDE

### DENY
- DENY_MISSING_CONTEXT
- DENY_POLICY_NOT_FOUND
- DENY_POLICY_CONFLICT
- DENY_CAPABILITY_NOT_PERMITTED
- DENY_SCHEMA_INVALID
- DENY_DETERMINISM_VIOLATION

### ESCALATE
- ESCALATE_POLICY_REQUIRES_AUTHORITY
- ESCALATE_ATTESTATION_REQUIRED

### REQUIRE_ATTESTATION
- REQUIRE_HUMAN_ATTESTATION
- REQUIRE_EXTERNAL_ASSERTION

---

## RULES

- Every decision record MUST include ≥1 reason code.
- Reason codes are immutable once recorded.
- Reason codes are not user-facing explanations.

Git is law.
