---
name: reflect
description: Analyze diary entries to identify patterns and propose CLAUDE.md updates
---

Analyze unprocessed diary entries to find patterns and distill persistent knowledge. Follow these steps exactly:

## Step 1: Check for Unprocessed Entries

```bash
DIARY_DIR="$HOME/.claude/memory/michi-mem/diary"
REFLECTIONS_DIR="$HOME/.claude/memory/michi-mem/reflections"
PROCESSED_LOG="$REFLECTIONS_DIR/processed.log"
mkdir -p "$REFLECTIONS_DIR"
touch "$PROCESSED_LOG"

echo "=== All diary files ==="
ls -1 "$DIARY_DIR"/*.md 2>/dev/null | xargs -I{} basename {}

echo "=== Already processed ==="
cat "$PROCESSED_LOG"
```

Identify which diary files have NOT been processed yet (their basename is not in `processed.log`). If there are no unprocessed entries, tell the user and stop.

## Step 2: Read Unprocessed Entries

Read each unprocessed diary file using the Read tool. Collect all content for analysis.

## Step 3: Pattern Analysis

Analyze the unprocessed diary entries together. Look for:

- **Repeated decisions**: Same type of technical choice made 2+ times
- **Recurring preferences**: Coding style, tool usage, workflow habits appearing across sessions
- **Repeated challenges**: Same problems surfacing multiple times
- **Workflow patterns**: How the user approaches tasks, what they prioritize
- **Project patterns**: Architecture decisions, naming conventions, file organization

Classify patterns by strength:
- **Strong** (3+ occurrences): High confidence, should become rules
- **Moderate** (2 occurrences): Worth noting, may become rules with more evidence
- **Emerging** (1 occurrence but significant): Track for future reflection

## Step 4: Determine Reflection Number

```bash
REFLECTIONS_DIR="$HOME/.claude/memory/michi-mem/reflections"
MONTH=$(date +%Y-%m)
COUNT=$(ls "$REFLECTIONS_DIR"/${MONTH}-reflection-*.md 2>/dev/null | wc -l | tr -d ' ')
echo $((COUNT + 1))
```

## Step 5: Write Reflection

Write a reflection file to `~/.claude/memory/michi-mem/reflections/YYYY-MM-reflection-N.md`:

```markdown
# Reflection: YYYY-MM

**Entries analyzed**: [count]
**Date range**: [earliest] to [latest]

## Strong Patterns
- [pattern]: [evidence summary]

## Moderate Patterns
- [pattern]: [evidence summary]

## Emerging Observations
- [observation]: [source session]

## Proposed CLAUDE.md Updates
- [specific rule or preference to add]
```

## Step 6: Update processed.log

Append the basename of each processed diary file to `processed.log`, one per line:

```bash
PROCESSED_LOG="$HOME/.claude/memory/michi-mem/reflections/processed.log"
# Append each processed file basename
echo "YYYY-MM-DD-session-N.md" >> "$PROCESSED_LOG"
```

## Step 7: Propose CLAUDE.md Updates

If strong patterns were found, propose specific additions to `~/.claude/CLAUDE.md`. Present the proposed changes to the user in a clear format:

```
Proposed additions to CLAUDE.md:
- [rule 1]
- [rule 2]
```

Ask the user: "Should I add these to your CLAUDE.md?"

If the user agrees, read `~/.claude/CLAUDE.md`, find or create a `## Learned Preferences` section, and append the new rules as bullet points. If the section already exists, merge new rules with existing ones (avoid duplicates).

If only moderate patterns were found, mention them but don't propose CLAUDE.md changes yet. Say they'll be re-evaluated in the next reflection.

## Step 8: Report

Summarize what was found:
- Number of entries analyzed
- Patterns discovered (strong/moderate/emerging counts)
- Whether CLAUDE.md was updated
- Path to the reflection file
