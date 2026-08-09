import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtemp, mkdir, readFile, rm, writeFile} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {createRendererServer, maxConcurrentBuildsFromEnv} from './server.mjs';

test('rejects a blocked source image with 422 before starting Docusaurus', async () => {
  await withArchive({
    'index.md': '# Preview\n\n![payload](./renamed.png)',
    'renamed.png': Buffer.from('icns0000'),
  }, async (archive) => {
    let buildCalls = 0;
    await withServer(async () => {
      buildCalls += 1;
      throw new Error('build must not start');
    }, async (endpoint) => {
      const response = await postArchive(endpoint, archive);
      assert.equal(response.status, 422);
      assert.match((await response.json()).error, /source image format is not allowed: renamed\.png \(ICNS\)/);
      assert.equal(buildCalls, 0);
    });
  });
});

test('rejects excessive archive entries while streaming the listing', async () => {
  const files = Object.fromEntries(
    Array.from({length: 2001}, (_, index) => [`entry-${index}.md`, '']),
  );

  await withArchive(files, async (archive) => {
    let buildCalls = 0;
    await withServer(async () => {
      buildCalls += 1;
    }, async (endpoint) => {
      const response = await postArchive(endpoint, archive);
      assert.equal(response.status, 422);
      assert.match((await response.json()).error, /source file count exceeds 2000/);
      assert.equal(buildCalls, 0);
    });
  });
});

test('starts Docusaurus after a safe source passes preflight', async () => {
  await withArchive({
    'index.md': '# Preview',
    'logo.png': Buffer.from([0x89, 0x50, 0x4e, 0x47]),
  }, async (archive) => {
    let buildCalls = 0;
    await withServer(async (command, args) => {
      buildCalls += 1;
      assert.equal(command, 'npm');
      const outDir = args.at(-1);
      await mkdir(outDir, {recursive: true});
      await writeFile(path.join(outDir, 'index.html'), '<h1>Preview</h1>');
    }, async (endpoint) => {
      const response = await postArchive(endpoint, archive);
      assert.equal(response.status, 200);
      assert.equal(decodeURIComponent(response.headers.get('x-docs-site-path')), 'index');
      assert.ok((await response.arrayBuffer()).byteLength > 0);
      assert.equal(buildCalls, 1);
    });
  });
});

test('limits concurrent builds, returns 429 without queueing, and releases the permit', async () => {
  await withArchive({'index.md': '# Preview'}, async (archive) => {
    let buildCalls = 0;
    let releaseFirstBuild;
    let markFirstBuildStarted;
    const firstBuildCanFinish = new Promise((resolve) => {
      releaseFirstBuild = resolve;
    });
    const firstBuildStarted = new Promise((resolve) => {
      markFirstBuildStarted = resolve;
    });

    await withServer(async (command, args) => {
      buildCalls += 1;
      if (buildCalls === 1) {
        markFirstBuildStarted();
        await firstBuildCanFinish;
      }
      const outDir = args.at(-1);
      await mkdir(outDir, {recursive: true});
      await writeFile(path.join(outDir, 'index.html'), '<h1>Preview</h1>');
    }, async (endpoint) => {
      const firstResponsePromise = postArchive(endpoint, archive);
      await firstBuildStarted;

      const busyResponse = await postArchive(endpoint, archive);
      assert.equal(busyResponse.status, 429);
      assert.match((await busyResponse.json()).error, /renderer is busy/);
      assert.equal(buildCalls, 1);

      releaseFirstBuild();
      const firstResponse = await firstResponsePromise;
      assert.equal(firstResponse.status, 200);
      await firstResponse.arrayBuffer();

      const laterResponse = await postArchive(endpoint, archive);
      assert.equal(laterResponse.status, 200);
      await laterResponse.arrayBuffer();
      assert.equal(buildCalls, 2);
    });
  });
});

test('releases the build permit after a build failure', async () => {
  await withArchive({'index.md': '# Preview'}, async (archive) => {
    let buildCalls = 0;
    await withServer(async (command, args) => {
      buildCalls += 1;
      if (buildCalls === 1) throw new Error('simulated build failure');

      const outDir = args.at(-1);
      await mkdir(outDir, {recursive: true});
      await writeFile(path.join(outDir, 'index.html'), '<h1>Preview</h1>');
    }, async (endpoint) => {
      const failedResponse = await postArchive(endpoint, archive);
      assert.equal(failedResponse.status, 422);
      assert.match((await failedResponse.json()).error, /simulated build failure/);

      const retryResponse = await postArchive(endpoint, archive);
      assert.equal(retryResponse.status, 200);
      await retryResponse.arrayBuffer();
      assert.equal(buildCalls, 2);
    });
  });
});

test('rejects an invalid MAX_CONCURRENT_BUILDS setting', () => {
  assert.throws(
    () => maxConcurrentBuildsFromEnv({MAX_CONCURRENT_BUILDS: '0'}),
    /MAX_CONCURRENT_BUILDS must be a positive integer/,
  );
  assert.throws(
    () => maxConcurrentBuildsFromEnv({MAX_CONCURRENT_BUILDS: '1.5'}),
    /MAX_CONCURRENT_BUILDS must be a positive integer/,
  );
});

async function postArchive(endpoint, archive) {
  return fetch(`${endpoint}/build`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/gzip',
      'Content-Length': String(archive.length),
      'X-Docs-Entry-Path': 'index.md',
    },
    body: archive,
  });
}

async function withServer(buildCommandRunner, callback) {
  const server = createRendererServer({buildCommandRunner});
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });

  try {
    const address = server.address();
    await callback(`http://127.0.0.1:${address.port}`);
  } finally {
    await new Promise((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

async function withArchive(files, callback) {
  const root = await mkdtemp(path.join(os.tmpdir(), 'renderer-server-test-'));
  const sourceDir = path.join(root, 'source');
  const archivePath = path.join(root, 'source.tar.gz');
  await mkdir(sourceDir);

  try {
    for (const [relativePath, content] of Object.entries(files)) {
      const destination = path.join(sourceDir, relativePath);
      await mkdir(path.dirname(destination), {recursive: true});
      await writeFile(destination, content);
    }
    execFileSync('tar', ['-czf', archivePath, '-C', sourceDir, '.']);
    await callback(await readFile(archivePath));
  } finally {
    await rm(root, {recursive: true, force: true});
  }
}
