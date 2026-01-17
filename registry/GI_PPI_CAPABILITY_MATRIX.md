# GI / PPI — CAPABILITY MATRIX (CANONICAL)

Authority Level: Binding Capability Registry  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

Capabilities define what a request may propose.
Capabilities do not imply meaning, intent, or approval.

---

## GLOBAL RULES

- Capabilities are declarative only.
- Capabilities are evaluated, not inferred.
- Absence of a required capability -> DENY.
- Capabilities never mutate policy.

---

## CANONICAL CAPABILITIES (V1)

| Capability Key | Description |
|---------------|-------------|
| CAP_PROPOSE_ACTION | Propose a governed action |
| CAP_READ_RESOURCE | Read a governed resource |
| CAP_WRITE_RESOURCE | Write or modify a governed resource |
| CAP_EXECUTE_OPERATION | Execute a controlled operation |
| CAP_REQUEST_ESCALATION | Request escalation to higher authority |
| CAP_REQUIRE_ATTESTATION | Require attestation prior to approval |

---

## CAPABILITY LAW

- Capabilities must be explicitly listed in requests.
- Engines may not add, infer, or enrich capabilities.
- Capability interpretation is policy-defined only.

Git is law.
