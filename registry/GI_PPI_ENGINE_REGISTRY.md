# GI / PPI — ENGINE REGISTRY (CANONICAL)

Authority Level: Binding Engine Registry  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

This registry defines all engines that exist within the Governance Interface (GI) and Policy Proposal Interface (PPI).

If an engine is not listed here, it does not exist.

---

## REGISTRY RULES (ABSOLUTE)

1. Engines exist only if registered here.
2. Engine status is authoritative.
3. No engine may execute unless status = IMPLEMENTED and Docs Lock has passed.
4. SPEC_ONLY engines are non-executable by law.
5. Registry changes require Git-governed amendment.

---

## ENGINE FAMILY (LOCKED)

| Engine Key | Name | Role | Status | Lane Spec |
|-----------|------|------|--------|-----------|
| PPI_CORE | Policy Proposal Evaluator | Deterministic request evaluation | SPEC_ONLY | lanes/PPI_CORE_LANES.md |
| POLICY_GRAPH | Policy Graph Resolver | Rule resolution & conflict handling | SPEC_ONLY | lanes/POLICY_GRAPH_LANES.md |
| STATE_MACHINE | Lifecycle State Engine | Request/decision state transitions | SPEC_ONLY | lanes/STATE_MACHINE_LANES.md |
| AUDIT_LEDGER | Audit Ledger Engine | Append-only decision record custody | SPEC_ONLY | lanes/AUDIT_LEDGER_LANES.md |
| ESCALATION_GATE | Escalation Interface Engine | Explicit non-automatic escalation | SPEC_ONLY | lanes/ESCALATION_GATE_LANES.md |

---

## STATUS DEFINITIONS

- SPEC_ONLY  
  Declared by law. No runtime permitted.

- IMPLEMENTED  
  Deterministic runtime exists. Tests pass. Replay proven.

- ACTIVE  
  IMPLEMENTED + approved by governance amendment.

Git is law.
