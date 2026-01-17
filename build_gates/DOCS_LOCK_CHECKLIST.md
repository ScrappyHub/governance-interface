# DOCS LOCK CHECKLIST — GI/PPI (CANONICAL)

Authority Level: Binding Build Gate  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

No runtime implementation work is permitted until this checklist passes.

## A. Required Files Exist (PASS/FAIL)

PASS requires all of these files to exist:

- GOVERNANCE_INDEX.md
- registry/GI_PPI_ENGINE_REGISTRY.md
- registry/GI_PPI_CAPABILITY_MATRIX.md
- registry/GI_PPI_REASON_CODES.md
- registry/GI_PPI_POLICY_REGISTRY.md

- schemas/PPI_REQUEST_V1.schema.json
- schemas/PPI_DECISION_RECORD_V1.schema.json
- schemas/PPI_POLICY_BUNDLE_V1.schema.json
- schemas/PPI_RULE_NODE_V1.schema.json
- schemas/PPI_STATE_MACHINE_V1.schema.json

- lanes/PPI_CORE_LANES.md
- lanes/POLICY_GRAPH_LANES.md
- lanes/STATE_MACHINE_LANES.md
- lanes/AUDIT_LEDGER_LANES.md
- lanes/ESCALATION_GATE_LANES.md

- examples/POLICY_BUNDLE_V1.example.json
- examples/REQUEST_V1.example.json
- examples/DECISION_RECORD_V1.example.json
- examples/STATE_MACHINE_V1.example.json

- docs/ROADMAP.md
- docs/THREAT_MODEL.md
- docs/GLOSSARY.md

## B. Cross-Reference Integrity (PASS/FAIL)

PASS requires:
- all registry lane spec paths exist
- all schema refs in schemas resolve (local paths present)
- examples correspond to schemas by name and intent

## C. Status Discipline (PASS/FAIL)

PASS requires:
- every engine in registry/GI_PPI_ENGINE_REGISTRY.md is SPEC_ONLY
- no engine is marked IMPLEMENTED or ACTIVE

## D. Amendment Law (PASS/FAIL)

PASS requires:
- any semantic change to schemas, reason codes, capability keys, or lane rules must be done via Git amendment commit

## Outcome

If A–D PASS → Docs Lock is complete.

Only after Docs Lock passes may implementation begin.

Git is law.
