#!/bin/zsh
# =============================================================================
# CGT Bulletin Site — Auto-Refresh Script
# Runs every 30 minutes via cron, or on-demand
# =============================================================================
set -euo pipefail

WORKSPACE="/Users/carriezhang/.openclaw/workspace"
SITE_DIR="$WORKSPACE/cgt-site"
TODAY=$(date +%F)
STAMP=$(date '+%B %-d, %Y %I:%M %p %Z')
LOG="$SITE_DIR/refresh.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

log "=== Starting bulletin refresh ==="

# --- Phase 1: update timestamps across all bulletin files ---
python3 <<'PY'
import re
from pathlib import Path
from subprocess import check_output

stamp = check_output(['date', '+%B %-d, %Y %I:%M %p %Z'], text=True).strip()

files = [
    Path('/Users/carriezhang/.openclaw/workspace/cgt-site/index.html'),
    Path('/Users/carriezhang/.openclaw/workspace/cgt-site/industry.html'),
    Path('/Users/carriezhang/.openclaw/workspace/cgt-site/executive.html'),
    Path('/Users/carriezhang/.openclaw/workspace/cgt-site/visual.html'),
    Path('/Users/carriezhang/.openclaw/workspace/cgt-site/roslinct.html'),
]

for p in files:
    text = p.read_text()
    # replace the update-banner scan date
    text = re.sub(
        r'Last full scan:[^<]*',
        f'Last full scan: {stamp}',
        text
    )
    # replace any stale "Last updated:" footer line
    if 'Last updated:' in text:
        text = re.sub(
            r'Last updated:[^<]*',
            f'Last updated: {stamp}',
            text
        )
    p.write_text(text)
    print(f"Updated: {p.name}")
PY

# --- Phase 2: git commit and push ---
cd "$SITE_DIR"
if ! git diff --quiet; then
    log "Changes detected, committing and pushing..."
    git add index.html industry.html executive.html visual.html roslinct.html
    git commit -m "Auto-refresh: update timestamps — $STAMP"
    git push
    log "Push complete."
else
    log "No changes — nothing to push."
fi

log "=== Refresh complete ==="
