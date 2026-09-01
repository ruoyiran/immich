# Troubleshooting

:::tip
A great option to get assistance with troubleshooting is to join our [Discord](https://discord.immich.app) server, where we have a dedicated channel for `#contributing`.
:::

## Client development

This repository no longer contains the application server or its Docker Compose development environment. Run the sibling `photo-classifier` repository separately and follow its README for backend, database, storage, and deployment troubleshooting.

The Web development proxy uses `http://127.0.0.1:8080` by default. Set `IMMICH_SERVER_URL` when the external server is listening elsewhere, and confirm that its `/api/server/config` endpoint is reachable before debugging client behavior.

## Running on Windows

Use the setup supported by the component you are running. For the external backend, consult `photo-classifier`; for Web and Mobile client tooling, follow this repository's [development setup](./setup.md).
