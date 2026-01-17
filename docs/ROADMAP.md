# ROADMAP — GI/PPI (CANONICAL)

Authority Level: Binding Project Roadmap  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Principle

This repo is Git-governed law first.

Implementation is forbidden until Docs Lock passes.

## 2. Phases (Locked)

### Phase 0 — Docs Lock (CURRENT)
Deliverables:
- All files required by build_gates/DOCS_LOCK_CHECKLIST.md exist
- All cross-references resolve
- All engines remain SPEC_ONLY

Exit Criteria:
- DOCS_LOCK_CHECKLIST.md passes

### Phase 1 — Minimal Deterministic Evaluator (PPI_CORE_V1)
Deliverables:
- Deterministic evaluation of PPI_REQUEST_V1 against PPI_POLICY_BUNDLE_V1
- Produces PPI_DECISION_RECORD_V1
- No enrichment, no inference, no hidden state
- Missing context -> DENY
- Conflict -> DENY unless explicit priority resolves

Exit Criteria:
- Golden tests prove deterministic replay
- Decision record hashing is stable under canonical serialization
- Policy version pinning is enforced

### Phase 2 — Audit Ledger (AUDIT_LEDGER_V1)
Deliverables:
- Append-only ledger interface
- Chain-hash linkage (prior_record_hash_sha256)
- Tamper detection by replay

Exit Criteria:
- Insert-only invariant proven by tests
- Replay produces identical hashes

### Phase 3 — Escalation Gate (ESCALATION_GATE_V1)
Deliverables:
- Explicit escalation request/response schema
- Escalation produces a new decision record
- No policy mutation

Exit Criteria:
- Escalation path is deterministic
- Escalation is never implicit

### Phase 4 — Policy Graph Compiler (POLICY_GRAPH_V1)
Deliverables:
- Deterministic compilation of policy bundles into a resolved rule graph
- Explicit rule_path emission

Exit Criteria:
- Graph compilation is stable and reproducible
- Conflicts resolve only per policy conflict rules

### Phase 5 — State Machine Enforcement (STATE_MACHINE_V1)
Deliverables:
- Lifecycle transitions enforced
- Terminal states required
- No ambiguous transitions

Exit Criteria:
- Invalid transitions hard-deny
- Decision records show state transitions deterministically

## 3. Implementation Status Rule

No engine may be marked IMPLEMENTED in registry/GI_PPI_ENGINE_REGISTRY.md unless:
- a corresponding engine lane exists
- tests exist and pass
- deterministic replay is proven
- audit record hashing is proven stable

Git is law.
