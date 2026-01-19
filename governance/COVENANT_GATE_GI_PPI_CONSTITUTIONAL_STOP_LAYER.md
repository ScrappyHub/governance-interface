# GI / PPI — CONSTITUTIONAL STOP LAYER (CANONICAL)

Authority Level: Absolute Stop Authority  
Status: ✅ LOCKED | ✅ NON-OVERRIDABLE  
Effective Date: First Public GI/PPI Deployment

---

## 1. PURPOSE

This document defines absolute conditions under which GI / PPI MUST refuse operation.

No engine, lane, policy, request, or operator may bypass this layer.

If any condition in this file is violated, execution MUST halt.

---

## 2. ABSOLUTE PROHIBITIONS

GI / PPI MUST NOT:

- infer missing context
- enrich requests with external data
- learn, adapt, or modify rules
- optimize for outcomes
- provide advice, interpretation, or intent
- execute real-world actions
- mutate policies at runtime
- accept unverifiable inputs
- bypass determinism
- suppress refusal

Any attempt to do so is a structural violation.

---

## 3. EXECUTION TERMINATION CONDITIONS

GI / PPI MUST immediately terminate evaluation if:

- schemas fail validation
- policy_version is missing or unregistered
- policy_hash_sha256 does not match registry
- required context keys are absent
- an engine attempts side effects
- a lane attempts inference or enrichment
- determinism cannot be guaranteed

Termination produces a DENY decision with reason code:
`DENY_CONSTITUTIONAL_VIOLATION`

---

## 4. REFUSAL AS SUCCESS

Refusal is a correct outcome.

Failure to refuse when required is a system failure.

---

## 5. AMENDMENT

This document may be amended only by:
- explicit Git commit
- audit-visible history
- full registry review

Silent change is forbidden.

Git is law.
