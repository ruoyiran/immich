---
sidebar_position: 2
---

# Setup

This repository is the client and client-contract workspace. The server is developed and run from the sibling `photo-classifier` repository.

## Toolchain

Install [mise](https://mise.jdx.dev/installing-mise.html), then run from the repository root:

```bash
mise install
pnpm install --frozen-lockfile
```

List available tasks with:

```bash
mise tasks ls --all --name-only
```

## Web

Start `photo-classifier` according to its README, then run:

```bash
mise //web:start
```

The Web proxy defaults to `http://127.0.0.1:8080`. Override it when necessary:

```bash
IMMICH_SERVER_URL=http://host:port mise //web:start
```

## Mobile

Install Flutter dependencies and start the app with:

```bash
mise //mobile:install
mise //mobile:start
```

Configure the server endpoint in the app to point to `photo-classifier`.

## OpenAPI clients

The committed OpenAPI snapshot is the input for TypeScript and Dart clients:

```bash
mise //:open-api
```

Do not edit generated clients manually.

## Machine Learning

The `machine-learning/` package can still be developed independently:

```bash
mise //machine-learning:install
```

It is not used by the current server runtime unless an explicit integration is added in `photo-classifier`.
