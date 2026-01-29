# Open-Source michi-mem Plugin Design

**Date**: 2026-01-28
**Goal**: Share michi-mem with Claude Code community, focusing on stability and documentation
**Scope**: Minimal viable release - polish existing features, add tests and comprehensive docs

## Overview

Transform the current michi-mem plugin into a community-ready open-source project with:
- Fixed command recognition issues
- Robust error handling
- Comprehensive testing
- Clear documentation
- Maintainable codebase

## Project Structure

```
michi-mem/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── commands/                 # Skill definitions
│   ├── diary.md
│   ├── reflect.md
│   └── mem-status.md
├── scripts/
│   ├── hooks/               # Lightweight bash hooks
│   │   ├── auto-diary.sh
│   │   ├── cleanup.sh
│   │   └── hooks.json
│   └── lib/                 # Python analysis scripts
│       ├── diary_writer.py
│       ├── pattern_analyzer.py
│       └── config.py
├── tests/
│   ├── integration/
│   │   └── test_workflow.sh
│   └── fixtures/            # Mock diary entries for testing
├── examples/                # Sample outputs
├── docs/
│   ├── INSTALLATION.md
│   ├── CONTRIBUTING.md
│   └── ARCHITECTURE.md
├── README.md
├── LICENSE (MIT)
└── Makefile                 # Common tasks (install, test, uninstall)
```

## Key Architectural Decisions

### 1. Hybrid Bash + Python Approach

**Hooks remain lightweight bash:**
- `auto-diary.sh` - Fast startup, minimal overhead for Stop hook
- `cleanup.sh` - Simple file operations for SessionEnd hook
- No complex logic, just shell out to Python when needed

**Analysis logic moves to Python:**
- `config.py` - Configuration management with validation
- `diary_writer.py` - Diary entry creation
- `pattern_analyzer.py` - Reflection and pattern detection

**Benefits:**
- Fast, minimal overhead for hooks
- Testable, maintainable code for complex analysis
- Easy to extend features
- Proper error handling with meaningful messages

### 2. Command Recognition Fix

**Current issue:** `/diary`, `/reflect`, `/mem-status` not recognized after installation

**Root causes:**
- Plugin registration timing (commands don't load if installed while Claude Code running)
- Marketplace vs local installation differences

**Solution:**
- Clear installation instructions requiring Claude Code restart
- Verify `plugin.json` format matches expectations
- Add validation script to check command registration
- Document expected behavior and troubleshooting

**Installation flow:**
```bash
# Clone to local repos
cd ~/.claude/plugins/repos/
git clone <repo-url> michi-mem

# Enable in settings.json
# "michi-mem@local": true

# Restart Claude Code (required)

# Verify
/mem-status
```

**Development workflow:**
- Symlink from marketplace to local repo
- `make install` handles setup
- `make verify` checks registration

## Python Module Design

### config.py - Configuration Management

```python
import json
from pathlib import Path
from typing import Dict, Any

class MemConfig:
    """Manages michi-mem configuration with validation."""

    def __init__(self, config_path: Path = None):
        self.path = config_path or Path.home() / ".claude/memory/michi-mem/config.json"
        self._config = self._load()

    def _load(self) -> Dict[str, Any]:
        """Load config with defaults, validate types."""
        defaults = {
            "diary_retention_days": 30,
            "reflection_retention": "permanent",
            "auto_reflect_threshold": 5,
            "auto_record": True,
            "auto_record_min_turns": 3
        }

        if not self.path.exists():
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self._save(defaults)
            return defaults

        try:
            with open(self.path) as f:
                user_config = json.load(f)

            # Merge with defaults
            config = {**defaults, **user_config}

            # Validate
            self._validate(config)

            return config
        except Exception as e:
            raise ConfigError(f"Invalid config: {e}")

    def _validate(self, config: Dict[str, Any]):
        """Validate configuration values."""
        if config["diary_retention_days"] < 1:
            raise ValueError("diary_retention_days must be positive")

        if config["auto_record_min_turns"] < 1:
            raise ValueError("auto_record_min_turns must be positive")

        if config["auto_reflect_threshold"] < 1:
            raise ValueError("auto_reflect_threshold must be positive")

    def get(self, key: str, default=None):
        """Get configuration value."""
        return self._config.get(key, default)
```

### diary_writer.py - Diary Creation

```python
from pathlib import Path
from datetime import datetime
from typing import Dict, Any

class DiaryWriter:
    """Handles diary entry creation."""

    def __init__(self, diary_dir: Path):
        self.diary_dir = diary_dir
        self.diary_dir.mkdir(parents=True, exist_ok=True)

    def create_entry(self, content: Dict[str, Any]) -> Path:
        """
        Create diary entry with session context.

        Args:
            content: Dict with keys: summary, work_done, decisions,
                    preferences, challenges, patterns

        Returns:
            Path to created diary file
        """
        today = datetime.now().strftime("%Y-%m-%d")
        session_num = self._get_next_session_number(today)

        filename = f"{today}-session-{session_num}.md"
        filepath = self.diary_dir / filename

        # Generate markdown
        markdown = self._format_entry(content, today, session_num)

        # Atomic write
        temp_path = filepath.with_suffix('.tmp')
        temp_path.write_text(markdown)
        temp_path.rename(filepath)

        return filepath

    def _get_next_session_number(self, date: str) -> int:
        """Count existing sessions for today."""
        pattern = f"{date}-session-*.md"
        existing = list(self.diary_dir.glob(pattern))
        return len(existing) + 1

    def _format_entry(self, content: Dict[str, Any], date: str, session: int) -> str:
        """Format diary entry as markdown."""
        sections = [
            f"# Session Diary: {date}",
            f"\n**Project**: {content.get('project', 'Unknown')}",
            f"**Branch**: {content.get('branch', 'Unknown')}",
            f"**Session**: {session}\n"
        ]

        if content.get('summary'):
            sections.append(f"## What Happened\n{content['summary']}\n")

        if content.get('work_done'):
            sections.append("## Work Done")
            for item in content['work_done']:
                sections.append(f"- {item}")
            sections.append("")

        # Add other sections if present...

        return "\n".join(sections)
```

### pattern_analyzer.py - Reflection Logic

```python
from pathlib import Path
from typing import List, Dict, Tuple
from collections import Counter

class PatternAnalyzer:
    """Analyzes diary entries to detect patterns."""

    def __init__(self, diary_dir: Path, reflections_dir: Path):
        self.diary_dir = diary_dir
        self.reflections_dir = reflections_dir
        self.processed_log = reflections_dir / "processed.log"

    def get_unprocessed_entries(self) -> List[Path]:
        """Find diary entries not yet reflected on."""
        all_entries = set(f.name for f in self.diary_dir.glob("*.md"))

        if self.processed_log.exists():
            processed = set(self.processed_log.read_text().splitlines())
        else:
            processed = set()

        unprocessed_names = all_entries - processed
        return [self.diary_dir / name for name in sorted(unprocessed_names)]

    def analyze(self, entries: List[Path]) -> Dict[str, Any]:
        """
        Analyze entries for patterns.

        Returns dict with:
            - strong_patterns: List of patterns with 3+ occurrences
            - moderate_patterns: List with 2 occurrences
            - emerging_observations: List with 1 occurrence
        """
        # Parse all entries
        preferences = []
        decisions = []
        challenges = []

        for entry_path in entries:
            entry = self._parse_entry(entry_path)
            preferences.extend(entry.get('preferences', []))
            decisions.extend(entry.get('decisions', []))
            challenges.extend(entry.get('challenges', []))

        # Count occurrences
        pref_counts = Counter(preferences)
        decision_counts = Counter(decisions)

        # Classify by strength
        strong = [p for p, count in pref_counts.items() if count >= 3]
        moderate = [p for p, count in pref_counts.items() if count == 2]
        emerging = [p for p, count in pref_counts.items() if count == 1]

        return {
            'strong_patterns': strong,
            'moderate_patterns': moderate,
            'emerging_observations': emerging,
            'entry_count': len(entries)
        }

    def mark_processed(self, entries: List[Path]):
        """Add entries to processed log."""
        with open(self.processed_log, 'a') as f:
            for entry in entries:
                f.write(f"{entry.name}\n")
```

## Error Handling Strategy

### Configuration Validation
- Check config.json exists, create with defaults if missing
- Validate types and ranges (positive integers, reasonable thresholds)
- Clear error messages for corrupted configs

### Dependency Checks
- Verify Python 3.7+ available
- Check write permissions on memory directory
- Graceful degradation if git unavailable

### Hook Failure Handling
- Hooks fail silently (never interrupt user workflow)
- Log errors to `~/.claude/memory/michi-mem/.state/errors.log`
- Error log auto-rotates (keep last 100 lines)
- `/mem-status` displays recent errors

### Command Safety
- Validate paths before file operations
- Atomic writes (write to temp, then rename)
- Handle missing directories gracefully
- File locking for concurrent access to processed.log

### User-Friendly Messages

```
❌ Error: Cannot write to ~/.claude/memory/michi-mem/
   Check directory permissions and try again.

✅ Diary saved: ~/.claude/memory/michi-mem/diary/2026-01-28-session-1.md
   Session recorded. (2 unprocessed entries total)

⚠️  Warning: 3 recent hook errors. Run /mem-status for details.
```

## Testing Strategy

### Integration Tests

**`tests/integration/test_workflow.sh`**
```bash
#!/bin/bash
set -euo pipefail

setup_test_env() {
  export TEST_HOME="/tmp/michi-mem-test-$$"
  export HOME="$TEST_HOME"
  mkdir -p "$TEST_HOME/.claude/memory/michi-mem"
  # Install plugin in test environment
}

test_diary_creation() {
  # Create diary entry
  # Verify file exists with correct structure
  # Check session marked as recorded
}

test_auto_reflection() {
  # Create 5 diary entries with known patterns
  # Trigger reflection
  # Verify patterns detected correctly
  # Check processed.log updated
}

test_cleanup() {
  # Create old diary entries (31+ days)
  # Run cleanup script
  # Verify old entries deleted, recent kept
}

cleanup_test_env() {
  rm -rf "$TEST_HOME"
}

# Run all tests
setup_test_env
test_diary_creation
test_auto_reflection
test_cleanup
cleanup_test_env

echo "All tests passed!"
```

### Test Fixtures
- Sample diary entries with known patterns
- Mock config files with various settings
- Expected reflection outputs for comparison

### CI/CD (GitHub Actions)
```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    steps:
      - uses: actions/checkout@v3
      - name: Run integration tests
        run: make test
```

### Manual Testing Checklist (CONTRIBUTING.md)
- [ ] Install plugin from scratch
- [ ] Restart Claude Code
- [ ] Verify commands recognized (/mem-status)
- [ ] Create diary entry manually
- [ ] Verify auto-diary prompts after 3+ turns
- [ ] Test reflection with 5+ entries
- [ ] Verify CLAUDE.md updates

## Documentation Plan

### README.md
Comprehensive but scannable:
- Quick start (3-step install)
- How it works (visual diagram)
- Commands reference table
- Configuration options
- Troubleshooting section
- Links to detailed docs

### INSTALLATION.md
Step-by-step guide:
- Prerequisites
- Installation methods (marketplace vs manual)
- Verification steps
- Uninstall instructions
- Troubleshooting command recognition

### CONTRIBUTING.md
Community guidelines:
- How to report bugs (issue template)
- How to propose features
- Development setup (`make install-dev`)
- Running tests (`make test`)
- Code style (Black for Python, shellcheck for bash)
- PR process

### ARCHITECTURE.md
Technical deep dive:
- System design overview
- Hook lifecycle diagram
- File formats and schemas
- Extension points for contributors
- Design decisions and trade-offs

## Minimal Viable Release Scope

### Included in v1.0.0
- ✅ Fixed command recognition
- ✅ Python refactoring (config, diary, reflect)
- ✅ Error handling & logging
- ✅ Integration tests
- ✅ Complete documentation
- ✅ MIT license
- ✅ Examples directory with sample outputs
- ✅ Makefile with install/test/uninstall

### Explicitly NOT in v1.0
Features to add based on community feedback:
- Custom diary templates
- Export features (JSON, CSV)
- Advanced pattern detection (ML-based)
- Multi-user support
- GUI/web interface
- Plugin marketplace submission

## Release Checklist

- [ ] All tests passing
- [ ] Documentation complete and reviewed
- [ ] Example outputs included
- [ ] CHANGELOG.md created
- [ ] LICENSE file added (MIT)
- [ ] README badges (tests, license)
- [ ] Tagged v1.0.0
- [ ] GitHub release created
- [ ] Announcement post drafted

## Implementation Plan

This design will be implemented using:
1. `superpowers:writing-plans` - Create detailed implementation plan
2. `superpowers:using-git-worktrees` - Isolated development workspace
3. `superpowers:test-driven-development` - Write tests first
4. `superpowers:requesting-code-review` - Review before release

The implementation will proceed in phases:
1. Project setup (structure, Python modules)
2. Core refactoring (config, diary, reflect)
3. Testing infrastructure
4. Documentation
5. Polish and release prep
