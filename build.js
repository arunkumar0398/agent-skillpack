#!/usr/bin/env node

/**
 * Agent Skillpack — Adapter Builder
 *
 * Converts canonical SKILL.md files to agent-specific formats:
 * - OpenCode: direct copy (native format)
 * - Claude Code: CLAUDE.md + .claude/rules/*.md
 * - Codex: AGENTS.md
 * - Cursor: .cursor/rules/*.mdc
 * - Windsurf: .windsurfrules
 * - GitHub Copilot: .github/copilot-instructions.md + .github/instructions/
 * - Cline: .clinerules/*.md
 * - Aider: CONVENTIONS.md + .aider.conf.yml
 */

import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync, rmSync, existsSync } from 'fs';
import { join, basename } from 'path';
import { fileURLToPath } from 'url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const SKILLS_DIR = join(__dirname, 'skills');
const DIST_DIR = join(__dirname, 'dist');

// ─── Helpers ────────────────────────────────────────────────────────────────

function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return { meta: {}, body: content };

  const raw = match[1];
  const body = match[2];
  const meta = {};

  for (const line of raw.split('\n')) {
    const colonIdx = line.indexOf(':');
    if (colonIdx === -1) continue;
    const key = line.slice(0, colonIdx).trim();
    let val = line.slice(colonIdx + 1).trim();

    // Handle YAML arrays: [a, b, c]
    if (val.startsWith('[') && val.endsWith(']')) {
      val = val.slice(1, -1).split(',').map(s => s.trim().replace(/^["']|["']$/g, ''));
    }
    // Handle multi-line descriptions with >-
    else if (val === '' || val === '>' || val === '>-') {
      continue; // will be handled by next lines or skip
    }
    // Strip quotes
    else {
      val = val.replace(/^["']|["']$/g, '');
    }

    meta[key] = val;
  }

  return { meta, body };
}

function readSkill(dirPath) {
  const skillMd = join(dirPath, 'SKILL.md');
  if (!existsSync(skillMd)) return null;

  const raw = readFileSync(skillMd, 'utf-8');
  const { meta, body } = parseFrontmatter(raw);

  // Read meta.json if exists
  const metaJsonPath = join(dirPath, 'meta.json');
  let metaJson = {};
  if (existsSync(metaJsonPath)) {
    metaJson = JSON.parse(readFileSync(metaJsonPath, 'utf-8'));
  }

  // Read references
  const refsDir = join(dirPath, 'references');
  const references = {};
  if (existsSync(refsDir)) {
    for (const f of readdirSync(refsDir)) {
      references[f] = readFileSync(join(refsDir, f), 'utf-8');
    }
  }

  // Read scripts
  const scriptsDir = join(dirPath, 'scripts');
  const scripts = {};
  if (existsSync(scriptsDir)) {
    for (const f of readdirSync(scriptsDir)) {
      scripts[f] = readFileSync(join(scriptsDir, f), 'utf-8');
    }
  }

  // Read agents
  const agentsDir = join(dirPath, 'agents');
  const agents = {};
  if (existsSync(agentsDir)) {
    for (const f of readdirSync(agentsDir)) {
      agents[f] = readFileSync(join(agentsDir, f), 'utf-8');
    }
  }

  return {
    name: meta.name || metaJson.name || basename(dirPath),
    description: meta.description || metaJson.description || '',
    version: meta.version || metaJson.version || '1.0.0',
    tags: meta.tags || metaJson.tags || [],
    agents: meta.agents || metaJson.agents || [],
    category: metaJson.category || '',
    body,
    raw,
    references,
    scripts,
    agents: agents,  // sub-agents
    dirName: basename(dirPath),
  };
}

function loadAllSkills() {
  const skills = [];
  const entries = readdirSync(SKILLS_DIR);
  for (const entry of entries) {
    if (entry.startsWith('_')) continue; // skip templates
    const fullPath = join(SKILLS_DIR, entry);
    if (!statSync(fullPath).isDirectory()) continue;
    const skill = readSkill(fullPath);
    if (skill) skills.push(skill);
  }
  return skills;
}

function ensureDir(dir) {
  mkdirSync(dir, { recursive: true });
}

function writeGenerated(path, content) {
  ensureDir(join(path, '..'));
  writeFileSync(path, content, 'utf-8');
}

// ─── Agent Adapters ─────────────────────────────────────────────────────────

function buildOpenCode(skills) {
  const outDir = join(DIST_DIR, 'opencode', 'skills');
  ensureDir(outDir);

  for (const skill of skills) {
    const skillDir = join(outDir, skill.dirName);
    ensureDir(skillDir);
    writeFileSync(join(skillDir, 'SKILL.md'), skill.raw, 'utf-8');

    // Copy references
    const refsDir = join(skillDir, 'references');
    ensureDir(refsDir);
    for (const [file, content] of Object.entries(skill.references)) {
      writeFileSync(join(refsDir, file), content, 'utf-8');
    }
    // Copy scripts
    const scriptsDir = join(skillDir, 'scripts');
    ensureDir(scriptsDir);
    for (const [file, content] of Object.entries(skill.scripts)) {
      writeFileSync(join(scriptsDir, file), content, 'utf-8');
    }
    // Copy agents
    const agentsDir = join(skillDir, 'agents');
    ensureDir(agentsDir);
    for (const [file, content] of Object.entries(skill.agents)) {
      writeFileSync(join(agentsDir, file), content, 'utf-8');
    }
  }
  console.log(`  opencode: ${skills.length} skills copied`);
}

function buildClaude(skills) {
  const outDir = join(DIST_DIR, 'claude');
  const rulesDir = join(outDir, '.claude', 'rules');
  ensureDir(rulesDir);

  // Generate CLAUDE.md with imports
  const imports = skills
    .map((s, i) => `@.claude/rules/${String(i + 1).padStart(2, '0')}-${s.dirName}.md`)
    .join('\n');
  const claudeMd = `# Agent Skillpack\n\n## Skills\n\n${imports}\n`;
  writeFileSync(join(outDir, 'CLAUDE.md'), claudeMd, 'utf-8');

  // Generate individual rule files
  for (let i = 0; i < skills.length; i++) {
    const skill = skills[i];
    const filename = `${String(i + 1).padStart(2, '0')}-${skill.dirName}.md`;
    const paths = skill.tags.map(t => `"**/${t}/**"`).join(', ');
    const frontmatter = [
      '---',
      `description: "${skill.description.replace(/"/g, '\\"')}"`,
      paths ? `paths: [${paths}]` : '',
      '---',
    ].filter(Boolean).join('\n');

    const content = `${frontmatter}\n\n${skill.body}`;
    writeFileSync(join(rulesDir, filename), content, 'utf-8');
  }
  console.log(`  claude: ${skills.length} rules generated`);
}

function buildCodex(skills) {
  const outDir = join(DIST_DIR, 'codex');
  ensureDir(outDir);

  const sections = skills.map(skill => {
    return `---\n\n## ${skill.name}\n\n${skill.description}\n\n${skill.body}`;
  });

  const header = `# Agent Skillpack\n\n> ${skills.length} engineering skills for AI coding agents\n\n`;
  const content = header + sections.join('\n\n');
  writeFileSync(join(outDir, 'AGENTS.md'), content, 'utf-8');
  console.log(`  codex: ${skills.length} skills merged into AGENTS.md`);
}

function buildCursor(skills) {
  const outDir = join(DIST_DIR, 'cursor', '.cursor', 'rules');
  ensureDir(outDir);

  for (const skill of skills) {
    const globs = skill.tags.map(t => `**/*${t}*`).join(', ');
    const frontmatter = [
      '---',
      `description: "${skill.description.replace(/"/g, '\\"')}"`,
      globs ? `globs: "${globs}"` : '',
      'alwaysApply: false',
      '---',
    ].filter(Boolean).join('\n');

    const content = `${frontmatter}\n\n${skill.body}`;
    writeFileSync(join(outDir, `${skill.dirName}.mdc`), content, 'utf-8');
  }
  console.log(`  cursor: ${skills.length} .mdc rules generated`);
}

function buildWindsurf(skills) {
  const outDir = join(DIST_DIR, 'windsurf');
  ensureDir(outDir);

  const TOKEN_LIMIT = 6000;
  let content = '# Agent Skillpack\n\n';
  let totalTokens = 0;

  // Rough token estimate: 1 token ≈ 4 chars
  for (const skill of skills) {
    const section = `\n---\n\n## ${skill.name}\n\n${skill.description}\n\n${skill.body}\n`;
    const estTokens = Math.ceil(section.length / 4);
    if (totalTokens + estTokens > TOKEN_LIMIT) {
      console.log(`  windsurf: truncated at ${skills.indexOf(skill)}/${skills.length} (token limit)`);
      break;
    }
    content += section;
    totalTokens += estTokens;
  }

  writeFileSync(join(outDir, '.windsurfrules'), content, 'utf-8');
  console.log(`  windsurf: ${skills.length} skills merged (~${totalTokens} tokens)`);
}

function buildCopilot(skills) {
  const outDir = join(DIST_DIR, 'copilot');
  const instrDir = join(outDir, '.github', 'instructions');
  ensureDir(instrDir);

  // Generate copilot-instructions.md (summary)
  const summaries = skills.map(s => `## ${s.name}\n\n${s.description}\n`);
  const header = `# Agent Skillpack\n\n> ${skills.length} engineering skills\n\n`;
  writeFileSync(join(outDir, '.github', 'copilot-instructions.md'), header + summaries.join('\n'), 'utf-8');

  // Generate individual instruction files
  for (const skill of skills) {
    const applyTo = skill.tags.map(t => `**/*${t}*`).join(', ');
    const frontmatter = [
      '---',
      applyTo ? `applyTo: "${applyTo}"` : '',
      '---',
    ].filter(Boolean).join('\n');

    const content = `${frontmatter}\n\n${skill.body}`;
    writeFileSync(join(instrDir, `${skill.dirName}.instructions.md`), content, 'utf-8');
  }
  console.log(`  copilot: ${skills.length} instructions generated`);
}

function buildCline(skills) {
  const outDir = join(DIST_DIR, 'cline', '.clinerules');
  ensureDir(outDir);

  for (let i = 0; i < skills.length; i++) {
    const skill = skills[i];
    const paths = skill.tags.map(t => `**/${t}/**`);
    const frontmatter = [
      '---',
      `description: "${skill.description.replace(/"/g, '\\"')}"`,
      paths.length ? `paths: [${paths.map(p => `"${p}"`).join(', ')}]` : '',
      'alwaysApply: false',
      '---',
    ].filter(Boolean).join('\n');

    const content = `${frontmatter}\n\n${skill.body}`;
    const filename = `${String(i + 1).padStart(2, '0')}-${skill.dirName}.md`;
    writeFileSync(join(outDir, filename), content, 'utf-8');
  }
  console.log(`  cline: ${skills.length} rules generated`);
}

function buildAider(skills) {
  const outDir = join(DIST_DIR, 'aider');
  ensureDir(outDir);

  // Generate CONVENTIONS.md
  const sections = skills.map(s => `## ${s.name}\n\n${s.description}\n\n${s.body}`);
  const header = `# Project Conventions\n\n> ${skills.length} engineering skills\n\n`;
  writeFileSync(join(outDir, 'CONVENTIONS.md'), header + sections.join('\n\n'), 'utf-8');

  // Generate .aider.conf.yml
  const config = `# Agent Skillpack — Aider Configuration
# Auto-generated by build.js

read:
  - CONVENTIONS.md

# Uncomment to enable auto-linting
# auto-lint: true
# lint-cmd:
#   - "typescript: npm run typecheck"
#   - "python: flake8"
`;
  writeFileSync(join(outDir, '.aider.conf.yml'), config, 'utf-8');
  console.log(`  aider: ${skills.length} skills merged into CONVENTIONS.md`);
}

// ─── Main ───────────────────────────────────────────────────────────────────

function main() {
  const args = process.argv.slice(2);
  const targetIdx = args.indexOf('--target');
  const target = targetIdx !== -1 ? args[targetIdx + 1] : null;

  console.log('Agent Skillpack — Building adapters...\n');

  // Clean dist
  if (existsSync(DIST_DIR)) {
    rmSync(DIST_DIR, { recursive: true, force: true });
  }
  ensureDir(DIST_DIR);

  // Load skills
  const skills = loadAllSkills();
  console.log(`Found ${skills.length} skills\n`);

  if (skills.length === 0) {
    console.log('No skills found in skills/ directory.');
    process.exit(0);
  }

  const builders = {
    opencode: buildOpenCode,
    claude: buildClaude,
    codex: buildCodex,
    cursor: buildCursor,
    windsurf: buildWindsurf,
    copilot: buildCopilot,
    cline: buildCline,
    aider: buildAider,
  };

  if (target) {
    if (!builders[target]) {
      console.error(`Unknown target: ${target}. Available: ${Object.keys(builders).join(', ')}`);
      process.exit(1);
    }
    builders[target](skills);
  } else {
    for (const [name, builder] of Object.entries(builders)) {
      builder(skills);
    }
  }

  console.log('\nDone!');
}

main();
