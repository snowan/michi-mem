---
name: diary
description: Create a structured diary entry from the current session transcript
---

Create a structured diary entry from the current session. Follow these steps exactly:

## Step 1: Gather Context

Use Bash to get the current date, working directory, and git branch:
```
date +%Y-%m-%d
pwd
git branch --show-current 2>/dev/null || echo "no git repo"
```

## Step 2: Determine Session Number

Use Bash to count existing diary files for today to determine the session number:
```
TODAY=$(date +%Y-%m-%d)
DIARY_DIR="$HOME/.claude/memory/michi-mem/diary"
mkdir -p "$DIARY_DIR"
COUNT=$(ls "$DIARY_DIR"/${TODAY}-session-*.md 2>/dev/null | wc -l | tr -d ' ')
echo $((COUNT + 1))
```

## Step 3: Analyze the Conversation

Review the full conversation transcript. Identify:
- What the user worked on
- Key accomplishments
- Technical decisions made and their rationale
- User preferences observed (coding style, workflow habits, tool preferences)
- Challenges encountered and how they were resolved
- Recurring patterns worth remembering

## Step 4: Write Diary Entry

Write a markdown file to `~/.claude/memory/michi-mem/diary/YYYY-MM-DD-session-N.md` using this format:

```markdown
# Session Diary: YYYY-MM-DD

**Project**: [working directory path]
**Branch**: [git branch]
**Session**: N

## What Happened
[2-3 sentence summary of the session]

## Work Done
- [bullet list of accomplishments]

## Decisions Made
- [key technical decisions with brief rationale]

## Preferences Observed
- [user preferences that should persist]

## Challenges & Solutions
- [problems encountered and how they were resolved]

## Patterns
- [code patterns, workflow patterns worth remembering]
```

Only include sections that have content. Skip empty sections entirely.

## Step 5: Mark Session as Recorded

Signal to the auto-diary hook that this session already has a diary entry, so it stops prompting:

```bash
STATE_DIR="$HOME/.claude/memory/michi-mem/.state"
mkdir -p "$STATE_DIR"
# Mark all active sessions (any session with a .turns file) as having a diary
for f in "$STATE_DIR"/*.turns; do
  [ -f "$f" ] || continue
  SESSION_ID=$(basename "$f" .turns)
  touch "$STATE_DIR/$SESSION_ID.diary"
done
```

## Step 6: Auto-Reflect Check

After saving the diary entry, check if automatic reflection should trigger:

```bash
DIARY_DIR="$HOME/.claude/memory/michi-mem/diary"
PROCESSED_LOG="$HOME/.claude/memory/michi-mem/reflections/processed.log"
touch "$PROCESSED_LOG"

# Count diary files not yet processed
TOTAL=$(ls "$DIARY_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
PROCESSED=$(wc -l < "$PROCESSED_LOG" | tr -d ' ')
UNPROCESSED=$((TOTAL - PROCESSED))
echo "Unprocessed diary entries: $UNPROCESSED"
```

If there are **5 or more** unprocessed entries, announce to the user:
> "You have [N] unprocessed diary entries. Running automatic reflection..."

Then execute the full reflection logic from the `/reflect` command inline:
1. Read all diary files in `~/.claude/memory/michi-mem/diary/` whose filenames are NOT listed in `processed.log`
2. Identify recurring patterns (2+ occurrences = pattern, 3+ = strong pattern)
3. Write a reflection file to `~/.claude/memory/michi-mem/reflections/YYYY-MM-reflection-N.md`
4. Append the processed diary filenames (one per line, basename only) to `processed.log`
5. If strong patterns were found, propose additions to `~/.claude/CLAUDE.md` and apply them after user confirmation

## Step 7: Confirm

Tell the user the diary entry was saved, including the file path and a brief summary of what was recorded. If auto-reflect triggered, also summarize the reflection results.
