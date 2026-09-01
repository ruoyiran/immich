---
sidebar_position: 95
---

# Upgrading

This repository ships the Immich Web and Mobile clients, generated SDKs, and the committed OpenAPI contract. It does not build or publish the application server.

Upgrade the backend from the sibling `photo-classifier` repository and follow that repository's README for image tags, database changes, rollback constraints, and deployment commands. The former Immich Docker Compose stack, `IMMICH_VERSION` server image setting, PostgreSQL migrations, and server downgrade guidance do not apply here.

For client updates:

1. Review changes to `open-api/immich-openapi-specs.json` and regenerate clients with `mise //:open-api` when the contract changes.
2. Reinstall JavaScript dependencies with `pnpm install --frozen-lockfile`.
3. Run the relevant checks from the [testing guide](../developer/testing.md).
4. Build and deploy Web or Mobile through its normal client release process.

Keep the deployed clients and `photo-classifier` on API-compatible revisions. Backend compatibility and migration sequencing are owned by `photo-classifier`.
