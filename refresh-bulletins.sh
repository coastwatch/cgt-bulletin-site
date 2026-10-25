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
    # Update the banner "Auto-refreshed:" timestamp and remove any stale trailing timestamp text
    text = re.sub(r'<span><strong>Auto-refreshed:[^<]*</strong>[^<]*</span>', f'<span><strong>Auto-refreshed: {stamp_full}</strong></span>', text)
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
    # Never let a missing/expired credential break the cron run silently.
    # GIT_TERMINAL_PROMPT=0 makes git fail fast with a clear error instead of hanging.
    # Credential fallback: the macOS keychain is not reliably reachable from the
    # cron/launchd context, so prefer an explicit 0600 credential file when present.
    CRED_FILE="/Users/carriezhang/.openclaw/credentials/github/git-credentials-coastwatch"
    GIT_ENV=()
    if [[ -r "$CRED_FILE" ]]; then
        GIT_ENV=(-c "credential.https://github.com.helper=store --file=$CRED_FILE")
    fi
    if GIT_TERMINAL_PROMPT=0 git "${GIT_ENV[@]}" push origin main 2>&1 | tee -a "$LOG"; then
        log "Push complete."
    else
        log "PUSH FAILED — content is committed locally but not deployed."
        log "Diagnose with: git config --list --show-origin | grep credential"
        log "See learned skill 'github-push-credential-repair'."
    fi
else
    log "No content changes — nothing to push."
fi

log "=== Refresh complete ==="
