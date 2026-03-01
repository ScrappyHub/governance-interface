# Covenant Gate — Policy + Evaluation Spec Pack (v1)

This repository defines the **standalone, deterministic policy + evaluation contract** for Covenant Gate.

It is intended to be:
- **standalone-first** (ship Covenant Gate without ecosystem dependencies)
- **integration-ready later** (ecosystem integration must consume this contract, not rewrite it)

## What’s in here
- Policy Base v1 format
- Policy Overlay v1 format (tighten-only)
- Reason code registry v1
- JSON Schemas
- Example policies and eval I/O
- Test vector format (golden vectors)

## Non-goals (v1)
- No regex
- No network/filesystem side effects in evaluation
- No AI/heuristics in decision-making

## Canonical rule
Evaluator is authoritative. UIs (including chatbot) must *reflect* evaluator output and must not invent decisions.

See: SPEC_POLICY_EVAL_V1.md
