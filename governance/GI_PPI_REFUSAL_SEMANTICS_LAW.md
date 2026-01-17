# GI / PPI — REFUSAL SEMANTICS LAW (CANONICAL)

Authority Level: Binding Law  
Status: BINDING | NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Refusal is Success

Refusal is not an error state.
Refusal is a successful governance outcome.

## 2. When to Refuse

PPI must refuse (DENY) when:
context is missing
context is ambiguous
policy is missing
policy version is not declared
policy evaluation cannot be completed deterministically
rule resolution conflicts without an explicit resolution rule
requested capability exceeds declared capability

## 3. No Soft Fail

GI/PPI forbids:
best-effort permission
partial allow
fallback allow
default allow

Default behavior is DENY unless explicitly allowed.

## 4. Refusal Must Be Explicit

Every refusal must:
emit DENY
emit reason_code(s)
emit rule_path (or explicit “NO_MATCH” path)
produce an immutable decision record

## 5. Refusal Cannot Be Negotiated

PPI does not bargain.
PPI does not persuade.
PPI does not accept “but I need it.”

Escalation is explicit, non-automatic, and does not alter refusal semantics.

## 6. Final Clause

A refusal is a valid artifact and must be preserved.

Git is law.
