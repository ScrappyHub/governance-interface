# GI / PPI — CHANGE CONTROL LAW (CANONICAL)

Authority Level: Binding Law  
Status: BINDING | NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. What Requires Change Control

Any change to:
policy language
rule resolution semantics
reason codes
request schema
decision record schema
engine registry statuses
capability matrix

Requires:
explicit commit
version bump where applicable
audit-visible history

## 2. No Silent Semantics

No change may silently alter evaluation outcomes.

Breaking changes require:
new major version of the affected schema or engine lane
explicit migration notes

## 3. Engine Status Rules

RESERVED or SPEC_ONLY engines are non-executable.

IMPLEMENTED requires:
a concrete lane exists in engines/<engine>/<version>/
tests exist in tests/
schema compliance is proven

ACTIVE requires:
determinism proof
audit proof
replay proof

## 4. Final Clause

If it is not in Git, it does not exist.

Git is law.
