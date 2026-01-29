# Architecture Documentation

Technical deep dive into michi-mem's design, implementation, and extension points.

## Table of Contents

- [Design Philosophy](#design-philosophy)
- [System Components](#system-components)
- [Data Flow](#data-flow)
- [File Formats](#file-formats)
- [Extension Points](#extension-points)
- [Design Decisions](#design-decisions)

## Design Philosophy

### Core Principle: Ephemeral Raw Data, Permanent Insights

michi-mem is built on a key insight: **raw conversation data is verbose and grows unbounded, but patterns are concise and timeless**.

**The 3-stage pipeline**:

1. **Diary (Ephemeral)** - Capture everything from sessions
   - High detail, context-rich
   - Useful for short-term pattern detection
   - Auto-deleted after configured retention period (default 30 days)

2. **Reflect (Permanent)** - Extract patterns from diaries
   - Condensed insights
   - Pattern frequency tracked (strong, moderate, emerging)
   - Never deleted

3. **Cleanup (Automatic)** - Manage storage
   - Remove old raw data
   - Preserve processed insights
   - Maintain minimal storage footprint

**Benefits**:
- Scales indefinitely (only insights accumulate)
- No manual pruning required
- Rich short-term context for pattern detection
- Concise long-term memory for Claude Code

### Design Goals

1. **Zero-overhead**: Hooks must be fast, never interrupt user workflow
2. **Fail-silent**: Errors logged but don't break Claude Code sessions
3. **Transparent**: User always knows what data exists and why
4. **Extensible**: Easy to add new analysis patterns or export formats
5. **Testable**: All components have clear interfaces and unit tests

## System Components

### 1. Plugin Manifest (`.claude-plugin/plugin.json`)

Defines plugin metadata and registration:

```json
{
  "name": "michi-mem",
  "version": "1.0.0",
  "description": "Automated memory lifecycle",
  "commands": [
    {
      "name": "diary",
      "description": "Create diary entry from session",
      "file": "commands/diary.md"
    },
    ...
  ],
  "hooks": "scripts/hooks/hooks.json"
}
```

**Purpose**: Registers commands and hooks with Claude Code.

**Why JSON?** Claude Code's plugin system requires this format.

### 2. Hook Scripts (Bash)

Lightweight bash scripts that integrate with Claude Code lifecycle:

#### `scripts/hooks/auto-diary.sh`

Triggered by: `Stop` hook (after conversation pauses/ends)

```bash
#!/bin/bash
set -euo pipefail

# Quick validation (no Python overhead)
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
TURN_COUNT="${CLAUDE_TURN_COUNT:-0}"

# Early exit if session too short
if [[ "$TURN_COUNT" -lt 3 ]]; then
    exit 0
fi

# Delegate to Python for complex logic
python3 -m scripts.lib.diary_writer "$SESSION_ID"
```

**Design rationale**:
- Fast startup (bash is instant, Python has import overhead)
- Simple validation logic in bash
- Complex analysis in Python
- Async execution (doesn't block user)

#### `scripts/hooks/cleanup.sh`

Triggered by: `SessionEnd` hook (when Claude Code exits)

```bash
#!/bin/bash
set -euo pipefail

DIARY_DIR="$HOME/.claude/memory/michi-mem/diary"
RETENTION_DAYS=30

# Find and remove old diary entries
find "$DIARY_DIR" -name "*.md" -mtime +$RETENTION_DAYS -delete

# Reflections directory untouched (permanent)
```

**Design rationale**:
- Simple file operations (no Python needed)
- Runs in background (async)
- Safe deletion (only targets diary/*.md)

#### `scripts/hooks/hooks.json`

Hook registration manifest:

```json
{
  "Stop": {
    "script": "scripts/hooks/auto-diary.sh",
    "async": true
  },
  "SessionEnd": {
    "script": "scripts/hooks/cleanup.sh",
    "async": true
  }
}
```

**Async execution**: Critical for zero-overhead goal. Hooks never block user.

### 3. Python Analysis Modules

Heavyweight logic implemented in Python for maintainability:

#### `scripts/lib/config.py`

Configuration management with validation:

```python
class MemConfig:
    """Singleton configuration manager."""

    def __init__(self, config_path: Path = None):
        self.path = config_path or Path.home() / ".claude/memory/michi-mem/config.json"
        self._config = self._load()

    def _load(self) -> Dict[str, Any]:
        """Load config with defaults, validate types."""
        defaults = {...}
        if not self.path.exists():
            self._create_defaults(defaults)
            return defaults

        # Merge user config with defaults
        # Validate ranges and types
        # Return validated config
```

**Responsibilities**:
- Load configuration from JSON
- Merge user config with defaults
- Validate ranges (positive integers, etc.)
- Auto-create config if missing

**Why Python?** Type validation, JSON parsing, clear error messages.

#### `scripts/lib/diary_writer.py`

Diary entry creation:

```python
class DiaryWriter:
    """Handles diary entry creation."""

    def create_entry(self, content: Dict[str, Any]) -> Path:
        """
        Create diary entry with session context.

        Returns:
            Path to created diary file
        """
        # Generate unique filename (date + session number)
        # Format as structured markdown
        # Atomic write (temp file then rename)
        # Return path
```

**Responsibilities**:
- Generate unique filenames (date-session-N.md)
- Format content as markdown
- Atomic writes (prevent corruption)
- Extract git context if available

**Key implementation details**:

```python
def _get_next_session_number(self, date: str) -> int:
    """Count existing sessions for today."""
    pattern = f"{date}-session-*.md"
    existing = list(self.diary_dir.glob(pattern))
    return len(existing) + 1

def _format_entry(self, content: Dict[str, Any], date: str, session: int) -> str:
    """Format diary entry as markdown."""
    # Structured sections:
    # - Header (date, project, branch, session)
    # - What Happened (summary)
    # - Work Done (bulleted list)
    # - Decisions Made
    # - Preferences Expressed
    # - Challenges Encountered
    # - Patterns Observed
```

**Atomic write pattern**:
```python
temp_path = filepath.with_suffix('.tmp')
temp_path.write_text(markdown)
temp_path.rename(filepath)  # Atomic on POSIX
```

Prevents partial writes if process interrupted.

#### `scripts/lib/pattern_analyzer.py`

Pattern detection from diary entries:

```python
class PatternAnalyzer:
    """Analyzes diary entries to detect patterns."""

    def get_unprocessed_entries(self) -> List[Path]:
        """Find diary entries not yet reflected on."""
        all_entries = set(f.name for f in self.diary_dir.glob("*.md"))
        processed = set(self.processed_log.read_text().splitlines())
        return sorted(all_entries - processed)

    def analyze(self, entries: List[Path]) -> Dict[str, Any]:
        """
        Analyze entries for patterns.

        Returns:
            - strong_patterns: 3+ occurrences
            - moderate_patterns: 2 occurrences
            - emerging_observations: 1 occurrence
        """
        # Parse entries for preferences, decisions, challenges
        # Count occurrences (collections.Counter)
        # Classify by frequency
        # Return structured results
```

**Responsibilities**:
- Track processed vs unprocessed entries
- Parse diary markdown (extract sections)
- Count pattern occurrences
- Classify patterns by strength
- Update processed log

**Pattern classification**:
```python
pref_counts = Counter(preferences)

strong = [p for p, count in pref_counts.items() if count >= 3]
moderate = [p for p, count in pref_counts.items() if count == 2]
emerging = [p for p, count in pref_counts.items() if count == 1]
```

Thresholds chosen empirically:
- **3+ occurrences**: Strong signal, worth highlighting
- **2 occurrences**: Moderate signal, watch for confirmation
- **1 occurrence**: Emerging, may or may not recur

### 4. Command Skills (Markdown)

User-facing commands implemented as Claude Code skills:

Structure:
```markdown
---
name: command-name
description: Brief description
---

Detailed instructions for Claude Code to execute the command.

## Section 1: Gather Data
Run scripts, collect context...

## Section 2: Process Data
Analyze, format...

## Section 3: Present Results
Display to user...
```

**Why markdown?** Claude Code's skill system uses markdown for:
- Natural language instructions
- Embedded code blocks (bash, Python)
- Structured output formatting

Example: `commands/diary.md`

```markdown
---
name: diary
description: Create a structured diary entry from the current session
---

Create a comprehensive diary entry by gathering context and formatting it.

## Gather Context

1. Get session context:
   - Project path and name
   - Git branch (if available)
   - Session duration

2. Ask user for content:
   - What was accomplished?
   - Were any decisions made?
   - Any preferences or patterns noticed?

## Create Entry

Run Python diary writer:

```bash
python3 -c "
from scripts.lib.diary_writer import DiaryWriter
from pathlib import Path

writer = DiaryWriter(Path.home() / '.claude/memory/michi-mem/diary')
content = {...}  # User-provided content
path = writer.create_entry(content)
print(f'Diary saved: {path}')
"
```

## Present Results

Show user the created diary path and current status.
```

## Data Flow

### Diary Creation Flow

```
User conversation (3+ turns)
         |
         | Stop hook triggered
         v
  auto-diary.sh (bash)
         |
         | Check turn count >= 3
         | Check auto_record enabled
         v
  diary_writer.py (Python)
         |
         | Prompt user for content
         | Format as markdown
         | Atomic write to diary/
         v
  diary/2026-01-28-session-N.md
         |
         v
  Update session state
  (mark as recorded)
```

### Reflection Flow

```
User runs /reflect
         |
         v
  pattern_analyzer.py
         |
         | Read unprocessed diary entries
         | Parse sections (preferences, decisions, etc.)
         | Count occurrences
         | Classify patterns (strong/moderate/emerging)
         v
  Generate reflection markdown
         |
         | Format analysis results
         | Propose CLAUDE.md updates
         | Atomic write to reflections/
         v
  reflections/2026-01-28.md
         |
         | Update processed.log
         v
  Present to user for review
```

### Cleanup Flow

```
Claude Code exits
         |
         | SessionEnd hook triggered
         v
  cleanup.sh (bash)
         |
         | Load retention config
         | Find diary/*.md files
         | Filter by age (mtime > N days)
         v
  Delete old diary entries
         |
         | (reflections/ untouched)
         v
  Log cleanup summary
```

## File Formats

### Diary Entry Format

**Filename**: `YYYY-MM-DD-session-N.md` (e.g., `2026-01-28-session-1.md`)

**Structure**:
```markdown
# Session Diary: 2026-01-28

**Project**: michi-mem
**Branch**: feature/add-export
**Session**: 1

## What Happened
Brief summary of the session's focus and outcomes.

## Work Done
- Implemented JSON export command
- Added unit tests for exporter module
- Updated documentation with export examples

## Decisions Made
- Use JSON instead of CSV for structured data export
- Include both diary and reflection data in single export

## Preferences Expressed
- Prefer verbose error messages over error codes
- Always write tests before implementation

## Challenges Encountered
- JSON serialization of Path objects required custom encoder
- Large exports (100+ entries) initially timed out

## Patterns Observed
- User consistently requests confirmation before destructive operations
- Prefers functional style over object-oriented for small utilities
```

**Sections** (all optional):
- **What Happened**: High-level summary
- **Work Done**: Bullet points of concrete tasks
- **Decisions Made**: Choices made during session
- **Preferences Expressed**: User's stated preferences
- **Challenges Encountered**: Problems faced
- **Patterns Observed**: Recurring behaviors noticed

**Why this structure?**
- Structured sections make parsing easy
- Flexibility (all sections optional)
- Human-readable (can review manually)
- Markdown for compatibility (can export/render)

### Reflection Format

**Filename**: `YYYY-MM-DD.md` (e.g., `2026-01-28.md`)

**Structure**:
```markdown
# Reflection: 2026-01-28

Analyzed 7 diary entries from past 14 days.

## Strong Patterns (3+ occurrences)

### Preference: Verbose error messages
- Observed in sessions: 2026-01-15, 2026-01-20, 2026-01-28
- Context: Always requests detailed error messages instead of codes

### Workflow: Test-first development
- Observed in sessions: 2026-01-15, 2026-01-22, 2026-01-28
- Context: Writes tests before implementing features

### Preference: Descriptive naming
- Observed in sessions: 2026-01-15, 2026-01-20, 2026-01-25
- Context: Prefers full variable names over abbreviations

## Moderate Patterns (2 occurrences)

### Preference: Functional style
- Observed in sessions: 2026-01-20, 2026-01-28
- Context: Uses functional programming for utilities

### Workflow: Confirmation before destructive ops
- Observed in sessions: 2026-01-22, 2026-01-28
- Context: Asks for confirmation before deleting/modifying

## Emerging Observations (1 occurrence)

- Uses Black formatter for all Python code (2026-01-28)
- Prefers composition over inheritance (2026-01-25)

## Proposed CLAUDE.md Updates

```markdown
## Coding Preferences

### Error Handling
- Use verbose error messages with context, not error codes
- Example: "Cannot write to ~/.claude/memory: Permission denied" over "Error 13"

### Development Workflow
- Write tests before implementation (TDD)
- Always run tests after changes

### Code Style
- Descriptive variable names (no abbreviations)
- Functional style for utilities
- Python: Format with Black

### Safety
- Request confirmation before destructive operations (delete, overwrite)
```
```

**Why this structure?**
- Grouped by pattern strength (prioritizes strong signals)
- Session references (traceable to source)
- Context included (why this matters)
- CLAUDE.md updates pre-formatted (easy to apply)

### Processed Log Format

**File**: `reflections/processed.log`

**Structure**:
```
2026-01-15-session-1.md
2026-01-15-session-2.md
2026-01-20-session-1.md
...
```

Simple newline-delimited list of processed diary filenames.

**Purpose**: Track which diary entries have been analyzed to avoid duplicate processing.

**Why plain text?** Simple, append-only, easy to parse.

### Configuration Format

**File**: `config.json`

**Structure**:
```json
{
  "diary_retention_days": 30,
  "reflection_retention": "permanent",
  "auto_reflect_threshold": 5,
  "auto_record": true,
  "auto_record_min_turns": 3
}
```

**Field definitions**:
- `diary_retention_days`: Number of days to keep diary entries (integer > 0)
- `reflection_retention`: Always "permanent" (reflections never deleted)
- `auto_reflect_threshold`: Unprocessed entry count before suggesting /reflect
- `auto_record`: Enable/disable auto-diary prompts (boolean)
- `auto_record_min_turns`: Minimum conversation turns before prompting (integer > 0)

**Validation** (config.py):
```python
def _validate(self, config: Dict[str, Any]):
    if config["diary_retention_days"] < 1:
        raise ValueError("diary_retention_days must be positive")

    if config["auto_record_min_turns"] < 1:
        raise ValueError("auto_record_min_turns must be positive")

    if config["auto_reflect_threshold"] < 1:
        raise ValueError("auto_reflect_threshold must be positive")
```

## Extension Points

### Adding New Analysis Types

To add new pattern detection logic:

1. **Extend diary format** (add new section):
   ```markdown
   ## Code Review Preferences
   - Focus on security implications
   - Check for proper error handling
   ```

2. **Update `diary_writer.py`** to include new section:
   ```python
   if content.get('code_review_prefs'):
       sections.append("## Code Review Preferences")
       for item in content['code_review_prefs']:
           sections.append(f"- {item}")
   ```

3. **Update `pattern_analyzer.py`** to parse new section:
   ```python
   def _parse_entry(self, entry_path: Path) -> Dict[str, Any]:
       # ...existing parsing...
       code_review_prefs = self._extract_section(text, "Code Review Preferences")
       return {
           'preferences': preferences,
           'code_review_prefs': code_review_prefs,  # New
           # ...
       }
   ```

4. **Add analysis logic**:
   ```python
   def analyze(self, entries: List[Path]) -> Dict[str, Any]:
       # Count code review preferences
       code_review_counts = Counter()
       for entry in entries:
           parsed = self._parse_entry(entry)
           code_review_counts.update(parsed.get('code_review_prefs', []))

       # Classify and return
   ```

### Adding New Commands

To add a new command (e.g., `/mem-export`):

1. **Create command skill** (`commands/mem-export.md`):
   ```markdown
   ---
   name: mem-export
   description: Export diary and reflection data to JSON
   ---

   Export all michi-mem data to structured JSON format.

   ## Implementation
   [Instructions for Claude Code to execute export]
   ```

2. **Register in plugin.json**:
   ```json
   {
     "commands": [
       ...existing commands...,
       {
         "name": "mem-export",
         "description": "Export data to JSON",
         "file": "commands/mem-export.md"
       }
     ]
   }
   ```

3. **Create Python module** if needed (`scripts/lib/exporter.py`):
   ```python
   class MemExporter:
       def export_to_json(self) -> str:
           # Load diary entries
           # Load reflections
           # Serialize to JSON
           # Return JSON string
   ```

4. **Write tests** (`tests/test_exporter.py`)

5. **Update documentation** (README, INSTALLATION)

### Adding New Hooks

To add a new lifecycle hook (e.g., pre-session initialization):

1. **Create hook script** (`scripts/hooks/init.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail

   # Initialize session-specific context
   echo "Session started" >> ~/.claude/memory/michi-mem/.state/sessions.log
   ```

2. **Register in hooks.json**:
   ```json
   {
     "SessionStart": {
       "script": "scripts/hooks/init.sh",
       "async": true
     }
   }
   ```

3. **Test hook behavior**:
   ```bash
   # Test manually
   bash scripts/hooks/init.sh

   # Verify log created
   cat ~/.claude/memory/michi-mem/.state/sessions.log
   ```

## Design Decisions

### Why Bash + Python Hybrid?

**Decision**: Use bash for hooks, Python for analysis.

**Alternatives considered**:
1. Pure bash (simple but hard to maintain)
2. Pure Python (powerful but slower startup)

**Rationale**:
- Hooks need fast startup (bash: instant, Python: ~100ms import overhead)
- Analysis needs maintainability (Python: clear, testable)
- Best of both: bash delegates to Python only when needed

**Trade-offs**:
- Added complexity (two languages)
- Easier testing (Python modules are unit-testable)
- Better performance (bash for hot path)

### Why Ephemeral Diaries?

**Decision**: Auto-delete diary entries after 30 days.

**Alternatives considered**:
1. Keep all diaries forever
2. User-initiated cleanup only

**Rationale**:
- Diaries grow unbounded (every session creates entry)
- Patterns already extracted to reflections
- Raw data rarely needed after pattern detection

**Trade-offs**:
- Cannot re-analyze old diaries
- Storage stays minimal
- Encourages regular reflection (process before deletion)

### Why Frequency-Based Pattern Detection?

**Decision**: Classify patterns by occurrence count (3+ = strong, 2 = moderate, 1 = emerging).

**Alternatives considered**:
1. Time-based (recent patterns prioritized)
2. ML-based clustering
3. Manual tagging

**Rationale**:
- Simple, explainable, deterministic
- Frequency is strong signal for preferences
- No ML dependencies (keeps plugin lightweight)

**Trade-offs**:
- Misses time-based trends (recent preference changes)
- No semantic grouping (similar patterns counted separately)
- Easy to implement and test

### Why Markdown for File Formats?

**Decision**: Use markdown for diary entries and reflections.

**Alternatives considered**:
1. JSON (structured)
2. Plain text (simple)
3. SQLite (queryable)

**Rationale**:
- Human-readable (users can inspect files)
- Structured enough (sections via headers)
- Portable (can render/export)
- Text-based (easy diffs in git)

**Trade-offs**:
- Parsing more complex than JSON
- Readable and flexible
- Compatible with documentation tools

### Why Atomic Writes?

**Decision**: Write to temp file, then rename (atomic operation).

**Alternatives considered**:
1. Direct writes (simpler)
2. File locking (more complex)

**Rationale**:
- Prevents partial writes on crash/interrupt
- POSIX guarantees atomic rename
- No corruption risk

**Implementation**:
```python
temp_path = filepath.with_suffix('.tmp')
temp_path.write_text(markdown)
temp_path.rename(filepath)  # Atomic
```

### Why Async Hooks?

**Decision**: All hooks run asynchronously.

**Alternatives considered**:
1. Synchronous hooks (block user)
2. Background processes (complex)

**Rationale**:
- Zero-overhead principle (never block user workflow)
- Claude Code supports async hooks natively
- Errors don't interrupt sessions

**Trade-offs**:
- Results not immediately available (usually fine)
- No interruption to user
- Better user experience

## Conclusion

michi-mem's architecture balances:
- **Performance** (bash for hot paths, async execution)
- **Maintainability** (Python for complex logic, clear interfaces)
- **Scalability** (ephemeral raw data, permanent insights)
- **User experience** (transparent, fail-silent, zero-overhead)

The 3-stage pipeline (diary → reflect → cleanup) provides lasting memory without unbounded storage growth, making it sustainable for long-term use.

For questions or suggestions, see [CONTRIBUTING.md](CONTRIBUTING.md).
