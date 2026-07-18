#!/usr/bin/env bash
set -euo pipefail

# apply-theme.sh — Inject theme colors and fonts into an HTML artifact
# Usage: ./apply-theme.sh <theme-name> [target-file]
#
# Themes: bauhaus-modernism, swiss-typography, memphis-postmodern,
#         brutalist-raw, scandinavian-minimal, japanese-wabi-sabi,
#         midcentury-modern, dark-academia, neo-grotesque, art-deco-revival

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES_DIR="$(dirname "$SCRIPT_DIR")/references"

THEME="${1:-}"
TARGET="${2:-index.html}"

if [[ -z "$THEME" ]]; then
  echo "Usage: $0 <theme-name> [target-file]"
  echo ""
  echo "Available themes:"
  echo "  bauhaus-modernism"
  echo "  swiss-typography"
  echo "  memphis-postmodern"
  echo "  brutalist-raw"
  echo "  scandinavian-minimal"
  echo "  japanese-wabi-sabi"
  echo "  midcentury-modern"
  echo "  dark-academia"
  echo "  neo-grotesque"
  echo "  art-deco-revival"
  exit 1
fi

declare -A THEMES

# Bauhaus Modernism
THEMES[bauhaus-modernism]='{
  "primary": "#E63946",
  "secondary": "#457B9D",
  "accent": "#F4A261",
  "background": "#F1FAEE",
  "surface": "#FFFFFF",
  "text-primary": "#1D3557",
  "text-secondary": "#6B7280",
  "heading-font": "Space Grotesk",
  "body-font": "DM Sans",
  "mono-font": "JetBrains Mono",
  "heading-weight": "700",
  "body-weight": "400"
}'

# Swiss Typography
THEMES[swiss-typography]='{
  "primary": "#000000",
  "secondary": "#D32F2F",
  "accent": "#1976D2",
  "background": "#FAFAFA",
  "surface": "#FFFFFF",
  "text-primary": "#212121",
  "text-secondary": "#757575",
  "heading-font": "Instrument Serif",
  "body-font": "Source Serif 4",
  "mono-font": "IBM Plex Mono",
  "heading-weight": "700",
  "body-weight": "400"
}'

# Memphis Postmodern
THEMES[memphis-postmodern]='{
  "primary": "#FF6B6B",
  "secondary": "#4ECDC4",
  "accent": "#FFE66D",
  "background": "#FFFFFF",
  "surface": "#F7F7F7",
  "text-primary": "#2C3E50",
  "text-secondary": "#7F8C8D",
  "heading-font": "Fraunces",
  "body-font": "Plus Jakarta Sans",
  "mono-font": "Fira Code",
  "heading-weight": "800",
  "body-weight": "400"
}'

# Brutalist Raw
THEMES[brutalist-raw]='{
  "primary": "#1A1A1A",
  "secondary": "#C4C4C4",
  "accent": "#FF4444",
  "background": "#E8E8E8",
  "surface": "#F0F0F0",
  "text-primary": "#0A0A0A",
  "text-secondary": "#555555",
  "heading-font": "Space Grotesk",
  "body-font": "IBM Plex Serif",
  "mono-font": "JetBrains Mono",
  "heading-weight": "700",
  "body-weight": "400"
}'

# Scandinavian Minimal
THEMES[scandinavian-minimal]='{
  "primary": "#2D3436",
  "secondary": "#636E72",
  "accent": "#E17055",
  "background": "#FAF9F6",
  "surface": "#FFFFFF",
  "text-primary": "#2D3436",
  "text-secondary": "#636E72",
  "heading-font": "DM Serif Display",
  "body-font": "Lora",
  "mono-font": "Source Code Pro",
  "heading-weight": "700",
  "body-weight": "400"
}'

# Japanese Wabi-Sabi
THEMES[japanese-wabi-sabi]='{
  "primary": "#3C3C3C",
  "secondary": "#8B7355",
  "accent": "#B85C38",
  "background": "#F5F0EB",
  "surface": "#EDE8E3",
  "text-primary": "#2C2C2C",
  "text-secondary": "#7A7267",
  "heading-font": "Instrument Serif",
  "body-font": "Newsreader",
  "mono-font": "IBM Plex Mono",
  "heading-weight": "600",
  "body-weight": "400"
}'

# Mid-Century Modern
THEMES[midcentury-modern]='{
  "primary": "#D4552B",
  "secondary": "#5B8C5A",
  "accent": "#E8A838",
  "background": "#FDF6E3",
  "surface": "#FFFFFF",
  "text-primary": "#3E3229",
  "text-secondary": "#8C7E6A",
  "heading-font": "Playfair Display",
  "body-font": "Source Serif 4",
  "mono-font": "Fira Code",
  "heading-weight": "700",
  "body-weight": "400"
}'

# Dark Academia
THEMES[dark-academia]='{
  "primary": "#C9B99A",
  "secondary": "#8B6F47",
  "accent": "#7B2D26",
  "background": "#1C1C1C",
  "surface": "#2A2A2A",
  "text-primary": "#E8E0D4",
  "text-secondary": "#9A9088",
  "heading-font": "DM Serif Display",
  "body-font": "Spectral",
  "mono-font": "JetBrains Mono",
  "heading-weight": "700",
  "body-weight": "400"
}'

# Neo-Grotesque
THEMES[neo-grotesque]='{
  "primary": "#0055FF",
  "secondary": "#00CC88",
  "accent": "#FF3366",
  "background": "#F8F9FA",
  "surface": "#FFFFFF",
  "text-primary": "#1A1A2E",
  "text-secondary": "#6C757D",
  "heading-font": "Outfit",
  "body-font": "DM Sans",
  "mono-font": "Source Code Pro",
  "heading-weight": "700",
  "body-weight": "400"
}'

# Art Deco Revival
THEMES[art-deco-revival]='{
  "primary": "#D4AF37",
  "secondary": "#1B1B2F",
  "accent": "#C0392B",
  "background": "#FAFAF0",
  "surface": "#F5F0E6",
  "text-primary": "#1B1B2F",
  "text-secondary": "#6B6B7B",
  "heading-font": "Playfair Display",
  "body-font": "Lora",
  "mono-font": "IBM Plex Mono",
  "heading-weight": "700",
  "body-weight": "400"
}'

if [[ -z "${THEMES[$THEME]+x}" ]]; then
  echo "Error: Unknown theme '$THEME'"
  echo "Run '$0' with no arguments to see available themes."
  exit 1
fi

THEME_JSON="${THEMES[$THEME]}"

if [[ ! -f "$TARGET" ]]; then
  echo "Error: Target file '$TARGET' not found."
  exit 1
fi

# Extract values from theme JSON
get_val() { echo "$THEME_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['$1'])" 2>/dev/null || echo "$THEME_JSON" | python -c "import sys,json; print(json.load(sys.stdin)['$1'])"; }

PRIMARY=$(get_val "primary")
SECONDARY=$(get_val "secondary")
ACCENT=$(get_val "accent")
BG=$(get_val "background")
SURFACE=$(get_val "surface")
TEXT_PRIMARY=$(get_val "text-primary")
TEXT_SECONDARY=$(get_val "text-secondary")
HEADING_FONT=$(get_val "heading-font")
BODY_FONT=$(get_val "body-font")
MONO_FONT=$(get_val "mono-font")
HEADING_WEIGHT=$(get_val "heading-weight")
BODY_WEIGHT=$(get_val "body-weight")

# Build CSS custom properties block
CSS_VARS=":root {
  --color-primary: ${PRIMARY};
  --color-secondary: ${SECONDARY};
  --color-accent: ${ACCENT};
  --color-background: ${BG};
  --color-surface: ${SURFACE};
  --color-text-primary: ${TEXT_PRIMARY};
  --color-text-secondary: ${TEXT_SECONDARY};
  --font-heading: '${HEADING_FONT}', sans-serif;
  --font-body: '${BODY_FONT}', serif;
  --font-mono: '${MONO_FONT}', monospace;
  --font-weight-heading: ${HEADING_WEIGHT};
  --font-weight-body: ${BODY_WEIGHT};
}"

# Google Fonts import
FONTS_URL="https://fonts.googleapis.com/css2?family=$(echo "$HEADING_FONT" | tr ' ' '+')&family=$(echo "$BODY_FONT" | tr ' ' '+')&family=$(echo "$MONO_FONT" | tr ' ' '+')&display=swap"
FONTS_IMPORT="@import url('${FONTS_URL}');"

# Inject into HTML
if grep -q "data-theme-applied" "$TARGET" 2>/dev/null; then
  echo "Theme already applied to $TARGET. Replace or remove existing theme block first."
  exit 1
fi

# Create temp file with injection
TEMP_FILE=$(mktemp)
{
  echo "<!-- data-theme-applied: ${THEME} -->"
  echo "<style>"
  echo "$FONTS_IMPORT"
  echo ""
  echo "$CSS_VARS"
  echo ""
  echo "body {"
  echo "  font-family: var(--font-body);"
  echo "  font-weight: var(--font-weight-body);"
  echo "  color: var(--color-text-primary);"
  echo "  background-color: var(--color-background);"
  echo "}"
  echo ""
  echo "h1, h2, h3, h4, h5, h6 {"
  echo "  font-family: var(--font-heading);"
  echo "  font-weight: var(--font-weight-heading);"
  echo "  color: var(--color-text-primary);"
  echo "}"
  echo ""
  echo "code, pre, .mono {"
  echo "  font-family: var(--font-mono);"
  echo "}"
  echo ""
  echo ".surface, .card {"
  echo "  background-color: var(--color-surface);"
  echo "}"
  echo ""
  echo "a {"
  echo "  color: var(--color-secondary);"
  echo "}"
  echo ""
  echo ".btn-primary {"
  echo "  background-color: var(--color-primary);"
  echo "  color: var(--color-surface);"
  echo "  border: none;"
  echo "  padding: 0.5rem 1rem;"
  echo "  cursor: pointer;"
  echo "}"
  echo ""
  echo ".accent {"
  echo "  color: var(--color-accent);"
  echo "}"
  echo "</style>"
} > "$TEMP_FILE"

# Insert before </head> or at top
if grep -q "</head>" "$TARGET"; then
  sed -i "/<\/head>/r $TEMP_FILE" "$TARGET"
else
  # Prepend if no </head> found
  cat "$TEMP_FILE" "$TARGET" > "${TARGET}.tmp" && mv "${TARGET}.tmp" "$TARGET"
fi

rm -f "$TEMP_FILE"

echo "Theme '$THEME' applied to $TARGET"
echo "  Primary:     $PRIMARY"
echo "  Secondary:   $SECONDARY"
echo "  Accent:      $ACCENT"
echo "  Background:  $BG"
echo "  Surface:     $SURFACE"
echo "  Heading:     $HEADING_FONT"
echo "  Body:        $BODY_FONT"
echo "  Mono:        $MONO_FONT"
