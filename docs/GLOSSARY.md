# GLOSSARY — GI/PPI (CANONICAL)

Authority Level: Binding Definitions  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## GI (Governance Interface)
The binding law surface that defines what governance is allowed to decide and how.

GI defines constraints. GI does not execute actions.

## PPI (Policy Proposal Interface)
The deterministic evaluation system that takes a request and returns an authorization decision record.

PPI evaluates. PPI does not execute.

## Request
A declarative object describing a proposed action, actor, target, capabilities, and context keys.

Requests must be schema-valid. Missing context may not be inferred.

## Policy Bundle
A versioned, hash-addressable container of rules and conflict resolution mode.

Policies must be pinned by version and recorded by hash for replay.

## Decision Record
The immutable output artifact of evaluation.

Includes:
- decision (ALLOW/DENY/ESCALATE/REQUIRE_ATTESTATION)
- reason codes
- rule path
- hashes required for replay integrity

## Determinism
Identical inputs + identical policy bundle + identical engine version -> identical decision record after canonical normalization.

Any nondeterminism is treated as failure.

## Refusal Semantics
DENY is a successful outcome when governance conditions are not satisfied.

DENY is not an error state.

## Attestation
An explicit, human-provided or system-provided declaration required to proceed.

Attestation is never implicit and never inferred.

## Escalation
An explicit governance path to a higher authority.
Escalation does not mutate policy and produces a new decision record.

## Capability
A named permission surface used to express what a request seeks to do.
Capabilities do not imply meaning or intent.

## Rule Path
A deterministic trace identifier for which rule(s) produced the decision.

## SPEC_ONLY
Declared in Git as allowed/defined, but not yet implemented in runtime.

## IMPLEMENTED
A status allowed only after:
- deterministic runtime exists
- tests prove replay
- audit hashing stability is proven
- registry is amended with Git trace

Git is law.
