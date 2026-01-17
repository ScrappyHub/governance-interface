# GI / PPI — REASON CODES (CANONICAL V1)

Authority Level: Binding Spec  
Status: BINDING | NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Purpose

Reason codes are stable, machine-readable explanations for ALLOW/DENY/ESCALATE/REQUIRE_ATTESTATION.

They are not user-facing prose.
They are audit primitives.

## 2. Canonical Codes

CTX_MISSING  
CTX_AMBIGUOUS  
POLICY_VERSION_MISSING  
POLICY_NOT_FOUND  
POLICY_CONFLICT_NO_RESOLUTION  
RULE_NO_MATCH  
CAPABILITY_EXCEEDED  
ATTESTATION_REQUIRED  
ENGINE_VERSION_MISMATCH  
NON_DETERMINISTIC_EVAL_FORBIDDEN  
INVALID_REQUEST_SCHEMA  
INTERNAL_EVAL_ERROR_DENY

## 3. Usage

At least one reason code must be present for:
DENY
ESCALATE
REQUIRE_ATTESTATION

ALLOW may include reason codes but is not required.

Git is law.
