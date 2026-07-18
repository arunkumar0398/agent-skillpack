#!/usr/bin/env node

/**
 * Agent Skillpack — meta.json Generator
 *
 * Generates meta.json for skills that don't have one.
 * Extracts metadata from SKILL.md frontmatter and directory structure.
 */

import { readFileSync, writeFileSync, readdirSync, existsSync, statSync } from 'fs';
import { join, basename } from 'path';
import { fileURLToPath } from 'url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const SKILLS_DIR = join(__dirname, 'skills');

const ALL_AGENTS = ['opencode', 'claude', 'codex', 'cursor', 'windsurf', 'copilot', 'cline', 'aider'];

// ─── Category Mapping ──────────────────────────────────────────────────────

const CATEGORY_PATTERNS = [
  { pattern: /git|worktree|branch|commit|version/i, category: 'git' },
  { pattern: /api|interface|endpoint|graphql|rest/i, category: 'architecture' },
  { pattern: /frontend|ui|component|css|tailwind/i, category: 'architecture' },
  { pattern: /security|hardening|auth|encrypt/i, category: 'security' },
  { pattern: /test|testing|spec|assertion/i, category: 'testing' },
  { pattern: /debug|error|fault|diagnos|recovery/i, category: 'debugging' },
  { pattern: /ci.?cd|deploy|ship|launch|pipeline/i, category: 'operations' },
  { pattern: /design|ux|theme|visual|art|canvas/i, category: 'design' },
  { pattern: /code.*review|quality|lint|format|simplif/i, category: 'quality' },
  { pattern: /performance|optim|speed|fast|cache/i, category: 'quality' },
  { pattern: /session|mcp|config|dual.*runtime|bridge/i, category: 'claude-desktop' },
  { pattern: /skill|activat|context.*engineer|using.*agent/i, category: 'meta' },
  { pattern: /plan|task|spec|incremental|iterat/i, category: 'workflow' },
  { pattern: /document|adr|readme|changelog/i, category: 'workflow' },
  { pattern: /observ|log|metric|trac|alert/i, category: 'operations' },
  { pattern: /learn|capture|knowledge|research/i, category: 'meta' },
];

function detectCategory(name, body) {
  const combined = `${name} ${body.slice(0, 500)}`;
  for (const { pattern, category } of CATEGORY_PATTERNS) {
    if (pattern.test(combined)) return category;
  }
  return 'workflow';
}

// ─── Tag Generation ────────────────────────────────────────────────────────

function generateTags(name) {
  // Split by hyphens, filter out common stop words
  const stopWords = new Set(['and', 'or', 'the', 'a', 'an', 'with', 'for', 'to', 'of', 'in', 'on', 'at', 'by']);
  return name
    .split('-')
    .filter(w => w.length > 2 && !stopWords.has(w))
    .slice(0, 5); // max 5 tags
}

// ─── Frontmatter Parser ────────────────────────────────────────────────────

function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return { meta: {}, body: content };

  const raw = match[1];
  const body = match[2];
  const meta = {};
  const lines = raw.split('\n');
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];
    const colonIdx = line.indexOf(':');
    if (colonIdx === -1) { i++; continue; }

    const key = line.slice(0, colonIdx).trim();
    let val = line.slice(colonIdx + 1).trim();

    // Handle multi-line YAML with >-
    if (val === '>' || val === '>-') {
      const multiLines = [];
      i++;
      while (i < lines.length && (lines[i].startsWith('  ') || lines[i].startsWith('\t'))) {
        multiLines.push(lines[i].trim());
        i++;
      }
      val = multiLines.join(' ');
    }
    // Handle YAML arrays: [a, b, c]
    else if (val.startsWith('[') && val.endsWith(']')) {
      val = val.slice(1, -1).split(',').map(s => s.trim().replace(/^["']|["']$/g, ''));
      i++;
    }
    // Handle empty value
    else if (val === '') {
      i++;
      continue;
    }
    else {
      val = val.replace(/^["']|["']$/g, '');
      i++;
    }

    meta[key] = val;
  }

  return { meta, body };
}

// ─── File Detection ────────────────────────────────────────────────────────

function detectFiles(dirPath, subDir) {
  const fullPath = join(dirPath, subDir);
  if (!existsSync(fullPath) || !statSync(fullPath).isDirectory()) return [];
  return readdirSync(fullPath).filter(f => !f.startsWith('.'));
}

// ─── Main ──────────────────────────────────────────────────────────────────

function main() {
  console.log('Agent Skillpack — Generating meta.json files...\n');

  const entries = readdirSync(SKILLS_DIR);
  let created = 0;
  let skipped = 0;

  for (const entry of entries) {
    if (entry.startsWith('_')) continue; // skip templates
    const fullPath = join(SKILLS_DIR, entry);
    if (!statSync(fullPath).isDirectory()) continue;

    const metaPath = join(fullPath, 'meta.json');
    if (existsSync(metaPath)) {
      skipped++;
      continue;
    }

    const skillMd = join(fullPath, 'SKILL.md');
    if (!existsSync(skillMd)) continue;

    // Read SKILL.md
    const raw = readFileSync(skillMd, 'utf-8');
    const { meta: frontmatter, body } = parseFrontmatter(raw);

    // Detect files
    const scripts = detectFiles(fullPath, 'scripts');
    const references = detectFiles(fullPath, 'references');
    const agents = detectFiles(fullPath, 'agents');

    // Generate metadata
    const name = frontmatter.name || entry;
    const description = frontmatter.description || '';
    const category = detectCategory(name, body);
    const tags = generateTags(name);

    const metaJson = {
      name,
      version: frontmatter.version || '1.0.0',
      description: description.replace(/\s+/g, ' ').trim(),
      tags,
      agents: [...ALL_AGENTS],
      category,
      dependencies: [],
      scripts,
      references,
    };

    // Write meta.json
    writeFileSync(metaPath, JSON.stringify(metaJson, null, 2) + '\n', 'utf-8');
    created++;
    console.log(`  ✓ ${entry} → category: ${category}, tags: [${tags.join(', ')}]`);
  }

  console.log(`\nDone! Created: ${created} | Skipped: ${skipped}`);
}

main();
