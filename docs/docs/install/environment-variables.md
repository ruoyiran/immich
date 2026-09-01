---
sidebar_position: 90
---

# Environment Variables

The server is maintained in the sibling `photo-classifier` repository. Its `PC_*` runtime, database, media, model-service, and deployment variables are documented in that repository's `README.md` and `.env.example`.

## General

Legacy `IMMICH_*` server settings are not consumed by the current backend. Use the `PC_*` settings documented by `photo-classifier`.

## Database

MySQL connection and migration settings belong to `photo-classifier`; this client repository has no database runtime.

## Prometheus

Metrics configuration is owned by the deployed backend and is not configured from this repository.

## Web development

| Variable                 | Description                                        | Default                 |
| :----------------------- | :------------------------------------------------- | :---------------------- |
| `IMMICH_SERVER_URL`      | Backend target used by the Vite development proxy  | `http://127.0.0.1:8080` |
| `PUBLIC_IMMICH_BUY_HOST` | Optional purchase-host override used at build time | Project default         |
| `PUBLIC_IMMICH_PAY_HOST` | Optional payment-host override used at build time  | Project default         |
| `BUILD_STATS`            | Enables the Vite bundle visualizer when set        | Disabled                |

## Browser E2E

| Variable                       | Description                                |
| :----------------------------- | :----------------------------------------- |
| `PLAYWRIGHT_BASE_URL`          | Browser-test base URL                      |
| `PLAYWRIGHT_HOST`              | Host used by the local Vite test server    |
| `PLAYWRIGHT_DISABLE_WEBSERVER` | Reuse an already-running Web server        |
| `PLAYWRIGHT_SLOW_MO`           | Adds a delay between Playwright operations |

## Standalone machine learning

The retained `machine-learning/` package reads `MACHINE_LEARNING_*` settings defined in `machine-learning/immich_ml/config.py`. This service is not part of the current `photo-classifier` runtime unless an explicit integration is configured there.
