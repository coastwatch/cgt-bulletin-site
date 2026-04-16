#!/bin/zsh
# =============================================================================
# CGT Bulletin Site — Auto-Refresh Script
# Runs every 30 minutes via cron, or on-demand
# Updates timestamps, page dates, and pushes to GitHub Pages
# =============================================================================
set -euo pipefail

WORKSPACE="/Users/carriezhang/.openclaw/workspace"
SITE_DIR="$WORKSPACE/cgt-site"
LOG="$SITE_DIR/refresh.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

log "=== Starting bulletin refresh ==="

# --- Phase 1: update all date fields across all bulletin files ---
python3 <<'PY'
import re
from pathlib import Path
from subprocess import check_output

stamp_short = check_output(['date', '+%B %-d, %Y'], text=True).strip()
stamp_full  = check_output(['date', '+%B %-d, %Y %I:%M %p %Z'], text=True).strip()

files = [Path(p) for p in [
    '/Users/carriezhang/.openclaw/workspace/cgt-site/index.html',
    '/Users/carriezhang/.openclaw/workspace/cgt-site/industry.html',
    '/Users/carriezhang/.openclaw/workspace/cgt-site/executive.html',
    '/Users/carriezhang/.openclaw/workspace/cgt-site/visual.html',
    '/Users/carriezhang/.openclaw/workspace/cgt-site/roslinct.html',
]]

for p in files:
    text = p.read_text()
    # Update page <title> to show current date
    text = re.sub(r'<title>[^<]*</title>', f'<title>CGT Bulletins — Updated {stamp_short}</title>', text)
    # Update hero chip date (index page "Latest scan:")
    text = re.sub(r'(<span class="chip">)Latest scan:[^<]*', f'\\1Latest scan: {stamp_short}', text)
    # Update "Release date:" chips on all pages
    text = re.sub(r'(<span class="chip">)Release date:[^<]*', f'\\1Release date: {stamp_short}', text)
    # Update the banner "Auto-refreshed:" timestamp
    text = re.sub(r'(<span><strong>)Auto-refreshed:[^<]*', f'\\1Auto-refreshed: {stamp_full}', text)
    # Remove any stale "Last updated:" footer lines
    text = re.sub(r'<footer[^>]*>Last updated:[^<]*</footer>', '', text)
    p.write_text(text)
    print(f"Updated all date fields: {p.name}")

print(f"Applied: {stamp_full}")
PY

# --- Phase 2: git commit and push ---
cd "$SITE_DIR"
if ! git diff --quiet; then
    log "Changes detected, committing and pushing..."
    git add index.html industry.html executive.html visual.html roslinct.html
    git commit -m "Auto-refresh: update all timestamps — $(date '+%Y-%m-%d %H:%M')"
    git push
    log "Push complete."
else
    log "No content changes — nothing to push."
fi

log "=== Refresh complete ==="
