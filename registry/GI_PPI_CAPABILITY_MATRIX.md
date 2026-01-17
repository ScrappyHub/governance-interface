# GI / PPI — CAPABILITY MATRIX (CANONICAL)

Authority Level: Binding Platform Spec  
Status: BINDING | NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Purpose

Capabilities define what an engine is allowed to do.

Capabilities do not imply intent.
Capabilities do not imply interpretation.
Capabilities are permission surfaces only.

## 2. Global Capabilities (Locked)

CAP_EVALUATE_REQUEST  
CAP_RESOLVE_POLICY_GRAPH  
CAP_ENFORCE_STATE_MACHINE  
CAP_WRITE_DECISION_RECORD  
CAP_HASH_DECISION_RECORD  
CAP_ESCALATE_EXPLICITLY  
CAP_REQUIRE_ATTESTATION  
CAP_REFUSE_DETERMINISTICALLY

## 3. Engine Capability Assignments

| Engine Key | Allowed Capabilities |
|---|---|
| PPI_CORE | CAP_EVALUATE_REQUEST, CAP_REFUSE_DETERMINISTICALLY, CAP_REQUIRE_ATTESTATION |
| POLICY_GRAPH | CAP_RESOLVE_POLICY_GRAPH |
| STATE_MACHINE | CAP_ENFORCE_STATE_MACHINE |
| AUDIT_LEDGER | CAP_WRITE_DECISION_RECORD, CAP_HASH_DECISION_RECORD |
| ESCALATION_GATE | CAP_ESCALATE_EXPLICITLY |

## 4. Prohibition

No engine may claim any capability not explicitly granted here.

Git is law.
