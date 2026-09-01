# Database Migrations

This repository no longer contains the server database schema or migration tooling.

The current server uses MySQL and is implemented in the sibling `photo-classifier` repository. Make schema and migration changes there, following its `README.md`, architecture documentation, and tests.

If a database change also changes the public API, update this repository's committed OpenAPI snapshot afterward and regenerate the TypeScript and Dart clients with:

```bash
mise //:open-api
```
