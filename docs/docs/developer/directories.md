---
title: Directories
---

# Repository Folder Structure

| Folder              | Description                                                                     |
| :------------------ | :------------------------------------------------------------------------------ |
| `.github/`          | Client, ML, documentation, and release workflows                                |
| `design/`           | Logos, screenshots, and static design assets                                    |
| `docs/`             | Docusaurus documentation source                                                 |
| `e2e/`              | Playwright browser tests using mocked API responses                             |
| `engineering/`      | Internal engineering notes and architecture decisions                           |
| `i18n/`             | Shared localization sources                                                     |
| `machine-learning/` | Standalone legacy-compatible inference service; not used by the current runtime |
| `mobile/`           | Flutter app and Android/iOS integrations                                        |
| `open-api/`         | Committed OpenAPI snapshot and client generators                                |
| `packages/cli/`     | Command-line API client                                                         |
| `packages/sdk/`     | Generated TypeScript API client                                                 |
| `packages/plugin-*` | Plugin contracts and SDKs                                                       |
| `web/`              | SvelteKit Web client                                                            |

The server is not part of this repository. It lives in the sibling `photo-classifier` repository.
