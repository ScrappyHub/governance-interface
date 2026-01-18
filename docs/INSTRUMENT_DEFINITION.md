# docs/INSTRUMENT_DEFINITION.md

# COVENANT — GOVERNANCE INSTRUMENT DEFINITION (CANONICAL)

Status: ✅ CANONICAL | ✅ BINDING  
Authority Level: Instrument Definition (Public-Facing, Non-Negotiable)  
Scope: Governance Interface (GI) + Policy Proposal Interface (PPI)  
Effective Date: First Public Covenant Deployment

## 1. What Covenant Is

Covenant is a governance instrument.

It deterministically evaluates **proposals** (declarative requests) against an **active, versioned policy**, and produces an immutable, replayable decision record.

Covenant exists to enforce one thing cleanly:

A request may be evaluated.
A request may be allowed.
A request may be denied.
The outcome is recorded exactly as it happened, under the exact policy that produced it.

Covenant is not a “smart assistant.”
It is not a recommender.
It is not an optimizer.
It is not allowed to infer, guess, interpret, or “help.”

It is an instrument boundary.

## 2. What Covenant Produces

For each evaluation, Covenant produces an immutable ledger entry that binds:

- the proposal content (as received)
- canonical proposal serialization
- proposal hashes (cryptographic)
- the decision (ALLOW or DENY)
- the reason codes
- diagnostics (non-semantic, non-inferential)
- the policy hash that governed the evaluation
- timestamps

This record is append-only, auditable, and replayable.

## 3. What Covenant Refuses to Do

Covenant does not:

- execute work
- call tools
- call networks
- pull external context
- infer missing information
- interpret meaning
- generate intent
- optimize outcomes
- apply sympathy or persuasion
- silently “fix” malformed inputs

If information is missing or the schema is wrong, the result is DENY.

Refusal is not a failure state.
Refusal is a correct, successful outcome.

## 4. Determinism Law

Covenant must be deterministic.

Given identical:

- policy version id
- policy hash
- rule ordering
- proposal content
- canonicalization rules

Covenant must produce:

- identical proposal hashes
- identical decision
- identical reason codes

Any deviation is an integrity violation.

## 5. Schema Gate Law (V0)

All proposals must declare a schema version.

Required:

- schema_version = "GI_PPI_PROPOSAL_V0"

Any other schema_version results in DENY.

Unknown top-level keys are forbidden.

DENY-by-default is mandatory when unknown keys appear.

This is a deliberate integrity posture:
unknown keys represent an ambiguity surface and must not pass.

## 6. Policy Versioning and Non-Mutation

Policies are versioned and hash-addressable.

A policy may be active, draft, or retired.

Key rule:

An evaluation is permanently bound to the policy hash that was active at the time of evaluation.

Changing the active policy does not mutate any previous evaluation.

A new policy requires a new proposal submission to produce a new evaluation.

This is not a UX choice.
It is custody law.

## 7. Replay Law

Any recorded evaluation must be reproducible.

Replay means:

- pull the proposal record
- re-canonicalize using the same canonicalization contract
- re-hash
- re-evaluate under the same policy version and rule ordering

Replay output must match the recorded decision and hashes.

If it does not match, the system is not trustworthy.

## 8. Audit Export Bundle

Covenant supports read-only export bundles.

An export bundle is a JSON object that contains:

- policy version metadata
- policy hashes
- full ruleset for that policy version
- policy rule graph nodes and edges
- reason code catalog
- a page of evaluation ledger entries

Bundles are intended to be:

- portable
- independently inspectable
- hashable as a file artifact
- suitable for institutional review

## 9. Entitlements (Organizations + Credits)

Covenant is an instrument. Access is governed.

The access model is minimal:

- Organization is the contracting identity
- Membership assigns role and authority boundaries
- Credits constrain evaluation volume

This is not “feature gating.”
It is enforceable instrument access control.

The evaluator remains pure.

Entitlement enforcement is expressed via policy and explicit checks, not hidden behavior.

## 10. Integration Model

Covenant is designed to sit between:

- intent (a request)
and
- action (execution in downstream systems)

Covenant does not execute.
It authorizes or denies.

Downstream systems may choose to honor Covenant decisions, but Covenant itself remains an auditable boundary, not an agent.

## 11. Non-Goals

Covenant is not:

- a chatbot
- an LLM
- a reasoning engine
- a workflow agent
- a personalization system
- a data enrichment system

If any integration attempts to make Covenant “smarter,” that integration is out-of-scope and must be separated.

## 12. Final Declaration

Covenant is governance as executable law.

It is deterministic.
It is auditable.
It is replayable.
It is refusal-correct.
It does not infer.
It does not mutate history.

It produces custody-grade decision artifacts that bind proposals to the policies that governed them.

Git is law.
