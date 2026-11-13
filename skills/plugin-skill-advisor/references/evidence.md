# Profile and feature evidence

Keep user-specific state outside the skill package. Before the first save, obtain permission for the location and fields. Reuse prior permission for the same scope. Preserve existing records; update only affected entries. Do not ask again for facts already provided unless they are ambiguous, stale, or materially consequential.

Minimal profile fields:

```json
{
  "schema_version": 1,
  "additional_spend": {"currency": "USD", "limit": 0},
  "plans": [
    {"product": "exact product name", "tier": "user supplied", "evidence": "user-confirmed", "confirmed_on": "YYYY-MM-DD"}
  ],
  "apps": [],
  "constraints": ["no new paid APIs"]
}
```

Do not populate placeholder values as facts. Unstated budgets remain unknown unless clearly inferred and disclosed from the conversation. Do not collect email addresses, payment details, login artifacts, API keys, account IDs, or browsing history. A plan confirmation is not permission to inspect the account or use its credits.

Evidence card per relevant feature:

```json
{
  "item": "exact item name",
  "feature": "specific requested operation",
  "kind": "skill | plugin | mcp | built-in | local-program",
  "presence": "local-file | explicitly-installed | cache-only | unknown",
  "session_available": "yes | no | unverified",
  "prerequisites": [],
  "processing": "local | external | mixed | unknown",
  "cost": {"status": "unknown", "details": "not yet established"},
  "connection": "unverified",
  "readiness": "unverified",
  "sources": [],
  "checked_at": "ISO-8601 timestamp",
  "check_scope": "metadata only",
  "next_action": "specific remaining verification"
}
```

Use actual values, not pipe-separated examples. Each nontrivial claim needs a source: tool response, local path and field, official URL, or dated user statement. Link to the specific pricing/feature/authentication page for cost claims. Mark discrepancies and unknowns; never convert a marketing description into a passed operational test.

Recheck session exposure and volatile service requirements when recommending. Keep historic test dates instead of silently refreshing their timestamps. Profiles and catalog exports are local user data, not material to bundle into a public release.
