# GI / PPI — ENGINE EXECUTION BOUNDARY LAW (CANONICAL)

Authority Level: Binding Law  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Purpose

This law defines what GI/PPI engines may and may not do at execution time.

## 2. Hard Prohibitions (Non-Negotiable)

No GI/PPI engine may:

- infer missing context
- enrich context from external sources
- perform network access
- use non-declared state
- learn, adapt, or self-modify
- mutate policy
- silently fallback
- execute domain work on behalf of governed systems

Missing context -> DENY.

## 3. Allowed Behaviors (Strictly Limited)

GI/PPI engines may:

- validate schema
- resolve policy deterministically
- evaluate a request deterministically
- emit a decision record
- hash and store an audit record
- require explicit attestation
- escalate explicitly through the escalation interface

## 4. No Side Effects Beyond Governance

An ALLOW decision does not execute the action.
It authorizes the action for a separate execution system.

GI/PPI is authorization, not actuation.

## 5. Final Clause

Any engine that violates boundaries is invalid and must be disabled by policy.

Git is law.
