# ESCALATION_GATE — LANES (CANONICAL)

Authority Level: Binding Lane Spec  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Role

ESCALATION_GATE defines explicit escalation.

Escalation is never automatic.

## 2. Lane Definitions

### Lane: ESCALATION_GATE_V1 (SPEC_ONLY)
Status: SPEC_ONLY

Rules:
- escalation requires explicit request metadata
- escalation produces a new decision record
- escalation never mutates policy bundles
- escalation never implies approval
- missing escalation authority -> DENY_POLICY_NOT_FOUND or DENY_CAPABILITY_NOT_PERMITTED

Git is law.
