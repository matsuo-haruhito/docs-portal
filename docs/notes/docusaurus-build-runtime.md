# Docusaurus build runtime notes

Docusaurus builds are executed in two paths:

- Rails seed/build flow for external sample documents
- Docusaurus renderer service for manual Markdown/MDX upload previews

## Node.js / npm

The seed build runner invokes `npm run build` under `docusaurus/`, so the execution environment must include Node.js and npm.

For local Docker development, rebuild the app image when npm is missing:

```bash
docker compose down -v --remove-orphans
docker compose build --no-cache app
docker compose run --rm app bash -lc "which node && node -v && which npm && npm -v"
```

Use `docker compose` consistently. Mixing the legacy `docker-compose` command with the v2 `docker compose` command can make it unclear which project/image is being used.

## Manual upload preview renderer

Manual Markdown/MDX uploads do not render HTML inside the Rails request. `ManualDocumentUpload` stores the draft `DocumentVersion` and enqueues `DocusaurusPreviewBuildJob`.

The job sends a `tar.gz` archive of the version's document files to the internal Docusaurus renderer API. The renderer builds with the repo-local `docusaurus/` configuration and returns a build artifact archive. Rails then expands the artifact under `storage/docs_sites/<version_id>/...` and updates `markdown_entry_path` / `site_build_path`.

`DocusaurusPreviewBuildJob` treats `.md`, `.markdown`, and `.mdx` as renderer targets. Non-Markdown versions, such as PDF or Office uploads, skip the renderer path and continue to use file viewers / side-by-side review.

For local development, enable the renderer compose file, and include Kroki when PlantUML / D2 diagrams should be rendered:

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.kroki.yml:docker-compose.docusaurus.yml
DOCUSAURUS_RENDERER_ENDPOINT=http://docusaurus:3000
KROKI_ENDPOINT=http://kroki:8000
```

The renderer container is built from local repository code rather than a generic public image because it depends on the repo-local Docusaurus config and `remark-kroki-diagrams` plugin.

The renderer has bounded input, output, and execution time. Tune these only when preview builds need larger document bundles:

```bash
DOCUSAURUS_RENDERER_MAX_UPLOAD_BYTES=20971520
DOCUSAURUS_RENDERER_MAX_OUTPUT_BYTES=52428800
DOCUSAURUS_RENDERER_BUILD_TIMEOUT_MS=60000
```

## Path safety and artifact lifecycle

Preview build inputs and outputs intentionally allow paths that normalize safely inside the site tree, such as `docs/../docs/guide.md`, while rejecting traversal, absolute, drive-letter, and NUL-containing paths.

The Rails side applies this boundary in three places:

- `DocusaurusPreviewArchiveBuilder` normalizes version file names before packing the source archive.
- `DocusaurusRendererClient` validates the renderer's `X-Docs-Site-Path` response header before installing the returned artifact.
- `DocusaurusPreviewArtifactInstaller` validates tar entries and checks that the expected entry HTML exists before replacing the current site directory.

Temporary archives returned from the renderer are closed by `DocusaurusPreviewBuildJob` after installation, including success and error paths.

## Kroki generated SVGs

Kroki-generated SVGs should not be treated as source files. They should be generated under the Docusaurus build workspace and then copied into `storage/docs_sites/<version_id>/...` as part of the built site output.

The Docusaurus config supports overriding the build workspace static directory with:

```bash
DOCUSAURUS_STATIC_DIR=/path/to/build/workspace/static
```

This value is used both by `remark-kroki-diagrams` as the SVG output directory and by Docusaurus `staticDirectories`, so generated SVGs are included in the returned build artifact without a separate HTML post-process step.