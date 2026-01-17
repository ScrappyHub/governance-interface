# THREAT MODEL — GI/PPI (CANONICAL)

Authority Level: Binding Security Model  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Purpose

GI/PPI exists to prevent policy drift, silent trust escalation, and unverifiable governance outcomes.

The core security property is replayable determinism.

## 2. Assumptions (Explicit)

- Inputs may be adversarial.
- Callers may attempt context spoofing.
- Callers may attempt missing-context coercion.
- Policies may evolve over time unless pinned and hashed.
- Any non-determinism is treated as a failure.

## 3. Primary Threats (What This Must Block)

### T1 — Policy Drift / “Latest Policy” Substitution
Mitigation:
- policy_version is mandatory
- policy_hash_sha256 is recorded in decision record
- replay requires exact policy bundle

### T2 — Context Spoofing / Fabricated Inputs
Mitigation:
- schema validation required
- declared_context is declarative only
- missing required keys -> DENY
- no enrichment from external sources

### T3 — Implicit Trust Escalation
Mitigation:
- no inference
- no convenience fallback
- no “helpful guessing”
- escalation is explicit only

### T4 — Hidden State / Nondeterministic Evaluation
Mitigation:
- evaluator must be pure function over inputs + pinned policy
- no network
- no time-dependent logic except timestamps recorded as data (not control)
- deterministic canonical serialization and hashing

### T5 — Post-hoc Record Tampering
Mitigation:
- decision records are hash-addressed
- audit ledger is append-only
- chain-hash pointer preserves ordering integrity

## 4. Non-Goals (Explicitly Not Solved Here)

GI/PPI does not solve:
- execution safety of downstream action systems
- identity verification (handled by external systems)
- UI/UX behavior or messaging quality
- semantic interpretation or “intent understanding”

GI/PPI is governance boundary, not intelligence.

## 5. Failure Semantics (Critical)

Refusal is a successful outcome.

A denied request is correct behavior when:
- context is missing
- policy is missing or ambiguous
- determinism cannot be proven
- conflict exists without explicit resolution

Git is law.
