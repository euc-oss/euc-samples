/* eslint-disable no-console */
// Generate PNG icons from SVG sources, backing up previous PNGs.
// Requires: npm i -D sharp

const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..');
const iconsDir = path.join(root, 'icons');
const srcDir = path.join(iconsDir, 'src');

const outputs = [
  { size: 16,  svg: 'icon-simple.svg', out: 'icon-16.png' },
  { size: 32,  svg: 'icon-simple.svg', out: 'icon-32.png' },
  { size: 48,  svg: 'icon-base.svg',   out: 'icon-48.png' },
  { size: 128, svg: 'icon-base.svg',   out: 'icon-128.png' }
];

async function ensureDir(p) {
  await fsp.mkdir(p, { recursive: true });
}

async function backupExisting() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupDir = path.join(iconsDir, 'backup', timestamp);
  await ensureDir(backupDir);
  const files = ['icon-16.png','icon-32.png','icon-48.png','icon-128.png'];
  for (const f of files) {
    const src = path.join(iconsDir, f);
    try {
      await fsp.access(src, fs.constants.F_OK);
      await fsp.copyFile(src, path.join(backupDir, f));
      console.log(`Backed up ${f} -> ${path.relative(root, path.join(backupDir, f))}`);
    } catch (_) { /* skip */ }
  }
  return backupDir;
}

async function generate() {
  await ensureDir(srcDir);
  await ensureDir(path.join(iconsDir, 'backup'));
  const backupDir = await backupExisting();
  console.log(`Backup directory: ${backupDir}`);

  for (const { size, svg, out } of outputs) {
    const svgPath = path.join(srcDir, svg);
    const outPath = path.join(iconsDir, out);
    console.log(`Rendering ${svg} -> ${out} at ${size}x${size}`);
    const svgBuffer = await fsp.readFile(svgPath);
    const image = sharp(svgBuffer).resize(size, size, { fit: 'cover' });
    await image.png({ compressionLevel: 9, adaptiveFiltering: true }).toFile(outPath);
  }
  console.log('Icon generation complete.');
}

generate().catch((err) => {
  console.error('Failed to generate icons:', err);
  process.exit(1);
});
