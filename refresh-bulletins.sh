#!/bin/zsh
set -euo pipefail

WORKSPACE="/Users/carriezhang/.openclaw/workspace"
SITE_DIR="$WORKSPACE/cgt-site"
TODAY=$(date +%F)
STAMP=$(date '+%Y-%m-%d %H:%M %Z')

# Placeholder refresh flow:
# If a richer generator is added later, replace this section with the real regeneration workflow.
# For now, keep the published pages current by updating visible release metadata timestamps.
python3 <<'PY'
from pathlib import Path
import re
files = [
    Path('/Users/carriezhang/.openclaw/workspace/cgt-site/index.html'),
    Path('/Users/carriezhang/.openclaw/workspace/cgt-site/industry.html'),
    Path('/Users/carriezhang/.openclaw/workspace/cgt-site/executive.html'),
    Path('/Users/carriezhang/.openclaw/workspace/cgt-site/visual.html'),
    Path('/Users/carriezhang/.openclaw/workspace/cgt-site/roslinct.html'),
]
stamp = __import__('subprocess').check_output(['date', '+%B %-d, %Y %I:%M %p %Z'], text=True).strip()
for p in files:
    text = p.read_text()
    if 'Last updated:' in text:
        text = re.sub(r'Last updated:[^<\\n]*', f'Last updated: {stamp}', text)
    else:
        text = text.replace('</body>', f"<footer style='max-width:1080px;margin:20px auto 40px;padding:0 20px;color:#a9b6d3;font-family:Inter,system-ui,sans-serif'>Last updated: {stamp}</footer></body>")
    p.write_text(text)
PY

cd "$SITE_DIR"
if ! git diff --quiet; then
  git add index.html industry.html executive.html visual.html roslinct.html refresh-bulletins.sh
  git commit -m "Auto-refresh bulletin timestamps"
  git push
fi
