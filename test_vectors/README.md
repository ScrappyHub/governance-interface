# Covenant Gate Test Vectors v1

Each case file includes:
- base_policy (inline)
- overlay_policy (optional)
- eval_input
- expected:
  - decision
  - reason_codes (exact ordering)
  - matched_rules.allow/deny (sorted)
  - policy_hash, input_hash, evaluation_id

Required suites:
- default deny
- allow match
- deny precedence
- overlay tighten-only (overlay widen forbidden)
- rule reorder invariance (same outputs even if arrays reordered)

Evaluators MUST:
- validate schemas
- derive effective policy deterministically
- evaluate rules sorted by rule.id
- compute hashes on canonical bytes
