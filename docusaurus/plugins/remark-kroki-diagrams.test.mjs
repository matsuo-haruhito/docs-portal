import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

import remarkKrokiDiagrams, {
  collectCodeNodes,
  krokiAssetBasename,
} from './remark-kroki-diagrams.mjs';

test('collectCodeNodes visits nested code blocks', () => {
  const languages = [];

  collectCodeNodes(
    {
      type: 'root',
      children: [
        {type: 'paragraph', children: [{type: 'text', value: 'Hello'}]},
        {
          type: 'container',
          children: [
            {type: 'code', lang: 'plantuml', value: '@startuml\n@enduml'},
            {type: 'code', lang: 'd2', value: 'A -> B'},
          ],
        },
      ],
    },
    (node) => languages.push(node.lang)
  );

  assert.deepEqual(languages, ['plantuml', 'd2']);
});

test('remarkKrokiDiagrams renders supported diagrams into static assets', async () => {
  const staticDir = await fs.mkdtemp(path.join(os.tmpdir(), 'kroki-static-'));
  const calls = [];
  const plugin = remarkKrokiDiagrams({
    endpoint: 'http://kroki.test',
    staticDir,
    fetchImpl: async (url, options) => {
      calls.push({url, options});

      return {
        ok: true,
        text: async () => '<svg>rendered</svg>',
      };
    },
  });

  const tree = {
    type: 'root',
    children: [
      {type: 'code', lang: 'plantuml', value: '@startuml\nAlice -> Bob\n@enduml'},
      {type: 'code', lang: 'ruby', value: 'puts :ok'},
      {type: 'code', lang: 'd2', value: 'A -> B'},
    ],
  };

  await plugin(tree, {path: 'docs/example.md'});

  const plantumlName = krokiAssetBasename('plantuml', '@startuml\nAlice -> Bob\n@enduml');
  const d2Name = krokiAssetBasename('d2', 'A -> B');
  const plantumlSvg = await fs.readFile(path.join(staticDir, 'generated', 'kroki', plantumlName), 'utf8');
  const d2Svg = await fs.readFile(path.join(staticDir, 'generated', 'kroki', d2Name), 'utf8');

  assert.equal(plantumlSvg, '<svg>rendered</svg>');
  assert.equal(d2Svg, '<svg>rendered</svg>');
  assert.equal(calls.length, 2);
  assert.equal(calls[0].url, 'http://kroki.test/plantuml/svg');
  assert.equal(calls[1].url, 'http://kroki.test/d2/svg');
  assert.equal(tree.children[0].type, 'image');
  assert.equal(tree.children[0].url, `/generated/kroki/${plantumlName}`);
  assert.equal(tree.children[1].type, 'code');
  assert.equal(tree.children[2].type, 'image');
});

test('remarkKrokiDiagrams fails when Kroki endpoint is missing for supported diagrams', async () => {
  const plugin = remarkKrokiDiagrams({
    fetchImpl: async () => {
      throw new Error('should not be called');
    },
  });

  await assert.rejects(
    plugin(
      {
        type: 'root',
        children: [{type: 'code', lang: 'puml', value: '@startuml\n@enduml'}],
      },
      {path: 'docs/diagram.md'}
    ),
    /KROKI_ENDPOINT is required/
  );
});
