# Code-server with common dev tools

This image includes
- NVM and the latest version of node
- java with quarkus
- mongosh
- docker-cli

pre-installed in the standard [code-server](https://github.com/coder/code-server) image

# Docker Compose Usage:

Start code server alon with latest version (or override version in .env file with environment variable VERSION)
```
docker compose up -d 
```

Start code server with auto-update side container (watch tower)

```
docker compose --profile update up -d 
```
