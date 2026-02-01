#!/bin/bash
set -euo pipefail
# michi-mem cleanup: removes old diary entries and stale state files
# Called automatically by SessionEnd hook

DIARY_DIR="$HOME/.claude/memory/michi-mem/diary"
STATE_DIR="$HOME/.claude/memory/michi-mem/.state"
CONFIG="$HOME/.claude/memory/michi-mem/config.json"

RETENTION_DAYS=30
if [ -f "$CONFIG" ]; then
  CONFIGURED=$(grep -o '"diary_retention_days":[[:space:]]*[0-9]*' "$CONFIG" | grep -o '[0-9]*' || true)
  if [ -n "$CONFIGURED" ]; then
    RETENTION_DAYS=$CONFIGURED
  fi
fi

if [ -d "$DIARY_DIR" ]; then
  DELETED=$(find "$DIARY_DIR" -name "*.md" -mtime +$RETENTION_DAYS -delete -print 2>/dev/null | wc -l | tr -d ' ' || echo "0")
  if [ "$DELETED" -gt 0 ]; then
    echo "michi-mem: cleaned up $DELETED diary entries older than $RETENTION_DAYS days"
  fi
fi

if [ -d "$STATE_DIR" ]; then
  find "$STATE_DIR" -type f -mtime +1 -delete 2>/dev/null || true
fi
