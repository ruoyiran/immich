# Testing

## Web

```bash
mise //web:test --run
mise //web:check
```

Use `mise //web:checklist` for the complete module gate.

## Browser E2E

The Playwright suite starts the Web Vite server and mocks API responses. It does not start a database, Docker Compose stack, or real backend.

```bash
mise //e2e:ci-unit
mise //e2e:test
```

Real API, upload, database, pipeline, and compatibility tests belong in the sibling `photo-classifier` repository.

## Mobile

```bash
mise //mobile:test
mise //mobile:analyze
```

Use `mise //mobile:checklist` for the complete module gate. Run focused migration and integration tests for Drift, sync, upload, background, or native changes.

## Machine Learning

```bash
mise //machine-learning:checklist
```

This validates the standalone service, not the current server runtime.
