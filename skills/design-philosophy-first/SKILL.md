---
name: design-philosophy-first
description: Guides visual output through a philosophy-first approach — every design artifact starts from a named movement and articulates principles before touching pixels. Prevents generic AI aesthetics by grounding decisions in intentional philosophy.
version: 1.0.0
tags: [design, visuals, themes, philosophy]
agents: [all]
category: design
---

# Design Philosophy First

## Overview

Before choosing colors, fonts, or layouts, define the *philosophy* behind the visual output. A design philosophy is a short, opinionated manifesto that names the aesthetic movement you're channeling and articulates the principles governing every visual decision. It acts as a contract: every pixel choice must trace back to a stated principle. This approach transforms visual output from "whatever the AI defaults to" into intentional, memorable design.

Philosophy-first design means:
- **Named inspiration**: Reference a real aesthetic tradition (Bauhaus, Swiss Typography, Memphis, Brutalism, etc.)
- **Articulated principles**: 4-6 clear rules that constrain color, typography, spacing, and composition
- **Craftsmanship**: Treat every visual decision as a deliberate choice, not a default

## When to Use

Use this skill for **any** visual output — HTML artifacts, landing pages, dashboards, presentations, diagrams, or any deliverable where aesthetics matter. If a human will look at it, apply philosophy-first design.

## Two-Step Process

### Step 1: Create the Philosophy

Before any code or design work, write a philosophy document following the template below. This is non-negotiable — even for quick prototypes.

### Step 2: Express on Canvas

Translate the philosophy into visual implementation. Every design decision (color, font, spacing, layout) must reference a principle from the philosophy.

## Philosophy Template

```markdown
# [Movement Name] Design Philosophy

## Inspiration
This design draws from the [Movement Name] tradition, specifically
[influences, eras, or practitioners].

## Principles

### 1. [Principle Name]
[One sentence stating the rule.]
**Application:** [How this constrains visual decisions.]

### 2. [Principle Name]
[One sentence stating the rule.]
**Application:** [How this constrains visual decisions.]

### 3. [Principle Name]
[One sentence stating the rule.]
**Application:** [How this constrains visual decisions.]

### 4. [Principle Name]
[One sentence stating the rule.]
**Application:** [How this constrains visual decisions.]

## Craftsmanship Commitments
- Every color is named and has a hex value justified by the philosophy
- Every font choice maps to a specific principle
- Every spacing decision references the rhythm system defined below
- No visual element exists without a reason
```

## Theme Application

After defining a philosophy, select or adapt from 10 pre-built palettes defined in `references/theme-palettes.md`. Each palette includes:
- Hex color codes (primary, secondary, accent, background, surface, text)
- Font stack recommendations
- Mood description
- Movement alignment

Run `scripts/apply-theme.sh <theme-name>` to inject theme variables into an HTML artifact.

## Anti-AI-Slop Rules

Apply these rules to every visual output. See `references/anti-ai-slop.md` for the full 20+ rule set.

1. **No purple gradients** — purple gradients are the single strongest signal of generic AI output
2. **No uniform rounded corners** — use varied radii (2px, 4px, 8px, 12px) intentionally
3. **No Inter font** — Inter is overused in AI-generated designs; pick a typeface with character
4. **No centered-everything** — use asymmetric layouts, left-aligned text, intentional alignment
5. **No drop shadows on everything** — use shadows sparingly and only where hierarchy demands it
6. **No equal spacing everywhere** — use a spatial scale (4px base) with clear rhythm
7. **No blue-to-purple or pink-to-purple gradients** — the most cliched AI color combination
8. **No glassmorphism by default** — only use frosted glass effects when the philosophy calls for them
9. **No generic icon sets** — choose icons that match the design's personality
10. **No filler text or placeholder content** — use real, meaningful copy

## Font Pairing System

Every philosophy should define font pairings from these categories:

| Role | Options (pick ONE) |
|------|---------------------|
| **Display / Heading** | Playfair Display, Space Grotesk, DM Serif Display, Instrument Serif, Fraunces |
| **Body** | Source Serif 4, Lora, IBM Plex Serif, Newsreader, Spectral |
| **Mono / Code** | JetBrains Mono, Fira Code, IBM Plex Mono, Source Code Pro |
| **UI / Small** | DM Sans, Plus Jakarta Sans, Outfit, Manrope, Sora |

Rules:
- Never pair two fonts from the same classification (e.g., two sans-serifs)
- Display and Body must contrast in weight and x-height
- Limit to 2-3 fonts maximum per philosophy
- Justify every font choice with a philosophy principle

## Common Rationalizations

| Rationalization | Why It's Wrong | What to Do Instead |
|-----------------|----------------|---------------------|
| "Purple gradients look modern" | They look generic and AI-generated | Choose colors from your philosophy's palette |
| "Rounded corners are friendlier" | Uniform rounding removes intentional hierarchy | Use varied radii based on element importance |
| "Centered text is cleaner" | It's lazy alignment that avoids compositional decisions | Align to grid, use intentional asymmetry |
| "Glassmorphism is trendy" | It's a crutch that hides lack of real design system | Only use when philosophy explicitly calls for translucency |
| "Inter is a safe choice" | Safe choices produce forgettable output | Pick a typeface with personality that serves the philosophy |
| "Shadows add depth" | Excessive shadows flatten rather than add depth | Use one elevation system with 2-3 levels max |
| "More colors = more vibrant" | Limited palettes with intentional accents are stronger | Stick to 5-6 colors max, use restraint |
| "This is just a quick prototype" | Quick output still creates impressions | Apply philosophy even to prototypes — it's faster than you think |

## Red Flags

Stop and reconsider if you notice:
- You're reaching for purple, blue-purple, or pink-purple combinations
- Every element has the same border-radius
- Text is centered in every section
- You're adding gradients "to make it pop"
- You haven't named the design movement or cited influences
- You can't explain why a specific color or font was chosen
- The design would be indistinguishable from any other AI output

## Verification

Before shipping any visual output, confirm:

- [ ] Philosophy document exists with a named movement
- [ ] 4-6 principles are stated with clear applications
- [ ] Every color has a hex code and philosophical justification
- [ ] Font choices are justified by principles, not habit
- [ ] No anti-AI-slop rules are violated
- [ ] Layout uses intentional alignment, not default centering
- [ ] Spacing follows a defined spatial scale
- [ ] The design would be identifiable as belonging to a specific tradition
- [ ] You can point to the philosophy and say *why* each visual choice was made
