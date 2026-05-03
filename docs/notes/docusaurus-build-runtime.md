# Docusaurus build runtime notes

Docusaurus builds are executed from the Rails seed/build flow when external sample documents are converted into static HTML.

## Node.js / npm

The build runner invokes `npm run build` under `docusaurus/`, so the execution environment must include Node.js and npm.

For local Docker development, rebuild the app image when npm is missing:

```bash
docker compose down -v --remove-orphans
docker compose build --no-cache app
docker compose run --rm app bash -lc "which node && node -v && which npm && npm -v"
```

Use `docker compose` consistently. Mixing the legacy `docker-compose` command with the v2 `docker compose` command can make it unclear which project/image is being used.

## Kroki generated SVGs

Kroki-generated SVGs should not be treated as source files. They should be generated under the Docusaurus build workspace and then copied into `storage/docs_sites/<version_id>/...` as part of the built site output.

The Docusaurus config supports overriding the plugin static directory with:

```bash
DOCUSAURUS_STATIC_DIR=/path/to/build/workspace/static
```
