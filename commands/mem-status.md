---
name: mem-status
description: Show memory system statistics and health
---

Display comprehensive statistics about the michi-mem memory system. Run the following commands and present the results in a clean format.

## Gather Statistics

Run this script to collect all stats:

```bash
DIARY_DIR="$HOME/.claude/memory/michi-mem/diary"
REFLECTIONS_DIR="$HOME/.claude/memory/michi-mem/reflections"
PROCESSED_LOG="$REFLECTIONS_DIR/processed.log"
CONFIG="$HOME/.claude/memory/michi-mem/config.json"

echo "=== Diary Entries ==="
TOTAL_DIARY=$(ls "$DIARY_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
echo "Total: $TOTAL_DIARY"

RECENT_DIARY=$(find "$DIARY_DIR" -name "*.md" -mtime -30 2>/dev/null | wc -l | tr -d ' ')
echo "Last 30 days: $RECENT_DIARY"

if [ -f "$PROCESSED_LOG" ]; then
  PROCESSED=$(wc -l < "$PROCESSED_LOG" | tr -d ' ')
else
  PROCESSED=0
fi
UNPROCESSED=$((TOTAL_DIARY - PROCESSED))
echo "Unprocessed: $UNPROCESSED"

LAST_DIARY=$(ls -t "$DIARY_DIR"/*.md 2>/dev/null | head -1)
echo "Last diary: ${LAST_DIARY:-none}"

echo ""
echo "=== Reflections ==="
TOTAL_REFLECT=$(ls "$REFLECTIONS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
echo "Total: $TOTAL_REFLECT"

LAST_REFLECT=$(ls -t "$REFLECTIONS_DIR"/*.md 2>/dev/null | head -1)
echo "Last reflection: ${LAST_REFLECT:-none}"

echo ""
echo "=== Storage ==="
du -sh "$HOME/.claude/memory/michi-mem" 2>/dev/null | cut -f1
du -sh "$DIARY_DIR" 2>/dev/null | cut -f1
du -sh "$REFLECTIONS_DIR" 2>/dev/null | cut -f1

echo ""
echo "=== Config ==="
cat "$CONFIG" 2>/dev/null || echo "No config found"
```

## Present Results

Format the output as a clean status report:

```
michi-mem Status
================

Diary Entries
  Total:         [N]
  Last 30 days:  [N]
  Unprocessed:   [N]
  Last entry:    [date or "none"]

Reflections
  Total:         [N]
  Last entry:    [date or "none"]

Storage
  Total:         [size]
  Diary:         [size]
  Reflections:   [size]

Config
  Diary retention:     [N] days
  Reflect threshold:   [N] unprocessed entries
  Reflection retention: permanent
```

If there are 5+ unprocessed diary entries, add a note:
> Tip: You have [N] unprocessed entries. Run `/reflect` to analyze patterns.
