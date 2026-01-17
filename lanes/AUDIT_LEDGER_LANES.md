# AUDIT_LEDGER — LANES (CANONICAL)

Authority Level: Binding Lane Spec  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Role

AUDIT_LEDGER provides append-only custody for decision records.

## 2. Lane Definitions

### Lane: AUDIT_LEDGER_V1 (SPEC_ONLY)
Status: SPEC_ONLY

Rules:
- append-only insertion; updates and deletes forbidden
- each record may include prior_record_hash_sha256 for chain-hash linking
- ledger ordering must be reproducible by deterministic keys (not wall-clock)

Tamper detection:
- replay recomputes hashes and detects mismatch

Git is law.
