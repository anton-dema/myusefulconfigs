#!/usr/bin/env bash
# autopush.sh — commit e push automatico per Proxmox-Utils
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# Controlla se ci sono modifiche (staged, unstaged o untracked)
if git diff --quiet && git diff --cached --quiet && \
   [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
    echo "Nessuna modifica da committare."
    exit 0
fi

# Aggiungi tutti i file modificati (esclusi quelli nel .gitignore)
git add -A

# Genera commit message automatico
TIMESTAMP="$(date '+%Y-%m-%d %H:%M')"
CHANGED_FILES="$(git diff --cached --name-only | tr '\n' ' ' | sed 's/ $//')"
COMMIT_MSG="auto: ${TIMESTAMP} — ${CHANGED_FILES}"

git commit -m "$COMMIT_MSG"
git push origin master

echo "Push completato: $COMMIT_MSG"
