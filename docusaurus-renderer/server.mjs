import {createServer} from 'node:http';
import {mkdtemp, mkdir, rm, readFile, stat} from 'node:fs/promises';
import {createWriteStream} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {pipeline} from 'node:stream/promises';
import {spawn} from 'node:child_process';
import {createArchiveListingValidator, sourceLimitsFromEnv, validateSourceTree} from './source-preflight.mjs';

const PORT = Number(process.env.PORT || 3000);
const MAX_UPLOAD_BYTES = Number(process.env.MAX_UPLOAD_BYTES || 20 * 1024 * 1024);
const MAX_OUTPUT_BYTES = Number(process.env.MAX_OUTPUT_BYTES || 50 * 1024 * 1024);
const BUILD_TIMEOUT_MS = Number(process.env.BUILD_TIMEOUT_MS || 60_000);
const SOURCE_LIMITS = sourceLimitsFromEnv();
const REPO_ROOT = process.env.REPO_ROOT || '/app';
const DOCUSAURUS_DIR = path.join(REPO_ROOT, 'docusaurus');

export function maxConcurrentBuildsFromEnv(env = process.env) {
  return positiveInteger(env.MAX_CONCURRENT_BUILDS ?? 1, 'MAX_CONCURRENT_BUILDS');
}

export function createRendererServer({
  buildCommandRunner = runCommand,
  maxConcurrentBuilds = maxConcurrentBuildsFromEnv(),
} = {}) {
  const buildGate = createConcurrencyGate(maxConcurrentBuilds);

  return createServer(async (request, response) => {
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
      const entryPath = safeRelativeHeader(decodeURIComponent(request.headers['x-docs-entry-path'] || 'index.md'));
      workRoot = await mkdtemp(path.join(os.tmpdir(), 'docusaurus-render-'));
      const sourceArchive = path.join(workRoot, 'source.tar.gz');
      const sourceDir = path.join(workRoot, 'docs-src');
      const staticDir = path.join(workRoot, 'static');
      const buildDir = path.join(workRoot, 'build');
      const outputArchive = path.join(workRoot, 'build.tar.gz');
      const docusaurusDocsDir = path.relative(DOCUSAURUS_DIR, sourceDir);
      const docusaurusStaticDir = path.relative(DOCUSAURUS_DIR, staticDir);

      await writeBoundedRequestBody(request, sourceArchive);
      await mkdir(sourceDir, {recursive: true});
      await mkdir(staticDir, {recursive: true});
      await validateArchiveEntries(sourceArchive, SOURCE_LIMITS);
      await extractArchive(sourceArchive, sourceDir);
      await validateSourceTree(sourceDir, SOURCE_LIMITS);

      const releaseBuildPermit = buildGate.tryAcquire();
      if (!releaseBuildPermit) {
        throw new HttpError(429, `renderer is busy: ${maxConcurrentBuilds} build(s) already running`);
      }

      try {
        await buildCommandRunner('npm', ['run', 'build', '--', '--out-dir', buildDir], {
          cwd: DOCUSAURUS_DIR,
          env: {
            ...process.env,
            DOCUSAURUS_DOCS_PATH: docusaurusDocsDir,
            DOCUSAURUS_STATIC_DIR: docusaurusStaticDir,
          },
          timeoutMs: BUILD_TIMEOUT_MS,
        });
      } finally {
        releaseBuildPermit();
      }

      const sitePath = await detectSitePath(buildDir, entryPath);
      await createArchive(outputArchive, buildDir);
      await ensureMaxFileSize(outputArchive, MAX_OUTPUT_BYTES, 'build output');
      const archive = await readFile(outputArchive);

      response.writeHead(200, {
        'Content-Type': 'application/gzip',
        'X-Docs-Site-Path': encodeURIComponent(sitePath),
        'Content-Length': archive.length,
      });
      response.end(archive);
    } catch (error) {
      sendJson(response, error?.statusCode || 422, {
        ok: false,
        error: error?.message || String(error),
      });
    } finally {
      if (workRoot) {
        await rm(workRoot, {recursive: true, force: true});
      }
    }
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const server = createRendererServer();
  server.listen(PORT, () => {
    console.log(`Docusaurus renderer listening on ${PORT}`);
  });
}

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

async function validateArchiveEntries(archivePath, limits) {
  const validator = createArchiveListingValidator(limits);
  let bufferedLine = '';

  const validateLine = (line) => {
    if (!line) return;
    validator.accept(line);
    safeArchiveEntryName(archiveEntryNameFromVerboseLine(line));
  };

  await runCommand('tar', ['-tvzf', archivePath], {
    timeoutMs: BUILD_TIMEOUT_MS,
    onStdout: (chunk) => {
      bufferedLine += chunk.toString('utf8');
      if (Buffer.byteLength(bufferedLine) > 16 * 1024 && !bufferedLine.includes('\n')) {
        throw new Error('archive entry line is too long');
      }

      const lines = bufferedLine.split('\n');
      bufferedLine = lines.pop() || '';
      lines.forEach(validateLine);
    },
  });
  validateLine(bufferedLine);
}

async function extractArchive(archivePath, destination) {
  await runCommand('tar', ['--no-same-owner', '--no-same-permissions', '-xzf', archivePath, '-C', destination], {timeoutMs: BUILD_TIMEOUT_MS});
}

async function createArchive(archivePath, sourceDir) {
  await runCommand('tar', ['-czf', archivePath, '-C', sourceDir, '.'], {timeoutMs: BUILD_TIMEOUT_MS});
}

async function runCommand(command, args, options = {}) {
  let stdout = '';
  let stderr = '';
  let streamError;
  const child = spawn(command, args, {
    cwd: options.cwd,
    env: options.env || process.env,
    stdio: ['ignore', 'pipe', 'pipe'],
    detached: true,
  });

  const terminate = () => {
    try {
      process.kill(-child.pid, 'SIGKILL');
    } catch {
      child.kill('SIGKILL');
    }
  };
  const timer = setTimeout(terminate, options.timeoutMs || BUILD_TIMEOUT_MS);

  child.stdout.on('data', (chunk) => {
    stdout = appendOutputTail(stdout, chunk);
    if (streamError || !options.onStdout) return;

    try {
      options.onStdout(chunk);
    } catch (error) {
      streamError = error;
      terminate();
    }
  });
  child.stderr.on('data', (chunk) => {
    stderr = appendOutputTail(stderr, chunk);
  });

  const exitCode = await new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('close', resolve);
  }).finally(() => clearTimeout(timer));

  if (streamError) throw streamError;
  if (exitCode !== 0) {
    throw new Error([`${command} ${args.join(' ')} failed with status ${exitCode}`, stderr, stdout].filter(Boolean).join('\n'));
  }
}

function appendOutputTail(current, chunk) {
  return `${current}${chunk.toString('utf8')}`.slice(-4000);
}

function safeRelativeHeader(value) {
  const raw = normalizeSlashes(value);
  if (raw.startsWith('/') || hasDriveLetter(raw)) {
    throw new Error('entry path is invalid');
  }

  const text = raw.replace(/^\/+/, '');
  if (!text || text.includes('\0') || text.startsWith('../') || text === '..' || path.isAbsolute(text)) {
    throw new Error('entry path is invalid');
  }
  return path.posix.normalize(text);
}

function archiveEntryNameFromVerboseLine(line) {
  const parts = line.trim().split(/\s+/);
  if (parts.length < 6) {
    throw new Error(`archive entry line is invalid: ${line}`);
  }
  return parts.slice(5).join(' ');
}

function safeArchiveEntryName(value) {
  const raw = normalizeSlashes(value);
  if (raw === './' || raw === '.') return null; // skip root directory entry
  if (raw.startsWith('/') || hasDriveLetter(raw)) {
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

async function detectSitePath(buildDir, entryPath) {
  const {readdir} = await import('node:fs/promises');

  // Collect all index.html paths relative to buildDir (non-recursive helper)
  async function findIndexFiles(dir, prefix = '') {
    const results = [];
    let entries;
    try {
      entries = await readdir(dir, {withFileTypes: true});
    } catch {
      return results;
    }
    for (const entry of entries) {
      const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
      if (entry.isDirectory()) {
        const sub = await findIndexFiles(path.join(dir, entry.name), rel);
        results.push(...sub);
      } else if (entry.name === 'index.html') {
        results.push(prefix || 'index');
      }
    }
    return results;
  }

  const allPaths = await findIndexFiles(buildDir);

  // Normalize Unicode for comparison (NFC)
  const normalizedPaths = allPaths.map((p) => p.normalize('NFC'));

  // Try exact normalized match first
  const normalized = normalizeSitePagePath(entryPath).normalize('NFC');
  if (normalizedPaths.includes(normalized)) {
    return allPaths[normalizedPaths.indexOf(normalized)];
  }

  // README at any level maps to index in Docusaurus
  const readmeAsIndex = normalized.replace(/(^|\/)README$/i, '$1index');
  if (readmeAsIndex !== normalized && normalizedPaths.includes(readmeAsIndex)) {
    return allPaths[normalizedPaths.indexOf(readmeAsIndex)];
  }

  // Build candidate: strip number prefixes (e.g. 00_, 01_) and top-level directory
  const segments = normalized.split('/');
  const strippedSegments = segments.map((s) => s.replace(/^\d+_/, ''));

  // Try progressively removing leading segments
  for (let start = 0; start < strippedSegments.length; start++) {
    const candidate = strippedSegments.slice(start).join('/');
    if (candidate && normalizedPaths.includes(candidate)) {
      return allPaths[normalizedPaths.indexOf(candidate)];
    }
  }

  // Also try the original segments with leading segments removed
  for (let start = 1; start < segments.length; start++) {
    const candidate = segments.slice(start).map((s) => s.replace(/^\d+_/, '')).join('/');
    if (candidate && normalizedPaths.includes(candidate)) {
      return allPaths[normalizedPaths.indexOf(candidate)];
    }
  }

  // Fallback: find any path whose last segment matches
  const entryBasename = path.posix.basename(normalized);
  const strippedBasename = entryBasename.replace(/^\d+_/, '');
  const baseIdx = normalizedPaths.findIndex((p) => {
    const last = p.split('/').pop();
    return last === entryBasename || last === strippedBasename;
  });
  if (baseIdx >= 0) {
    return allPaths[baseIdx];
  }

  // Last resort
  return normalized;
}

function normalizeSlashes(value) {
  return String(value || '').replaceAll('\\', '/');
}

function hasDriveLetter(value) {
  return /^[A-Za-z]:\//.test(value);
}

class HttpError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.statusCode = statusCode;
  }
}

function positiveInteger(value, name) {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive integer`);
  }
  return parsed;
}

function createConcurrencyGate(limit) {
  const validatedLimit = positiveInteger(limit, 'maxConcurrentBuilds');
  let activeBuilds = 0;

  return {
    tryAcquire() {
      if (activeBuilds >= validatedLimit) return null;

      activeBuilds += 1;
      let released = false;
      return () => {
        if (released) return;
        released = true;
        activeBuilds -= 1;
      };
    },
  };
}

function sendJson(response, status, payload) {
  const body = JSON.stringify(payload);
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  response.end(body);
}
