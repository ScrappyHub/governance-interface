# GI / PPI — ENGINE REGISTRY (CANONICAL)

Authority Level: Binding Registry Index  
Status: BINDING | NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Purpose

This file is the authoritative registry of GI/PPI engines.
Anything not listed here does not exist inside GI/PPI.

## 2. Registry Status Model

RESERVED: name exists, not executable  
SPEC_ONLY: contract exists, not executable  
IMPLEMENTED: lane exists + tests exist  
ACTIVE: implemented + determinism + audit + replay proven

## 3. Canonical Engine Family

| Engine Key | Name | Role | Status | Engine Path |
|---|---|---|---|---|
| PPI_CORE | Policy-Bound Processing Core | Deterministic evaluation of requests | SPEC_ONLY | engines/ppi_core/v1/ |
| POLICY_GRAPH | Policy Graph Resolver | Rule storage + resolution + conflict rules | SPEC_ONLY | engines/policy_graph/v1/ |
| STATE_MACHINE | Request Lifecycle State Machine | Formal transitions and terminal states | SPEC_ONLY | engines/state_machine/v1/ |
| AUDIT_LEDGER | Audit Ledger | Append-only decision record custody | SPEC_ONLY | engines/audit_ledger/v1/ |
| ESCALATION_GATE | Escalation Interface | Explicit non-automatic escalation surface | SPEC_ONLY | engines/escalation_gate/v1/ |

## 4. Identity Rule

Engine identity is defined only by this registry.

Folder names, module names, or filenames do not define identity.

## 5. Final Clause

Unregistered engines do not exist. GI/PPI must refuse them.

Git is law.
