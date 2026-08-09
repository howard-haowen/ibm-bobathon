#!/usr/bin/env node
/**
 * scripts/update-index.mjs
 *
 * Scans artifacts/*.html (excluding index.html), extracts per-file metadata,
 * and regenerates the <p class="section-label"> + <div class="card-grid">
 * block inside artifacts/index.html.
 *
 * Metadata extracted (in priority order):
 *   eyebrow  — first .card-eyebrow text, else empty
 *   title    — first <h1> text, else <title> text, else filename
 *   desc     — first <p> after <h1> (the hero description), else empty
 *
 * Usage:
 *   node scripts/update-index.mjs                      # default: artifacts/
 *   node scripts/update-index.mjs --dir workshops/w01/artifacts
 */

import { readdir, readFile, writeFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Allow --dir <path> override (path relative to repo root / cwd)
const dirFlagIdx = process.argv.indexOf('--dir');
const ARTIFACTS_DIR = dirFlagIdx !== -1
  ? resolve(process.cwd(), process.argv[dirFlagIdx + 1])
  : resolve(__dirname, '../artifacts');
const INDEX_FILE = resolve(ARTIFACTS_DIR, 'index.html');

// ── helpers ────────────────────────────────────────────────────────────────

/** Extract inner text from the first occurrence of a tag (handles attributes). */
function firstTagText(html, tag) {
  const re = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`, 'i');
  const m = html.match(re);
  return m ? m[1].replace(/<[^>]+>/g, '').trim() : '';
}

/** Extract inner text of the first element carrying a given class. */
function firstClassText(html, cls) {
  const re = new RegExp(`class="[^"]*\\b${cls}\\b[^"]*"[^>]*>([\\s\\S]*?)<\\/`, 'i');
  const m = html.match(re);
  return m ? m[1].replace(/<[^>]+>/g, '').trim() : '';
}

/**
 * Extract the first <p> that comes *after* the <h1> and is not inside a
 * special wrapper (hero eyebrow, card-eyebrow, section-label).
 */
function heroDesc(html) {
  const h1Match = html.match(/<h1[^>]*>[\s\S]*?<\/h1>/i);
  if (!h1Match) return '';
  const after = html.slice(h1Match.index + h1Match[0].length);
  // grab first <p ...>...</p> that doesn't look like an eyebrow
  const pRe = /<p([^>]*)>([\s\S]*?)<\/p>/gi;
  let m;
  while ((m = pRe.exec(after)) !== null) {
    const attrs = m[1];
    const text = m[2].replace(/<[^>]+>/g, '').trim();
    if (/eyebrow|section-label/.test(attrs)) continue;
    if (text.length > 10) return text;
  }
  return '';
}

/** Decode common HTML entities to avoid double-escaping. */
function decodeEntities(str) {
  return str
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, '\u00a0');
}

function escapeHtml(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ── gather files ───────────────────────────────────────────────────────────

const entries = await readdir(ARTIFACTS_DIR);
const htmlFiles = entries
  .filter(f => f.endsWith('.html') && f !== 'index.html')
  .sort();

if (htmlFiles.length === 0) {
  console.log('No HTML files found in artifacts/ (excluding index.html).');
  process.exit(0);
}

// ── parse metadata ─────────────────────────────────────────────────────────

const cards = await Promise.all(
  htmlFiles.map(async file => {
    const raw = await readFile(resolve(ARTIFACTS_DIR, file), 'utf8');
    const eyebrow = decodeEntities(
                      firstClassText(raw, 'card-eyebrow') ||
                      firstClassText(raw, 'hero-eyebrow') || '');
    const title   = decodeEntities(
                      firstTagText(raw, 'h1') || firstTagText(raw, 'title') || file);
    const desc    = decodeEntities(heroDesc(raw));
    return { file, eyebrow, title, desc };
  })
);

// ── build replacement HTML ─────────────────────────────────────────────────

const cardItems = cards.map(({ file, eyebrow, title, desc }) => {
  const eyebrowHtml = eyebrow
    ? `\n        <p class="card-eyebrow">${escapeHtml(eyebrow)}</p>`
    : '';
  const descHtml = desc
    ? `\n        <p>${escapeHtml(desc)}</p>`
    : '';
  return `
      <a class="card" href="${escapeHtml(file)}">${eyebrowHtml}
        <h2>${escapeHtml(title)}</h2>${descHtml}
        <span class="card-cta">閱讀報告</span>
      </a>`;
}).join('\n');

const newSectionLabel =
  `<p class="section-label">全部報告（${cards.length}）</p>`;

const newCardGrid =
  `<div class="card-grid">${cardItems}\n\n    </div>`;

// ── patch index.html ───────────────────────────────────────────────────────

let index = await readFile(INDEX_FILE, 'utf8');

// Replace section-label line
index = index.replace(
  /<p class="section-label">全部報告（\d+）<\/p>/,
  newSectionLabel,
);

// Replace card-grid block (non-greedy, from opening to closing tag)
index = index.replace(
  /<div class="card-grid">[\s\S]*?<\/div>/,
  newCardGrid,
);

await writeFile(INDEX_FILE, index, 'utf8');

console.log(`✔  index.html updated — ${cards.length} report(s):`);
cards.forEach(c => console.log(`   • ${c.file}  →  ${c.title}`));
