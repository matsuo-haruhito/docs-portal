import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';

const SUPPORTED_LANGUAGES = new Map([
  ['plantuml', 'plantuml'],
  ['puml', 'plantuml'],
  ['d2', 'd2'],
]);

export function krokiAssetBasename(diagramType, source) {
  const digest = crypto
    .createHash('sha1')
    .update(`${diagramType}\0${source}`)
    .digest('hex');

  return `${diagramType}-${digest}.svg`;
}

export function collectCodeNodes(tree, visitor) {
  if (!tree || typeof tree !== 'object') {
    return;
  }

  if (tree.type === 'code') {
    visitor(tree);
  }

  const {children} = tree;
  if (!Array.isArray(children)) {
    return;
  }

  children.forEach((child) => collectCodeNodes(child, visitor));
}

export default function remarkKrokiDiagrams(options = {}) {
  const outputDir = options.outputDir ?? 'generated/kroki';
  const endpoint = options.endpoint ?? process.env.KROKI_ENDPOINT;
  const fetchImpl = options.fetchImpl ?? globalThis.fetch;
  const staticDir = options.staticDir ?? path.join(process.cwd(), 'static');

  return async (tree, file) => {
    const tasks = [];

    collectCodeNodes(tree, (node) => {
      const language = node.lang?.toLowerCase();
      const diagramType = SUPPORTED_LANGUAGES.get(language);
      if (!diagramType) {
        return;
      }

      tasks.push(
        replaceCodeBlockWithDiagram({
          node,
          file,
          diagramType,
          endpoint,
          fetchImpl,
          outputDir,
          staticDir,
        })
      );
    });

    await Promise.all(tasks);
  };
}

async function replaceCodeBlockWithDiagram({
  node,
  file,
  diagramType,
  endpoint,
  fetchImpl,
  outputDir,
  staticDir,
}) {
  if (!endpoint) {
    throw new Error(
      `KROKI_ENDPOINT is required to render ${diagramType} diagrams in ${file?.path ?? 'unknown file'}`
    );
  }

  if (typeof fetchImpl !== 'function') {
    throw new Error('A fetch implementation is required for Kroki diagram rendering');
  }

  const source = node.value ?? '';
  const basename = krokiAssetBasename(diagramType, source);
  const relativeAssetPath = path.posix.join(outputDir, basename);
  const absoluteAssetPath = path.join(staticDir, ...relativeAssetPath.split('/'));
  const renderUrl = `${endpoint.replace(/\/+$/, '')}/${diagramType}/svg`;

  await fs.mkdir(path.dirname(absoluteAssetPath), {recursive: true});

  try {
    await fs.access(absoluteAssetPath);
  } catch {
    let response;

    try {
      response = await fetchImpl(renderUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
        },
        body: source,
      });
    } catch (error) {
      throw new Error(
        [
          `Kroki fetch failed for ${diagramType} in ${file?.path ?? 'unknown file'}.`,
          `Endpoint: ${renderUrl}`,
          'If you use the optional local Kroki compose file, make sure .env includes:',
          '  COMPOSE_FILE=docker-compose.yml:docker-compose.kroki.yml',
          '  KROKI_ENDPOINT=http://kroki:8000',
          `Cause: ${error?.message ?? error}`,
        ].join('\n')
      );
    }

    if (!response.ok) {
      const body = await response.text();
      throw new Error(
        `Kroki rendering failed for ${diagramType} in ${file?.path ?? 'unknown file'}: ${response.status} ${body}`
      );
    }

    const svg = await response.text();
    await fs.writeFile(absoluteAssetPath, svg, 'utf8');
  }

  node.type = 'image';
  node.url = `/${relativeAssetPath}`;
  node.alt = `${diagramType} diagram`;
  delete node.lang;
  delete node.meta;
  delete node.value;
}
