import {createServer} from 'node:http';
import {mkdtemp, mkdir, rm, readFile, stat} from 'node:fs/promises';
import {createWriteStream} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {pipeline} from 'node:stream/promises';
import {spawn} from 'node:child_process';

const PORT = Number(process.env.PORT || 3000);
const MAX_UPLOAD_BYTES = Number(process.env.MAX_UPLOAD_BYTES || 20 * 1024 * 1024);
const MAX_OUTPUT_BYTES = Number(process.env.MAX_OUTPUT_BYTES || 50 * 1024 * 1024);
const BUILD_TIMEOUT_MS = Number(process.env.BUILD_TIMEOUT_MS || 60_000);
const REPO_ROOT = process.env.REPO_ROOT || '/app';
const DOCUSAURUS_DIR = path.join(REPO_ROOT, 'docusaurus');

const server = createServer(async (request, response) => {
  if (request.method === 'GET' && request.url === '/health') {
    sendJson(response, 200, {ok: true});
    return;
  }

  if (request.method !== 'POST' || request.url !== '/build') {
    sendJson(response, 404, {ok: false, error: 'not found'});
    return;
  }

  let workRoot;
  try {
    const entryPath = safeRelativeHeader(request.headers['x-docs-entry-path'] || 'index.md');
    workRoot = await mkdtemp(path.join(os.tmpdir(), 'docusaurus-render-'));
    const sourceArchive = path.join(workRoot, 'source.tar.gz');
    const sourceDir = path.join(workRoot, 'docs-src');
    const staticDir = path.join(workRoot, 'static');
    const buildDir = path.join(workRoot, 'build');
    const outputArchive = path.join(workRoot, 'build.tar.gz');
    const docusaurusStaticDir = path.relative(DOCUSAURUS_DIR, staticDir);

    await writeBoundedRequestBody(request, sourceArchive);
    await mkdir(sourceDir, {recursive: true});
    await mkdir(staticDir, {recursive: true});
    await validateArchiveEntries(sourceArchive);
    await extractArchive(sourceArchive, sourceDir);

    await runCommand('npm', ['run', 'build', '--', '--out-dir', buildDir], {
      cwd: DOCUSAURUS_DIR,
      env: {
        ...process.env,
        DOCUSAURUS_DOCS_PATH: sourceDir,
        DOCUSAURUS_STATIC_DIR: docusaurusStaticDir,
      },
      timeoutMs: BUILD_TIMEOUT_MS,
    });

    const sitePath = normalizeSitePagePath(entryPath);
    await createArchive(outputArchive, buildDir);
    await ensureMaxFileSize(outputArchive, MAX_OUTPUT_BYTES, 'build output');
    const archive = await readFile(outputArchive);

    response.writeHead(200, {
      'Content-Type': 'application/gzip',
      'X-Docs-Site-Path': sitePath,
      'Content-Length': archive.length,
    });
    response.end(archive);
  } catch (error) {
    sendJson(response, 422, {
      ok: false,
      error: error?.message || String(error),
    });
  } finally {
    if (workRoot) {
      await rm(workRoot, {recursive: true, force: true});
    }
  }
});

server.listen(PORT, () => {
  console.log(`Docusaurus renderer listening on ${PORT}`);
});

async function writeBoundedRequestBody(request, destination) {
  const expectedLength = Number(request.headers['content-length'] || 0);
  if (expectedLength > MAX_UPLOAD_BYTES) {
    throw new Error(`upload is too large: ${expectedLength} bytes`);
  }

  let received = 0;
  request.on('data', (chunk) => {
    received += chunk.length;
    if (received > MAX_UPLOAD_BYTES) {
      request.destroy(new Error(`upload exceeded ${MAX_UPLOAD_BYTES} bytes`));
    }
  });

  await pipeline(request, createWriteStream(destination));
}

async function ensureMaxFileSize(filePath, maxBytes, label) {
  const info = await stat(filePath);
  if (info.size > maxBytes) {
    throw new Error(`${label} is too large: ${info.size} bytes`);
  }
}

async function validateArchiveEntries(archivePath) {
  const listing = await captureCommand('tar', ['-tzf', archivePath], {timeoutMs: BUILD_TIMEOUT_MS});
  listing.split('\n').filter(Boolean).forEach((entryName) => {
    safeArchiveEntryName(entryName);
  });
}

async function extractArchive(archivePath, destination) {
  await runCommand('tar', ['--no-same-owner', '--no-same-permissions', '-xzf', archivePath, '-C', destination], {timeoutMs: BUILD_TIMEOUT_MS});
}

async function createArchive(archivePath, sourceDir) {
  await runCommand('tar', ['-czf', archivePath, '-C', sourceDir, '.'], {timeoutMs: BUILD_TIMEOUT_MS});
}

async function captureCommand(command, args, options = {}) {
  const stdoutChunks = [];
  await runCommand(command, args, {
    ...options,
    onStdout: (chunk) => stdoutChunks.push(chunk),
  });
  return Buffer.concat(stdoutChunks).toString('utf8');
}

async function runCommand(command, args, options = {}) {
  const stdoutChunks = [];
  const stderrChunks = [];
  const child = spawn(command, args, {
    cwd: options.cwd,
    env: options.env || process.env,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  const timer = setTimeout(() => {
    child.kill('SIGKILL');
  }, options.timeoutMs || BUILD_TIMEOUT_MS);

  child.stdout.on('data', (chunk) => {
    stdoutChunks.push(chunk);
    options.onStdout?.(chunk);
  });
  child.stderr.on('data', (chunk) => stderrChunks.push(chunk));

  const exitCode = await new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('close', resolve);
  }).finally(() => clearTimeout(timer));

  if (exitCode !== 0) {
    const stdout = Buffer.concat(stdoutChunks).toString('utf8').slice(-4000);
    const stderr = Buffer.concat(stderrChunks).toString('utf8').slice(-4000);
    throw new Error([`${command} ${args.join(' ')} failed with status ${exitCode}`, stderr, stdout].filter(Boolean).join('\n'));
  }
}

function safeRelativeHeader(value) {
  const raw = normalizeSlashes(value);
  if (raw.startsWith('/')) {
    throw new Error('entry path is invalid');
  }

  const text = raw.replace(/^\/+/, '');
  if (!text || text.includes('\0') || text.startsWith('../') || text === '..' || path.isAbsolute(text)) {
    throw new Error('entry path is invalid');
  }
  return path.posix.normalize(text);
}

function safeArchiveEntryName(value) {
  const raw = normalizeSlashes(value);
  if (raw.startsWith('/')) {
    throw new Error(`archive entry path is invalid: ${value}`);
  }

  const text = raw.replace(/^\.\//, '');
  const normalized = path.posix.normalize(text);
  if (!normalized || normalized === '.' || normalized === '..' || normalized.startsWith('../') || normalized.includes('\0') || path.isAbsolute(text)) {
    throw new Error(`archive entry path is invalid: ${value}`);
  }
  return normalized;
}

function normalizeSitePagePath(entryPath) {
  let value = safeRelativeHeader(entryPath);
  value = value.replace(/\/(?:index|README)\.(?:md|markdown|mdx)$/i, '');
  value = value.replace(/\.(md|markdown|mdx)$/i, '');
  value = value.replace(/\/index\.html$/i, '');
  value = value.replace(/\.html$/i, '');
  return value || 'index';
}

function normalizeSlashes(value) {
  return String(value || '').replaceAll('\\', '/');
}

function sendJson(response, status, payload) {
  const body = JSON.stringify(payload);
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  response.end(body);
}
