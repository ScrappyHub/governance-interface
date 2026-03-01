# Covenant Gate — Policy + Evaluation Spec v1 (Standalone)

This spec defines:
- Policy Base v1 format
- Policy Overlay v1 format
- Overlay Tighten-Only Law
- Deterministic Evaluation Input/Output contracts
- Reason Code registry
- Determinism + stress test requirements
- Chatbot Adapter Law (non-authoritative UI layer)

## 1. Canonical Determinism Law

Evaluator MUST be deterministic:
- no randomness
- no wall clock, no env reads, no filesystem probing, no network
- same policy + same input => identical output bytes (modulo optional trace which MUST be derivable deterministically)

Default posture: DENY on uncertainty.

## 2. Hashing + IDs

### Canonical JSON bytes
Hashes are SHA-256 over canonical JSON bytes:
- UTF-8 no BOM
- LF only
- keys sorted
- no insignificant whitespace

### policy_hash
policy_hash = SHA-256(canonical_bytes(policy.effective.json))

### input_hash
input_hash = SHA-256(canonical_bytes(eval_input.json))

### evaluation_id
evaluation_id = SHA-256(
  policy_hash + "\n" +
  input_hash + "\n" +
  engine_version
)

engine_version is a stable string: "covenantgate.eval.v1"

## 3. Decision Contract (Evaluator Output)

Evaluator output must include:
- schema: "covenantgate.eval_output.v1"
- decision: "allow" | "deny"
- reason_codes: ordered list of stable reason codes
- policy_hash, input_hash, engine_version, evaluation_id
- matched_rules: { allow: [rule_id...], deny: [rule_id...] } (sorted)
- optional reason_trace (structured) BUT MUST NOT be required to validate decision

Reason codes are part of the truth: they must be stable, ordered, deterministic.

## 4. Policy Model

### 4.1 Policy Base v1
- schema: "covenantgate.policy.base.v1"
- defaults: default_decision MUST be "deny" for v1
- allow_rules: array of allow rules
- deny_rules: array of deny rules

### 4.2 Policy Overlay v1
- schema: "covenantgate.policy.overlay.v1"
Overlay may:
- add deny rules
- add additional constraints
- narrow allow rules
Overlay MUST NOT widen scope relative to base.

### 4.3 Overlay Tighten-Only Law (required)
When deriving effective policy:
- Effective denies = base denies UNION overlay denies
- Effective allows = base allows INTERSECT overlay constraints (overlay can only remove allow outcomes)
- Any attempt by overlay to widen allow beyond base MUST hard-fail policy load:
  reason_code: OVERLAY_WIDEN_FORBIDDEN

## 5. Rule Semantics

### 5.1 Deny precedence
If ANY deny rule matches => decision = "deny".
If no deny matches and >=1 allow rule matches => "allow".
Else => default_decision ("deny").

### 5.2 Rule ordering invariance (required)
Evaluator MUST treat rule evaluation order as:
- sort rules by rule.id ascending (bytewise)

Matched rule lists MUST be sorted ascending by id.

### 5.3 Conditions (deterministic)
Condition node types:
- {"all": [cond...]}  (AND)
- {"any": [cond...]}  (OR)
- {"not": cond}       (NOT)
- {"op": "<op>", "path": "<json_pointer>", ...}

Allowed ops v1 (no regex in v1):
- exists: {"op":"exists","path":"/a/b"}
- eq:     {"op":"eq","path":"/a/b","value":<json>}
- in:     {"op":"in","path":"/a/b","values":[<json>...]}
- starts_with: {"op":"starts_with","path":"/a/b","value":"prefix"}
- contains:    {"op":"contains","path":"/a/b","value":<json>}   (arrays only)
- lt/lte/gt/gte: numeric comparisons (numbers only)

If a path is missing or type mismatch occurs during op evaluation => op returns false.
No implicit conversions.

## 6. Reason Codes

Required core codes:
- DEFAULT_DENY
- INPUT_SCHEMA_INVALID
- POLICY_SCHEMA_INVALID
- OVERLAY_SCHEMA_INVALID
- OVERLAY_WIDEN_FORBIDDEN
- DENY_RULE_MATCH:<rule_id>
- ALLOW_RULE_MATCH:<rule_id>

Ordering:
1) input invalid => deny; begins with INPUT_SCHEMA_INVALID
2) deny matches => DENY_RULE_MATCH:<id> ... (sorted)
3) allow matches and no deny => ALLOW_RULE_MATCH:<id> ... (sorted)
4) nothing => ["DEFAULT_DENY"]

No prose.

## 7. Enforcement Points (Standalone v1)

Must support at least:
- "ingest.packet"
- "policy.update.overlay"
- "eval.request"

## 8. Chatbot Adapter Law

Conversational layer:
- MUST NOT compute allow/deny
- MUST produce structured eval_input.json
- MUST call evaluator
- MUST render decision + reason_codes exactly as returned
- MAY render friendly text by mapping reason_code -> message
- MUST show the same allow/deny as the deterministic evaluator

## 9. Stress Tests (Required for "100% standalone")

Release is 100% only when:
- schema suite passes
- overlay tighten-only suite passes
- determinism suite passes
- reorder invariance suite passes
- tamper suite passes

Test vectors MUST be checked in and must pass in CI.
