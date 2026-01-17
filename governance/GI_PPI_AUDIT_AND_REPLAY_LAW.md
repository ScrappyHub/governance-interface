# GI / PPI — AUDIT AND REPLAY LAW (CANONICAL)

Authority Level: Binding Law  
Status: BINDING | NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Decision Records Are Artifacts

Every PPI evaluation produces a decision record.

Decision records are:
append-only
immutable
replay-safe
hashable

## 2. Replay Requirement

Given the same:
request payload
declared context
policy version
engine versions

Re-evaluation must produce the same decision outcome and an equivalent canonical decision record.

## 3. Hashing Requirement

Decision records must be hash-addressable.

At minimum:
canonical JSON serialization
sha256(record)

Hash is a first-class value, not metadata.

## 4. No Mutation

No update path exists for decision records.
No delete path exists for decision records.

If correction is required, it is a new decision record that references the prior record by hash.

## 5. Minimum Audit Surface

A decision record must include:
decision_id
created_at
policy_version
engine_versions
request_hash
decision
reason_codes
rule_path
record_hash_sha256

## 6. Final Clause

Audit is not optional and not bypassable.

Git is law.
