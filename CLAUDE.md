# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**michi-mem** is a Claude Code plugin providing automated memory lifecycle management through a 3-stage pipeline:

1. **Diary** - Ephemeral session records (30-day retention)
2. **Reflect** - Permanent pattern analysis from diaries
3. **Cleanup** - Automatic removal of old raw data

The system is designed for zero-overhead operation using async hooks and fail-silent error handling.

## Development Commands

### Testing

```bash
# Run all tests (unit + integration)
make test

# Run unit tests only (Python)
python3 -m pytest tests/ -v

# Run specific test
python3 -m pytest tests/test_config.py::TestMemConfig::test_default_config -v

# Run integration tests (bash)
bash tests/integration/test_workflow.sh

# Run with coverage
python3 -m pytest tests/ --cov=scripts.lib --cov-report=html
```

### Code Quality

```bash
# Run linters (shellcheck for bash, flake8 for Python)
make lint

# Format Python code (Black formatter)
make format
```

### Installation

```bash
# Install plugin to ~/.claude/plugins/repos/
make install

# Install in development mode (symlink - changes reflected immediately)
make install-dev

# Uninstall
make uninstall

# Verify installation
make verify
```

### Cleanup

```bash
# Remove Python cache files
make clean
```

## Architecture

### Component Organization

**Bash layer** (scripts/hooks/):
- Fast startup, minimal overhead
- Simple validation logic (turn count, config checks)
- Delegates complex operations to Python
- All hooks run asynchronously (never block user)

**Python layer** (scripts/lib/):
- Complex analysis and formatting
- Type-safe configuration management
- Pattern detection and classification
- Atomic file writes (temp file → rename)

**Skills layer** (commands/):
- Markdown-based command definitions
- User-facing commands: /diary, /reflect, /mem-status
- Executed by Claude Code skill system

### Key Modules

**scripts/lib/config.py**
- Singleton configuration manager
- Auto-creates config with defaults if missing
- Validates types and ranges (positive integers, etc.)
- Location: `~/.claude/memory/michi-mem/config.json`

**scripts/lib/diary_writer.py**
- Generates unique filenames (date-session-N.md)
- Formats structured markdown entries
- Atomic writes to prevent corruption
- Extracts git context when available

**scripts/lib/pattern_analyzer.py**
- Tracks processed vs unprocessed entries
- Counts pattern occurrences (collections.Counter)
- Classifies patterns by frequency:
  - Strong: 3+ occurrences
  - Moderate: 2 occurrences
  - Emerging: 1 occurrence
- Updates processed.log after analysis

### Hook System

**PreCompact hook**:
- Triggers before context compaction
- Prompts Claude to create diary entry
- Preserves session knowledge before compaction

**Stop hook** (scripts/hooks/auto-diary.sh):
- Triggers after conversation pauses/ends
- Checks turn count >= 3
- Prompts for diary entry creation if auto_record enabled

**SessionEnd hook** (scripts/hooks/cleanup.sh):
- Triggers when Claude Code exits
- Removes diary entries older than retention period
- Never touches reflections (permanent storage)

### File Locations

All data stored under `~/.claude/memory/michi-mem/`:

```
~/.claude/memory/michi-mem/
├── config.json                    # Configuration
├── diary/                         # Ephemeral (30 days default)
│   └── YYYY-MM-DD-session-N.md
├── reflections/                   # Permanent
│   ├── YYYY-MM-DD.md
│   └── processed.log              # Tracks analyzed diaries
└── .state/
    └── errors.log                 # Hook error log
```

## Testing Guidelines

### Test Structure

- **Unit tests**: `tests/test_*.py` (Python modules)
- **Integration tests**: `tests/integration/*.sh` (full workflow)
- **Fixtures**: `tests/fixtures/*.md` (sample diary entries)

### Writing Tests

1. Use descriptive names: `test_config_creates_defaults_if_missing`
2. One assertion per test (focus on single behavior)
3. Use tmp_path fixture for file operations
4. Clean up after tests (no artifacts)
5. Mock external dependencies (git repos, etc.)

### Example Pattern

```python
def test_diary_writer_creates_sequential_sessions(tmp_path):
    """Diary writer increments session number for same-day entries."""
    writer = DiaryWriter(tmp_path)

    content1 = {"summary": "First session"}
    path1 = writer.create_entry(content1)
    assert "session-1.md" in path1.name

    content2 = {"summary": "Second session"}
    path2 = writer.create_entry(content2)
    assert "session-2.md" in path2.name
```

## Code Style

### Python

- Formatter: Black (line length 88)
- Linter: Flake8
- Type hints required for function signatures
- Docstrings for public functions (Google style)
- Keep functions under 50 lines

### Bash

- Always use `set -euo pipefail`
- Quote variables: `"$VAR"` not `$VAR`
- Use `[[` for conditionals
- Run shellcheck before committing

## Plugin Development Notes

### Adding New Commands

1. Create skill file in `commands/<name>.md`
2. Register in `.claude-plugin/plugin.json` commands array
3. Create Python module in `scripts/lib/` if needed
4. Add tests
5. Update README and INSTALLATION docs

### Adding New Hooks

1. Create hook script in `scripts/hooks/<name>.sh`
2. Register in `scripts/hooks/hooks.json`
3. Set appropriate timeout and async flag
4. Test manually before committing

### Atomic Write Pattern

Always use for file creation to prevent corruption:

```python
temp_path = filepath.with_suffix('.tmp')
temp_path.write_text(content)
temp_path.rename(filepath)  # Atomic on POSIX
```

### Error Handling

- Hooks must fail silently (log errors, don't interrupt)
- Error logs go to `~/.claude/memory/michi-mem/.state/errors.log`
- User-facing errors should be clear and actionable
- Include suggested fixes in error messages

## Design Principles

1. **Zero-overhead**: Hooks never block user workflow (async)
2. **Fail-silent**: Errors logged but don't break sessions
3. **Transparent**: Users always know what data exists
4. **Scalable**: Only insights accumulate (raw data expires)
5. **Testable**: Clear interfaces, comprehensive tests

## Common Development Tasks

### Testing Hook Behavior

```bash
# Test auto-diary hook manually
CLAUDE_SESSION_ID="test" CLAUDE_TURN_COUNT=5 \
  bash scripts/hooks/auto-diary.sh

# Test cleanup hook
bash scripts/hooks/cleanup.sh

# Check error log
cat ~/.claude/memory/michi-mem/.state/errors.log
```

### Testing in Claude Code

1. Make code changes
2. If using `make install-dev`, changes are live (restart Claude Code)
3. If using `make install`, run install again
4. Test commands: `/diary`, `/reflect`, `/mem-status`

### Debugging

- Check `~/.claude/memory/michi-mem/.state/errors.log` for hook errors
- Run `/mem-status` to verify plugin health
- Check `~/.claude/logs/` for Claude Code logs
- Test Python modules directly: `python3 -c "from scripts.lib.config import MemConfig; print(MemConfig().config)"`
