#!/usr/bin/env node

/**
 * Agent Skillpack — Schema Validator
 *
 * Validates all SKILL.md files and meta.json files in skills/
 * Checks for required fields, format compliance, and cross-references.
 */

import { readFileSync, readdirSync, statSync, existsSync } from 'fs';
import { join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const SKILLS_DIR = join(__dirname, 'skills');

// ─── Schema ─────────────────────────────────────────────────────────────────

const REQUIRED_FRONTMATTER = ['name', 'description', 'version'];
const VALID_AGENTS = ['opencode', 'claude', 'codex', 'cursor', 'windsurf', 'copilot', 'cline', 'aider'];
const VALID_CATEGORIES = [
  'workflow', 'git', 'architecture', 'operations', 'security',
  'quality', 'testing', 'design', 'meta', 'claude-desktop'
];

const REQUIRED_SKILL_SECTIONS = [
  'Overview',
  'When to Use',
];

// ─── Validators ─────────────────────────────────────────────────────────────

function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return { meta: {}, body: content, hasFrontmatter: false };

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

  return { meta, body, hasFrontmatter: true };
}

function validateSkill(dirPath) {
  const errors = [];
  const warnings = [];
  const skillName = dirPath.split(/[\\/]/).pop();

  // Check SKILL.md exists
  const skillMd = join(dirPath, 'SKILL.md');
  if (!existsSync(skillMd)) {
    errors.push('SKILL.md not found');
    return { skillName, errors, warnings, passed: false };
  }

  const raw = readFileSync(skillMd, 'utf-8');
  const { meta, body, hasFrontmatter } = parseFrontmatter(raw);

  // Check frontmatter
  if (!hasFrontmatter) {
    errors.push('Missing YAML frontmatter (--- delimiters)');
  } else {
    for (const field of REQUIRED_FRONTMATTER) {
      if (!meta[field]) {
        errors.push(`Missing required frontmatter field: ${field}`);
      }
    }

    // Validate version format (semver)
    if (meta.version && !/^\d+\.\d+\.\d+/.test(meta.version)) {
      warnings.push(`Version "${meta.version}" is not valid semver`);
    }

    // Validate agents array
    if (meta.agents && Array.isArray(meta.agents)) {
      for (const agent of meta.agents) {
        if (!VALID_AGENTS.includes(agent)) {
          warnings.push(`Unknown agent: "${agent}"`);
        }
      }
    }

    // Validate tags
    if (meta.tags && Array.isArray(meta.tags)) {
      if (meta.tags.length === 0) {
        warnings.push('Empty tags array — add categories for better discovery');
      }
    }
  }

  // Check sections
  const bodyLower = body.toLowerCase();
  for (const section of REQUIRED_SKILL_SECTIONS) {
    if (!bodyLower.includes(section.toLowerCase())) {
      warnings.push(`Missing recommended section: "${section}"`);
    }
  }

  // Check body length
  const lineCount = raw.split('\n').length;
  if (lineCount > 500) {
    warnings.push(`SKILL.md is ${lineCount} lines — consider splitting (recommended <500)`);
  }

  // Check meta.json
  const metaJsonPath = join(dirPath, 'meta.json');
  if (existsSync(metaJsonPath)) {
    try {
      const metaJson = JSON.parse(readFileSync(metaJsonPath, 'utf-8'));
      if (!metaJson.name) errors.push('meta.json: missing "name"');
      if (!metaJson.version) errors.push('meta.json: missing "version"');
      if (!metaJson.description) warnings.push('meta.json: missing "description"');
      if (!metaJson.category) warnings.push('meta.json: missing "category"');
    } catch (e) {
      errors.push(`meta.json: invalid JSON — ${e.message}`);
    }
  } else {
    warnings.push('No meta.json found — add metadata for adapter generation');
  }

  return {
    skillName,
    errors,
    warnings,
    passed: errors.length === 0,
    lineCount,
    hasFrontmatter,
    version: meta.version || 'unknown',
  };
}

// ─── Main ───────────────────────────────────────────────────────────────────

function main() {
  console.log('Agent Skillpack — Validating skills...\n');

  if (!existsSync(SKILLS_DIR)) {
    console.error('skills/ directory not found');
    process.exit(1);
  }

  const entries = readdirSync(SKILLS_DIR);
  const results = [];

  for (const entry of entries) {
    if (entry.startsWith('_')) continue;
    const fullPath = join(SKILLS_DIR, entry);
    if (!statSync(fullPath).isDirectory()) continue;

    const result = validateSkill(fullPath);
    results.push(result);

    const icon = result.passed ? '✓' : '✗';
    const color = result.passed ? '\x1b[32m' : '\x1b[31m';
    console.log(`${color}${icon}\x1b[0m ${result.skillName} (${result.version}, ${result.lineCount || 0} lines)`);

    for (const err of result.errors) {
      console.log(`    \x1b[31mERROR: ${err}\x1b[0m`);
    }
    for (const warn of result.warnings) {
      console.log(`    \x1b[33mWARN: ${warn}\x1b[0m`);
    }
  }

  // Summary
  const passed = results.filter(r => r.passed).length;
  const failed = results.filter(r => !r.passed).length;
  const totalWarnings = results.reduce((sum, r) => sum + r.warnings.length, 0);

  console.log(`\n${'─'.repeat(50)}`);
  console.log(`Total: ${results.length} skills | Passed: ${passed} | Failed: ${failed} | Warnings: ${totalWarnings}`);

  if (failed > 0) {
    process.exit(1);
  }
}

main();
