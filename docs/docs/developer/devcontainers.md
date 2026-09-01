---
title: Dev Containers
sidebar_position: 3
---

# Development Containers

This repository does not currently ship a Dev Container configuration. The previous configuration depended on the removed in-repository server and Docker Compose stack.

Install the required tools with `mise`, or use your own container environment:

```bash
mise install
pnpm install --frozen-lockfile
```

For Web development that needs a real backend, start the sibling `photo-classifier` server separately. Its default URL is `http://127.0.0.1:8080`.

Use the module-specific commands in [Setup](./setup.md) and [Testing](./testing.md) after the toolchain is installed.
