# GI / PPI — CAPABILITY MATRIX (CANONICAL)

Authority Level: Binding Capability Specification  
Status: ✅ LOCKED | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

This file defines all capability keys recognized by GI / PPI.

Capabilities are declarative permissions only.
They do not imply intent, meaning, or execution.

---

## CAPABILITY RULES

1. Capabilities must be explicitly declared.
2. Missing capability => DENY.
3. Capabilities grant eligibility for evaluation, not approval.
4. Capabilities may not be inferred or expanded.

---

## CANONICAL CAPABILITIES

| Capability Key | Description |
|---------------|-------------|
| CAP_PROPOSE_ACTION | Actor may submit an action for evaluation |
| CAP_READ_RESOURCE | Actor may request read access |
| CAP_WRITE_RESOURCE | Actor may request write access |
| CAP_MODIFY_POLICY | Actor may request policy change (requires escalation) |
| CAP_ESCALATE_REQUEST | Actor may request escalation |
| CAP_ATTEST | Actor may provide attestation metadata |

---

## PROHIBITIONS

Capabilities MUST NOT:
- execute actions
- imply trust
- bypass policy
- override denial

Git is law.
