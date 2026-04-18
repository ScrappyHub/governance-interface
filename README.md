# Covenant Gate

Deterministic governance and policy evaluation engine.

## What it is

Covenant Gate is a local-first policy engine for systems that require:

- deterministic policy evaluation
- explicit allow and deny behavior
- signed policy bundle verification
- auditable receipts and repeatable evidence
- strict machine-readable inputs and outputs

It is designed for environments where governance logic must be inspectable, reproducible, and verifiable.

## What users can do

- evaluate structured policy inputs
- verify signed policy bundles
- run deterministic selftests
- generate reproducible evidence
- integrate governance into systems

## What problem it solves

Replaces scattered governance logic with:

- versioned policy rules
- deterministic evaluation
- explicit allow/deny outcomes
- auditable execution

## Run

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File .\scripts\_RUN_cg_full_green_v1.ps1 `
  -RepoRoot .

## Output

- deterministic receipts
- reproducible transcripts
- explicit PASS / FAIL tokens
