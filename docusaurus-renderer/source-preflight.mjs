import {lstat, open, opendir} from 'node:fs/promises';
import path from 'node:path';

export const DEFAULT_SOURCE_LIMITS = Object.freeze({
  maxFiles: 2_000,
  maxFileBytes: 20 * 1024 * 1024,
  maxTotalBytes: 200 * 1024 * 1024,
});

const HEADER_BYTES = 4 * 1024;
const BLOCKED_ISOBMFF_BRANDS = new Map([
  ['avif', 'AVIF'],
  ['mif1', 'HEIF'],
  ['msf1', 'HEIF sequence'],
  ['heic', 'HEIC'],
  ['heix', 'HEIC'],
  ['hevc', 'HEIC sequence'],
  ['hevx', 'HEIC sequence'],
]);

export function sourceLimitsFromEnv(env = process.env) {
  return {
    maxFiles: positiveInteger(env.MAX_SOURCE_FILES, DEFAULT_SOURCE_LIMITS.maxFiles, 'MAX_SOURCE_FILES'),
    maxFileBytes: positiveInteger(env.MAX_SOURCE_FILE_BYTES, DEFAULT_SOURCE_LIMITS.maxFileBytes, 'MAX_SOURCE_FILE_BYTES'),
    maxTotalBytes: positiveInteger(env.MAX_SOURCE_BYTES, DEFAULT_SOURCE_LIMITS.maxTotalBytes, 'MAX_SOURCE_BYTES'),
  };
}

export async function validateSourceTree(rootDir, limits = DEFAULT_SOURCE_LIMITS) {
  const normalizedLimits = normalizeLimits(limits);
  const summary = {fileCount: 0, totalBytes: 0};
  await scanDirectory(rootDir, rootDir, normalizedLimits, summary);
  return summary;
}

export function createArchiveListingValidator(limits = DEFAULT_SOURCE_LIMITS) {
  const normalizedLimits = normalizeLimits(limits);
  const summary = {fileCount: 0, totalBytes: 0};

  return {
    accept(line) {
      const mode = line.slice(0, 1);
      if (!['-', 'd'].includes(mode)) {
        throw new Error(`archive entry type is not allowed: ${line}`);
      }

      const metadata = archiveEntryMetadata(line);
      if (metadata.name === './' || metadata.name === '.' || mode === 'd') return;

      summary.fileCount += 1;
      if (summary.fileCount > normalizedLimits.maxFiles) {
        throw new Error(`source file count exceeds ${normalizedLimits.maxFiles}`);
      }
      if (metadata.size > normalizedLimits.maxFileBytes) {
        throw new Error(`source file is too large: ${metadata.name} (${metadata.size} bytes)`);
      }

      summary.totalBytes += metadata.size;
      if (summary.totalBytes > normalizedLimits.maxTotalBytes) {
        throw new Error(`source tree is too large: ${summary.totalBytes} bytes`);
      }
    },
    summary,
  };
}

export function validateArchiveListing(listing, limits = DEFAULT_SOURCE_LIMITS) {
  const validator = createArchiveListingValidator(limits);
  for (const line of listing.split('\n').filter(Boolean)) {
    validator.accept(line);
  }
  return validator.summary;
}

export function blockedImageFormat(header) {
  if (header.length >= 4 && header.subarray(0, 4).toString('ascii') === 'icns') {
    return 'ICNS';
  }

  if (header.length >= 2 && header[0] === 0xff && header[1] === 0x0a) {
    return 'JPEG XL codestream';
  }

  if (header.length < 12) return null;

  const boxType = header.subarray(4, 8).toString('ascii');
  if (boxType === 'JXL ') return 'JPEG XL';
  if (boxType === 'jP  ') return 'JPEG 2000';
  if (boxType !== 'ftyp') return null;

  const boxSize = header.readUInt32BE(0);
  if (boxSize === 0 || boxSize === 1 || boxSize < 16 || boxSize > HEADER_BYTES || boxSize > header.length) {
    return 'ISO BMFF ftyp outside inspection bounds';
  }

  const majorBrand = header.subarray(8, 12).toString('ascii');
  const blockedMajorBrand = BLOCKED_ISOBMFF_BRANDS.get(majorBrand);
  if (blockedMajorBrand) return blockedMajorBrand;

  for (let offset = 16; offset + 4 <= boxSize; offset += 4) {
    const compatibleBrand = header.subarray(offset, offset + 4).toString('ascii');
    const blockedCompatibleBrand = BLOCKED_ISOBMFF_BRANDS.get(compatibleBrand);
    if (blockedCompatibleBrand) return blockedCompatibleBrand;
  }

  return null;
}

async function scanDirectory(rootDir, currentDir, limits, summary) {
  const directory = await opendir(currentDir);
  for await (const entry of directory) {
    const absolutePath = path.join(currentDir, entry.name);
    const relativePath = path.relative(rootDir, absolutePath).split(path.sep).join('/');
    const info = await lstat(absolutePath);

    if (info.isDirectory()) {
      await scanDirectory(rootDir, absolutePath, limits, summary);
      continue;
    }

    if (!info.isFile()) {
      throw new Error(`source entry type is not allowed: ${relativePath}`);
    }

    summary.fileCount += 1;
    if (summary.fileCount > limits.maxFiles) {
      throw new Error(`source file count exceeds ${limits.maxFiles}`);
    }

    if (info.size > limits.maxFileBytes) {
      throw new Error(`source file is too large: ${relativePath} (${info.size} bytes)`);
    }

    summary.totalBytes += info.size;
    if (summary.totalBytes > limits.maxTotalBytes) {
      throw new Error(`source tree is too large: ${summary.totalBytes} bytes`);
    }

    const format = await detectBlockedImageFormat(absolutePath);
    if (format) {
      throw new Error(`source image format is not allowed: ${relativePath} (${format})`);
    }
  }
}

async function detectBlockedImageFormat(filePath) {
  const handle = await open(filePath, 'r');
  try {
    const header = Buffer.alloc(HEADER_BYTES);
    const {bytesRead} = await handle.read(header, 0, header.length, 0);
    return blockedImageFormat(header.subarray(0, bytesRead));
  } finally {
    await handle.close();
  }
}

function archiveEntryMetadata(line) {
  const parts = line.trim().split(/\s+/);
  if (parts.length < 6 || !/^\d+$/.test(parts[2])) {
    throw new Error(`archive entry line is invalid: ${line}`);
  }

  return {
    size: Number(parts[2]),
    name: parts.slice(5).join(' '),
  };
}

function normalizeLimits(limits) {
  return {
    maxFiles: positiveInteger(limits.maxFiles, DEFAULT_SOURCE_LIMITS.maxFiles, 'maxFiles'),
    maxFileBytes: positiveInteger(limits.maxFileBytes, DEFAULT_SOURCE_LIMITS.maxFileBytes, 'maxFileBytes'),
    maxTotalBytes: positiveInteger(limits.maxTotalBytes, DEFAULT_SOURCE_LIMITS.maxTotalBytes, 'maxTotalBytes'),
  };
}

function positiveInteger(value, fallback, label) {
  const number = value === undefined || value === null || value === '' ? fallback : Number(value);
  if (!Number.isSafeInteger(number) || number <= 0) {
    throw new Error(`${label} must be a positive integer`);
  }
  return number;
}
