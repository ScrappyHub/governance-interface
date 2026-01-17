# POLICY_GRAPH — LANES (CANONICAL)

Authority Level: Binding Lane Spec  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Role

POLICY_GRAPH resolves a policy bundle into an ordered evaluation graph.

It produces deterministic rule_path outputs used by PPI_CORE.

## 2. Lane Definitions

### Lane: POLICY_GRAPH_V1 (SPEC_ONLY)
Status: SPEC_ONLY

Rules:
- compile policy rules into deterministic order
- conflict handling follows policy_bundle.conflict_mode
- if conflict_mode=DENY_ON_CONFLICT, conflicting matches yield DENY_POLICY_CONFLICT
- if conflict_mode=PRIORITY_ORDER, first rule_key match in priority_order wins
- graph compilation must be stable under canonical serialization

No side effects.

Git is law.
