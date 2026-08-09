import assert from 'node:assert/strict';
import {mkdtemp, mkdir, rm, symlink, writeFile} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {
  blockedImageFormat,
  sourceLimitsFromEnv,
  validateArchiveListing,
  validateSourceTree,
} from './source-preflight.mjs';

const blockedHeaders = [
  ['ICNS', Buffer.from('icns0000')],
  ['JPEG XL codestream', Buffer.from([0xff, 0x0a])],
  ['JPEG XL', boxHeader('JXL ', 'jxl ')],
  ['JPEG 2000', boxHeader('jP  ', 'jp2 ')],
  ['AVIF', boxHeader('ftyp', 'avif')],
  ['HEIF', boxHeader('ftyp', 'mif1')],
  ['HEIF sequence', boxHeader('ftyp', 'msf1')],
  ['HEIC', boxHeader('ftyp', 'heic')],
  ['HEIC', boxHeader('ftyp', 'heix')],
  ['HEIC sequence', boxHeader('ftyp', 'hevc')],
  ['HEIC sequence', boxHeader('ftyp', 'hevx')],
];

for (const [format, header] of blockedHeaders) {
  test(`detects ${format} by file bytes`, () => {
    assert.equal(blockedImageFormat(header), format);
  });
}

test('detects blocked ISO BMFF compatible brands', () => {
  assert.equal(blockedImageFormat(ftypHeader('isom', ['avif'])), 'AVIF');
  assert.equal(blockedImageFormat(ftypHeader('isom', ['heic'])), 'HEIC');
});

test('rejects an ftyp box that cannot be fully inspected', () => {
  const header = ftypHeader('isom', []);
  header.writeUInt32BE(8192, 0);
  assert.equal(blockedImageFormat(header), 'ISO BMFF ftyp outside inspection bounds');
});

test('allows common safe image headers', () => {
  assert.equal(blockedImageFormat(Buffer.from([0x89, 0x50, 0x4e, 0x47])), null);
  assert.equal(blockedImageFormat(Buffer.from([0xff, 0xd8, 0xff, 0xe0])), null);
  assert.equal(blockedImageFormat(Buffer.from('GIF89a')), null);
});

test('counts nested regular files and bytes', async () => {
  await withSourceTree(async (root) => {
    await mkdir(path.join(root, 'assets'));
    await writeFile(path.join(root, 'index.md'), '# Preview');
    await writeFile(path.join(root, 'assets', 'logo.png'), Buffer.from([0x89, 0x50, 0x4e, 0x47]));

    assert.deepEqual(await validateSourceTree(root, {
      maxFiles: 2,
      maxFileBytes: 20,
      maxTotalBytes: 20,
    }), {fileCount: 2, totalBytes: 13});
  });
});

test('rejects a blocked image even when its extension is safe', async () => {
  await withSourceTree(async (root) => {
    await writeFile(path.join(root, 'renamed.png'), Buffer.from('icns0000'));

    await assert.rejects(
      validateSourceTree(root),
      /source image format is not allowed: renamed\.png \(ICNS\)/,
    );
  });
});

test('rejects too many files', async () => {
  await withSourceTree(async (root) => {
    await writeFile(path.join(root, 'one.md'), '1');
    await writeFile(path.join(root, 'two.md'), '2');

    await assert.rejects(
      validateSourceTree(root, {maxFiles: 1, maxFileBytes: 10, maxTotalBytes: 10}),
      /source file count exceeds 1/,
    );
  });
});

test('rejects an oversized individual file', async () => {
  await withSourceTree(async (root) => {
    await writeFile(path.join(root, 'large.md'), '1234');

    await assert.rejects(
      validateSourceTree(root, {maxFiles: 1, maxFileBytes: 3, maxTotalBytes: 10}),
      /source file is too large: large\.md \(4 bytes\)/,
    );
  });
});

test('rejects an oversized source tree', async () => {
  await withSourceTree(async (root) => {
    await writeFile(path.join(root, 'one.md'), '123');
    await writeFile(path.join(root, 'two.md'), '456');

    await assert.rejects(
      validateSourceTree(root, {maxFiles: 2, maxFileBytes: 3, maxTotalBytes: 5}),
      /source tree is too large: 6 bytes/,
    );
  });
});

test('rejects non-regular entries', async () => {
  await withSourceTree(async (root) => {
    await writeFile(path.join(root, 'target.md'), '# Target');
    await symlink(path.join(root, 'target.md'), path.join(root, 'linked.md'));

    await assert.rejects(
      validateSourceTree(root),
      /source entry type is not allowed: linked\.md/,
    );
  });
});

test('rejects declared archive expansion limits before extraction', () => {
  const listing = [
    '-rw-r--r-- user/group 4 2026-08-09 12:00 ./one.md',
    '-rw-r--r-- user/group 4 2026-08-09 12:00 ./two.md',
  ].join('\n');

  assert.throws(
    () => validateArchiveListing(listing, {maxFiles: 1, maxFileBytes: 4, maxTotalBytes: 8}),
    /source file count exceeds 1/,
  );
  assert.throws(
    () => validateArchiveListing(listing, {maxFiles: 2, maxFileBytes: 3, maxTotalBytes: 8}),
    /source file is too large: \.\/one\.md \(4 bytes\)/,
  );
  assert.throws(
    () => validateArchiveListing(listing, {maxFiles: 2, maxFileBytes: 4, maxTotalBytes: 7}),
    /source tree is too large: 8 bytes/,
  );
});

test('validates configured limits', () => {
  assert.deepEqual(sourceLimitsFromEnv({
    MAX_SOURCE_FILES: '4',
    MAX_SOURCE_FILE_BYTES: '8',
    MAX_SOURCE_BYTES: '16',
  }), {maxFiles: 4, maxFileBytes: 8, maxTotalBytes: 16});

  assert.throws(
    () => sourceLimitsFromEnv({MAX_SOURCE_FILES: '0'}),
    /MAX_SOURCE_FILES must be a positive integer/,
  );
});

function boxHeader(type, brand) {
  const header = Buffer.alloc(16);
  header.writeUInt32BE(16, 0);
  header.write(type, 4, 'ascii');
  header.write(brand, 8, 'ascii');
  return header;
}

function ftypHeader(majorBrand, compatibleBrands) {
  const header = Buffer.alloc(16 + compatibleBrands.length * 4);
  header.writeUInt32BE(header.length, 0);
  header.write('ftyp', 4, 'ascii');
  header.write(majorBrand, 8, 'ascii');
  compatibleBrands.forEach((brand, index) => header.write(brand, 16 + index * 4, 'ascii'));
  return header;
}

async function withSourceTree(callback) {
  const root = await mkdtemp(path.join(os.tmpdir(), 'source-preflight-test-'));
  try {
    await callback(root);
  } finally {
    await rm(root, {recursive: true, force: true});
  }
}
