# STATE_MACHINE — LANES (CANONICAL)

Authority Level: Binding Lane Spec  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Role

STATE_MACHINE defines allowed lifecycle transitions for requests and decisions.

## 2. Lane Definitions

### Lane: STATE_MACHINE_V1 (SPEC_ONLY)
Status: SPEC_ONLY

Rules:
- all transitions must be explicit
- invalid transition -> DENY_DETERMINISM_VIOLATION (treated as structural failure)
- terminal states are final; no post-terminal transitions

This engine does not evaluate policy; it governs lifecycle legality.

Git is law.
