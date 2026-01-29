#!/bin/bash
# michi-mem auto-diary: Stop hook that prompts Claude to create diary entries
# Tracks session turns via state files, only prompts after min_turns threshold

CONFIG="$HOME/.claude/memory/michi-mem/config.json"
STATE_DIR="$HOME/.claude/memory/michi-mem/.state"
mkdir -p "$STATE_DIR"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id','unknown'))" 2>/dev/null)

if [ "$SESSION_ID" = "unknown" ] || [ -z "$SESSION_ID" ]; then
  exit 0
fi

AUTO_RECORD=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('auto_record', True))" 2>/dev/null || echo "True")
if [ "$AUTO_RECORD" = "False" ] || [ "$AUTO_RECORD" = "false" ]; then
  exit 0
fi

if [ -f "$STATE_DIR/${SESSION_ID}.diary" ]; then
  exit 0
fi

TURN_FILE="$STATE_DIR/${SESSION_ID}.turns"
TURNS=0
if [ -f "$TURN_FILE" ]; then
  TURNS=$(cat "$TURN_FILE")
fi
TURNS=$((TURNS + 1))
echo "$TURNS" > "$TURN_FILE"

MIN_TURNS=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('auto_record_min_turns', 3))" 2>/dev/null || echo "3")
if [ "$TURNS" -lt "$MIN_TURNS" ]; then
  exit 0
fi

if [ -f "$STATE_DIR/${SESSION_ID}.prompted" ]; then
  exit 0
fi
touch "$STATE_DIR/${SESSION_ID}.prompted"

printf '{"systemMessage": "[michi-mem] Auto-diary: This session has had %d+ turns of meaningful work. Please create a diary entry to preserve session knowledge. Use the Skill tool with skill=\\\"diary\\\"."}\n' "$TURNS"
