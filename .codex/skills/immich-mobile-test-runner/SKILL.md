---
name: immich-mobile-test-runner
description: Run Immich mobile regression or acceptance test cases from a Feishu/Lark Sheet on a simulator, with Lark progress updates, safe database backup rules, test and fix queues, worktree-based bug fixes, server redeploy/retest handling, and final verification.
---

# Immich Mobile Test Runner

## Overview

Use this skill to execute Immich mobile test cases sourced from a Feishu Sheet. Keep testing moving by maintaining a test queue and a fix queue: record failing cases, continue the remaining cases, then fix and retest failures in isolated worktrees.

## Start Checklist

1. Read the root `AGENTS.md`, `engineering/README.md`, and any subtree `AGENTS.md` before editing files in that subtree.
2. Run `git status --short` before edits. Preserve unrelated user changes.
3. Use `lark-cli sheets +workbook-info` on the user-provided sheet URL, then read the target sheet by id or title using `+table-get` or `+csv-get`.
4. Send progress updates to the requested Lark chat with `lark-cli im +messages-send --as bot --chat-id <chat_id> --markdown $'...'`. Use real line breaks via shell `$'...'`; do not send literal `\n` text.
5. Store transient queue files, logs, screenshots, and database backups outside tracked source unless the user asks to keep them. Use names that include the date and case id.

## Queue Workflow

1. Normalize the sheet into a queue with `scripts/extract_cases.py`.
2. Treat every non-empty row as a test case unless the sheet explicitly marks it out of scope. Do not skip cases silently.
3. For each case, record: case id, title, source row, prerequisites, steps, expected result, actual result, status, evidence path, and notes.
4. When a case fails, add it to the fix queue and immediately continue the next test case.
5. After the test queue is exhausted, process the fix queue one case at a time.
6. If a case appears impossible to execute, investigate why, record the blocker, fix environment/data/code as needed, and retest. Mark it untestable only when the root cause is external and cannot be changed locally.

## Simulator And Login

- Prefer the already booted iOS simulator when available. If no simulator is booted, ask the user to boot one or confirm a simulator choice before launching.
- Use the repository's existing mobile build and test commands from `mise tasks ls --all --name-only`, `mobile/mise.toml`, or `mobile/pubspec.yaml`.
- For app login, inspect local database/configuration records only as needed. Never print passwords, tokens, cookies, or secrets in chat, logs, Lark messages, commits, or screenshots.
- Prefer creating a disposable test user when the server supports it. If using an existing user, redact credentials and restore any modified profile/data state.

## Android Media Fixtures

- For Android emulator cases that read local media, push fixtures into `/sdcard/DCIM/...` or `/sdcard/Pictures/...`, trigger MediaScanner, then verify both the file path and the expected display name before running the case.
- For single-case `flutter test` runs, pass dart-defines for the exact fixture names that exist on the device. Do not rely on default fixture names when timestamped media was generated during the run.
- Derive the installed package id from the APK or `adb shell pm list packages | grep immich`; debug builds commonly use `app.alextran.immich.debug`, not the release package id.
- After Flutter installs the app, grant media permissions to the actual package id before the test syncs local assets: `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`, `ACCESS_MEDIA_LOCATION`, and `POST_NOTIFICATIONS` when declared. A host harness may watch for the install log line and run `adb shell pm grant ...` plus `cmd appops set ... allow` in a retry loop.
- If `_waitForLocalAssetByName` fails with an empty `saw` list, first check app installation, runtime media permissions, MediaStore indexing, and fixture-name dart-defines before changing test assertions.
- Video upload and resumable upload cases require `ACCESS_MEDIA_LOCATION`; without it, checksum calculation may fail while reading the original asset.

## Database Safety

- Before any delete, destructive update, migration, fixture reset, or manual correction in a database, create a backup first.
- Identify whether the relevant database lives in this repo or in `../photo-classifier`; server persistence is normally owned by `../photo-classifier`.
- Use native backup tools for the database engine when available. Record the backup path and timestamp, but do not expose credentials.
- If database data is incorrect, correct the minimum necessary records, keep a before/after note, and rerun the affected case.
- Never delete uploads, generated assets, or user data without a verified backup and a restore plan.

## Fix Queue Workflow

1. Create a dedicated worktree and branch for each failing case, for example `.worktrees/fix-<case-slug>` on `codex/fix-<case-slug>`.
2. If the fix is client-side, edit only the affected Immich subtree and run focused tests/formatters.
3. If the fix touches server behavior, make the server change in `../photo-classifier`, run its relevant tests, redeploy/restart the service, then retest the mobile case.
4. If the server API contract changes, update this repo's OpenAPI snapshot and regenerate consumers before retesting.
5. After retest passes, merge the fix branch back to `main` as requested, then remove the worktree and branch.
6. Keep each fix branch scoped to one failing case unless multiple failures share the same confirmed root cause.

## Progress Updates

Send concise Lark Markdown updates at these points:

- Start of run: queue source, target simulator, and safety stance.
- After reading the sheet: total cases and detected columns.
- Every few cases or every notable state change: current case, passed/failed/blocked counts, and next action.
- When a case fails: case id/title, visible symptom, and that it was added to the fix queue.
- Before and after a database backup or server redeploy, with secrets redacted.
- End of run: total passed, fixed, failed, blocked, remaining risks, and evidence paths.

## Verification

- Run the narrowest relevant test for each fix, plus simulator retest of the original failed case.
- Before declaring completion, run formatting/checks for all changed files and `git diff --check`.
- If tests cannot run, state exactly which command failed and why.

## Resources

- `scripts/extract_cases.py`: Convert `lark-cli sheets +table-get` or `+csv-get` JSON output into a normalized queue JSON.
- `references/queue-schema.md`: Queue artifact fields and status meanings.
