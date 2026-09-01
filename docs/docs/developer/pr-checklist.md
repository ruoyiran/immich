# PR Checklist

Run the checks that match the files you changed. Confirm available task names with `mise tasks ls --all --name-only`.

## Web

- [ ] `mise //web:lint`
- [ ] `mise //web:format`
- [ ] `mise //web:check`
- [ ] `mise //web:test --run`

Use `mise //web:checklist` for the complete Web gate.

## Mobile

- [ ] `mise //mobile:format`
- [ ] `mise //mobile:analyze`
- [ ] `mise //mobile:test`
- [ ] Run the required code generator for OpenAPI, Drift, Pigeon, localization, icons, or splash changes.

Use `mise //mobile:checklist` for the complete Mobile gate.

## Browser E2E

- [ ] `mise //e2e:ci-unit`
- [ ] `mise //e2e:test` when the affected browser flow needs execution

These tests mock API responses and do not validate a real server.

## Machine Learning

- [ ] `mise //machine-learning:checklist`

The package is standalone and is not used by the current `photo-classifier` runtime.

## API contract and SDKs

- [ ] Implement and test server behavior in the sibling `photo-classifier` repository.
- [ ] Update `open-api/immich-openapi-specs.json`.
- [ ] Run `mise //:open-api`.
- [ ] Verify Web and Mobile consumers.

## Documentation and workflows

- [ ] `mise //docs:format`
- [ ] `mise //.github:format` for workflow changes
- [ ] Update redirects when moving or removing public pages.
- [ ] Run `git diff --check` before committing.
