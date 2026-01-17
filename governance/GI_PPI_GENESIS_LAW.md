# GI / PPI — GENESIS LAW (CANONICAL)

Authority Level: Binding Constitutional Law  
Status: BINDING | NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Definition

GI/PPI is a governance execution substrate.

GI defines and enforces law.
PPI evaluates proposed actions against law.

Neither GI nor PPI performs domain work.

GI/PPI decides whether an action may occur. It does not decide what the action means.

## 2. Non-Identity

GI/PPI is not:
AI, intelligence, learning, reasoning, optimization, interpretation, intent inference, convenience tooling.

Any system that does those things must be governed by GI/PPI and remains subordinate to it.

## 3. Core Principle

No computation, interaction, or execution is permitted unless explicitly authorized by versioned, auditable governance rules.

Refusal is a successful outcome.

## 4. Determinism (Non-Negotiable)

Evaluation is deterministic.

Given:
the same request
the same declared context
the same policy version
the same engine versions

The decision record must be reproducible.

GI/PPI forbids:
hidden state
learning
self-modification
silent fallback
implicit permission
policy guessing

Missing context results in DENY.

## 5. Inputs Are Declarative Only

GI/PPI accepts only declared inputs and declared context.

GI/PPI does not infer.
GI/PPI does not enrich.
GI/PPI does not “helpfully guess.”

## 6. Outputs Are Canonical

PPI outputs one of:
ALLOW
DENY
ESCALATE
REQUIRE_ATTESTATION

Every output must be accompanied by a decision record that includes:
policy_version
engine_versions
rule_path
reason_code(s)
timestamp
hashable canonical payload

## 7. Separation of Roles (Hard Boundary)

GI defines policy, versions policy, and publishes policy.

PPI evaluates requests against published policy.

PPI may not modify policy.
PPI may not escalate automatically.
PPI may not grant permission based on sympathy, convenience, or probability.

## 8. Audit Is Not Optional

Every evaluation produces an append-only decision record.

Audit is treated as a first-class artifact.

No path exists that allows:
evaluation without record
record mutation
record deletion

## 9. Scope Boundary

This repo does not reference:
CORE
ROOTED
physics
measurement
meaning

Those systems may be governed by GI/PPI later. They do not define GI/PPI.

## 10. Final Clause

If a behavior is not written into binding law and registries in Git, it has no standing.

Git is law.
