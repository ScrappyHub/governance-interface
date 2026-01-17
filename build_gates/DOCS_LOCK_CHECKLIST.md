# DOCS LOCK CHECKLIST — GI/PPI (CANONICAL)

Authority Level: Binding Gate  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 0. Rule

No engine may advance from SPEC_ONLY to IMPLEMENTED until this checklist passes.

No runtime code may be treated as authoritative unless the docs layer is locked first.

## 1. Repo Completeness (Pass/Fail)

PASS only if all exist exactly:

- README.md
- .gitignore
- GOVERNANCE_INDEX.md

### Governance
- governance/GI_PPI_GENESIS_LAW.md
- governance/GI_PPI_REFUSAL_SEMANTICS_LAW.md
- governance/GI_PPI_AUDIT_AND_REPLAY_LAW.md
- governance/GI_PPI_ENGINE_EXECUTION_BOUNDARY_LAW.md
- governance/GI_PPI_POLICY_VERSIONING_LAW.md
- governance/GI_PPI_CHANGE_CONTROL_LAW.md

### Registries
- registry/GI_PPI_ENGINE_REGISTRY.md
- registry/GI_PPI_CAPABILITY_MATRIX.md
- registry/GI_PPI_REASON_CODES.md
- registry/GI_PPI_POLICY_REGISTRY.md

### Schemas
- schemas/PPI_REQUEST_V1.schema.json
- schemas/PPI_DECISION_RECORD_V1.schema.json
- schemas/PPI_POLICY_BUNDLE_V1.schema.json
- schemas/PPI_RULE_NODE_V1.schema.json
- schemas/PPI_STATE_MACHINE_V1.schema.json

### Lane Specs
- lanes/PPI_CORE_LANES.md
- lanes/POLICY_GRAPH_LANES.md
- lanes/STATE_MACHINE_LANES.md
- lanes/AUDIT_LEDGER_LANES.md
- lanes/ESCALATION_GATE_LANES.md

### Examples
- examples/POLICY_BUNDLE_V1.example.json
- examples/REQUEST_V1.example.json
- examples/DECISION_RECORD_V1.example.json
- examples/STATE_MACHINE_V1.example.json

## 2. Cross-Reference Integrity (Pass/Fail)

PASS only if:

- GOVERNANCE_INDEX.md links to every file above
- Engine keys referenced in lane specs appear in GI_PPI_ENGINE_REGISTRY.md
- Reason codes referenced anywhere appear in GI_PPI_REASON_CODES.md
- Schemas referenced anywhere exist in /schemas
- Examples exist for every schema and use correct version tags

## 3. Status Discipline (Pass/Fail)

PASS only if:

- All engines remain SPEC_ONLY in GI_PPI_ENGINE_REGISTRY.md
- No file claims “implemented” behavior unless paired with:
  - lane spec declaring deterministic algorithm
  - invariant tests (future phase)
  - and an IMPLEMENTED gate (future phase)

## 4. Final Clause

Docs Lock passing means:
- governance is frozen at the authority level
- implementation becomes execution only

Git is law.
