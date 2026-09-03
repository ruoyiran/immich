# Queue Schema

Use one JSON document per run:

```json
{
  "source": {
    "sheet_url": "redacted-or-original-url",
    "sheet_id": "a59c79",
    "read_at": "2026-09-02T23:00:00+08:00"
  },
  "test_queue": [
    {
      "case_id": "TC-001",
      "row": 2,
      "title": "Login succeeds",
      "module": "mobile",
      "priority": "P1",
      "preconditions": "",
      "steps": "1. ...",
      "expected": "...",
      "actual": "",
      "status": "pending",
      "evidence": "",
      "notes": "",
      "raw": {}
    }
  ],
  "fix_queue": []
}
```

Statuses:

- `pending`: Not executed yet.
- `running`: Execution is in progress.
- `passed`: Expected behavior was verified.
- `failed`: Behavior did not match expected result and the case was added to the fix queue.
- `blocked`: Environment or data prevented execution; investigate and fix before finalizing.
- `retest-pending`: A fix landed and the original case needs to be rerun.
