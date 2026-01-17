# GI / PPI — REASON CODES (CANONICAL)

Authority Level: Binding Reason Registry  
Status: ✅ LOCKED | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

Reason codes explain *why* a decision occurred.
They do not justify, soften, or contextualize outcomes.

---

## GENERAL DENIAL CODES

| Code | Meaning |
|-----|--------|
| DENY_SCHEMA_INVALID | Request failed schema validation |
| DENY_MISSING_CONTEXT | Required context key missing |
| DENY_POLICY_NOT_FOUND | Policy not registered |
| DENY_POLICY_CONFLICT | Conflicting rules detected |
| DENY_CAPABILITY_NOT_PERMITTED | Capability missing or invalid |
| DENY_CONSTITUTIONAL_VIOLATION | Stop layer violation |
| DENY_DETERMINISM_VIOLATION | Non-deterministic behavior detected |

---

## NON-DENIAL CODES

| Code | Meaning |
|-----|--------|
| ALLOW_POLICY_MATCH | Policy explicitly allows |
| ESCALATE_REQUIRED | Explicit escalation required |
| REQUIRE_ATTESTATION | Attestation required before reevaluation |

---

## SEMANTIC LAW

- Reason codes are immutable once emitted.
- Multiple reason codes may exist per decision.
- Reason codes do not imply remediation.

Git is law.
