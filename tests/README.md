# Tests (Canonical)

This repo treats determinism and replay as first-class.

Minimum test categories to create before any engine becomes IMPLEMENTED:

1. Schema compliance tests (request + decision record)
2. Determinism tests (same inputs -> same output)
3. Replay tests (same request/policy -> same decision)
4. Refusal tests (missing context -> DENY with correct reason codes)
5. No-fallback tests (no implicit allow)

An engine lane cannot be marked IMPLEMENTED until tests exist.

Git is law.
