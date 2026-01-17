# GI / PPI — ENGINE REGISTRY (CANONICAL)

Authority Level: Binding Engine Registry  
Status: ✅ LOCKED | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

This registry defines all engines that legally exist inside GI / PPI.

If an engine is not listed here, it does not exist.

---

## REGISTRY RULES (ABSOLUTE)

1. Engines exist only if registered here.
2. Engine identity is defined by:
   - engine_key
   - engine_version
   - lane_spec
3. Engines may not self-register.
4. All engines are deterministic by law.
5. All engines are SPEC_ONLY until explicitly implemented and audited.

---

## CANONICAL ENGINE REGISTRY

| Engine Key | Role | Status | Lane Spec |
|-----------|------|--------|-----------|
| PPI_CORE | Deterministic policy evaluation | SPEC_ONLY | lanes/PPI_CORE_LANES.md |
| POLICY_GRAPH | Policy rule graph resolution | SPEC_ONLY | lanes/POLICY_GRAPH_LANES.md |
| STATE_MACHINE | Lifecycle enforcement | SPEC_ONLY | lanes/STATE_MACHINE_LANES.md |
| AUDIT_LEDGER | Append-only custody | SPEC_ONLY | lanes/AUDIT_LEDGER_LANES.md |
| ESCALATION_GATE | Explicit escalation handling | SPEC_ONLY | lanes/ESCALATION_GATE_LANES.md |

---

## IMPLEMENTATION LAW

No engine may be marked IMPLEMENTED until:
- Docs Lock passes
- Determinism is proven
- Audit replay succeeds

Git is law.
