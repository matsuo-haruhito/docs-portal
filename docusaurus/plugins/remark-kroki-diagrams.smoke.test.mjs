import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import remarkKrokiDiagrams, {krokiAssetBasename} from './remark-kroki-diagrams.mjs';

const PLANTUML_SOURCE = `@startuml
Alice -> Bob: hello
@enduml`;

test('renders a PlantUML code block into a generated Kroki SVG asset', async () => {
  const staticDir = await fs.mkdtemp(path.join(os.tmpdir(), 'docs-portal-kroki-smoke-'));

  try {
    const calls = [];
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" data-smoke="plantuml"></svg>';
    const tree = {
      type: 'root',
      children: [
        {
          type: 'code',
          lang: 'plantuml',
          value: PLANTUML_SOURCE,
        },
      ],
    };

    const transform = remarkKrokiDiagrams({
      endpoint: 'http://kroki:8000/',
      outputDir: 'generated/kroki',
      staticDir,
      fetchImpl: async (url, init) => {
        calls.push({url, init});
        return new Response(svg, {status: 200});
      },
    });

    await transform(tree, {path: 'docs/kroki-smoke.md'});

    const basename = krokiAssetBasename('plantuml', PLANTUML_SOURCE);
    const assetPath = path.join(staticDir, 'generated', 'kroki', basename);

    assert.equal(calls.length, 1);
    assert.equal(calls[0].url, 'http://kroki:8000/plantuml/svg');
    assert.equal(calls[0].init.method, 'POST');
    assert.equal(calls[0].init.headers['Content-Type'], 'text/plain; charset=utf-8');
    assert.equal(calls[0].init.body, PLANTUML_SOURCE);
    assert.equal(await fs.readFile(assetPath, 'utf8'), svg);

    assert.deepEqual(tree.children[0], {
      type: 'image',
      url: `/generated/kroki/${basename}`,
      alt: 'plantuml diagram',
    });
  } finally {
    await fs.rm(staticDir, {recursive: true, force: true});
  }
});

test('fails clearly when a diagram block is present but KROKI_ENDPOINT is unset', async () => {
  const tree = {
    type: 'root',
    children: [
      {
        type: 'code',
        lang: 'd2',
        value: 'source -> target',
      },
    ],
  };
  const transform = remarkKrokiDiagrams({endpoint: ''});

  await assert.rejects(
    transform(tree, {path: 'docs/no-kroki.md'}),
    /KROKI_ENDPOINT is required to render d2 diagrams in docs\/no-kroki\.md/
  );
});
