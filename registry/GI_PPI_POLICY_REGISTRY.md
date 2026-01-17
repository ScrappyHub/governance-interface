# GI / PPI — POLICY REGISTRY (CANONICAL)

Authority Level: Binding Registry Index  
Status: ✅ BINDING | ✅ NON-OPTIONAL  
Effective Date: First Public GI/PPI Deployment

## 1. Purpose

This file defines which policy bundles are recognized by GI/PPI.

If a policy bundle is not registered here, it does not exist inside GI/PPI.

## 2. Policy Registry Table

| policy_id | status | description | bundle_schema | example_path |
|---|---|---|---|---|
| GI_PPI_BASELINE | SPEC_ONLY | Baseline governance policy surface for GI/PPI | schemas/PPI_POLICY_BUNDLE_V1.schema.json | examples/POLICY_BUNDLE_V1.example.json |

Status meanings:
- RESERVED: name exists, not usable
- SPEC_ONLY: schema exists, not enforced by runtime yet
- ACTIVE: enforced by runtime evaluator (future phase)

## 3. Final Clause

Runtime may evaluate only policies registered here.

Git is law.
