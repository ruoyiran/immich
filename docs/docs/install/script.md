---
sidebar_position: 20
---

# Server Installation

This repository no longer ships an installation script, Docker Compose stack, or server image.

Install and deploy the backend from the sibling `photo-classifier` repository. Its `README.md`, `.env.example`, and deployment scripts are the authoritative instructions for the Go server, MySQL database, media paths, Rust pipeline, and external model services.

After the backend is running, point the Web or Mobile client at its URL. The local Web development proxy defaults to `http://127.0.0.1:8080`.
