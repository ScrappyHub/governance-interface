# GI / PPI — POLICY VERSIONING LAW (CANONICAL)

Authority Level: Binding Law  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Purpose

Policy must be versioned, addressable, and replayable.

## 2. Policy Identity

A policy is identified by:

- policy_id
- policy_version
- policy_hash_sha256 (over canonical policy bundle JSON)

Policy text without hash identity has no standing.

## 3. Pinning

Every PPI request must declare policy_version.

If policy_version is missing -> DENY with POLICY_VERSION_MISSING.

If policy is not found -> DENY with POLICY_NOT_FOUND.

## 4. Compatibility

Policy changes that can alter evaluation outcomes require a version bump.

Breaking changes require a major version bump.

## 5. Replay

Any decision record must include:

- policy_version
- policy_hash_sha256

so that the decision can be replayed under the exact policy surface that produced it.

## 6. Final Clause

No “latest policy” resolution is permitted at evaluation time.
Everything is pinned.

Git is law.
