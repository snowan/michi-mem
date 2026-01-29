# Contributing Guide

Thank you for your interest in contributing to michi-mem! This guide will help you get started with bug reports, feature proposals, development setup, and pull requests.

## Table of Contents

- [Reporting Bugs](#reporting-bugs)
- [Proposing Features](#proposing-features)
- [Development Setup](#development-setup)
- [Running Tests](#running-tests)
- [Code Style](#code-style)
- [Pull Request Process](#pull-request-process)
- [Manual Testing Checklist](#manual-testing-checklist)

## Reporting Bugs

### Before Reporting

1. **Check existing issues**: Search [GitHub Issues](https://github.com/<username>/michi-mem/issues) to avoid duplicates
2. **Verify it's a bug**: Run `/mem-status` to check system health
3. **Check error logs**: Look at `~/.claude/memory/michi-mem/.state/errors.log`
4. **Try latest version**: Update to the latest release

### Bug Report Template

When opening an issue, include:

**Title**: Clear, specific description (e.g., "Auto-diary prompt not appearing after 5 turns")

**Environment**:
```
- OS: macOS 14.2 / Ubuntu 22.04 / etc.
- Claude Code version: 1.x.x
- michi-mem version: 1.0.0
- Python version: 3.11.2
```

**Steps to Reproduce**:
```
1. Start Claude Code
2. Have 5 conversation turns
3. Observe: no diary prompt appears
```

**Expected Behavior**:
```
After 3+ turns, should see prompt:
"Would you like to create a diary entry for this session?"
```

**Actual Behavior**:
```
No prompt appears
```

**Logs**:
```bash
# Output of /mem-status
[paste output here]

# Recent errors
[paste last 20 lines of errors.log]
```

**Additional Context**:
Any other relevant details (configuration, recent changes, etc.)

### Priority Labels

We use these labels for triage:
- `bug` - Something isn't working
- `critical` - Breaks core functionality
- `minor` - Small issue with workaround
- `enhancement` - Improvement to existing feature
- `documentation` - Docs need update

## Proposing Features

We welcome feature ideas! Before proposing:

1. **Check roadmap**: See README.md for planned features
2. **Search existing issues**: Someone may have already suggested it
3. **Consider scope**: Features should align with michi-mem's philosophy (automated memory lifecycle)

### Feature Request Template

**Title**: Clear feature description (e.g., "Add export to JSON feature")

**Problem**:
```
I want to analyze my diary entries in external tools,
but there's no easy way to export the data.
```

**Proposed Solution**:
```
Add `/mem-export` command that outputs all diary entries
and reflections in JSON format:

{
  "diary": [...],
  "reflections": [...]
}
```

**Alternatives Considered**:
```
- Manual file copying (too manual)
- CSV export (less structured)
```

**Additional Context**:
Example use cases, mockups, related tools, etc.

## Development Setup

### Prerequisites

- Python 3.7+
- Bash
- Git
- Make (for convenience commands)

### Clone and Install

```bash
# Fork the repository on GitHub first

# Clone your fork
git clone https://github.com/<your-username>/michi-mem
cd michi-mem

# Create development environment
make install-dev

# This symlinks to ~/.claude/plugins/repos/michi-mem-dev
# and sets up Python development dependencies
```

### Development Workflow

```bash
# Make changes to code
vim scripts/lib/diary_writer.py

# Run tests
make test

# Run specific test
python3 -m pytest tests/test_diary_writer.py -v

# Test in Claude Code
# 1. Restart Claude Code to pick up changes
# 2. Test commands: /diary, /reflect, /mem-status

# Run linters
make lint

# Format code
make format
```

### Directory Structure

```
michi-mem/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── commands/                 # Skill definitions (markdown)
│   ├── diary.md
│   ├── reflect.md
│   └── mem-status.md
├── scripts/
│   ├── hooks/               # Hook scripts (bash)
│   │   ├── auto-diary.sh
│   │   ├── cleanup.sh
│   │   └── hooks.json
│   └── lib/                 # Analysis modules (Python)
│       ├── __init__.py
│       ├── config.py
│       ├── diary_writer.py
│       └── pattern_analyzer.py
├── tests/
│   ├── __init__.py
│   ├── test_config.py
│   ├── test_diary_writer.py
│   ├── test_pattern_analyzer.py
│   ├── integration/
│   │   └── test_workflow.sh
│   └── fixtures/            # Sample diary entries
├── docs/
│   ├── INSTALLATION.md
│   ├── CONTRIBUTING.md      # This file
│   └── ARCHITECTURE.md
├── examples/                # Sample outputs
├── Makefile                 # Development commands
├── README.md
└── LICENSE
```

## Running Tests

### Unit Tests (Python)

```bash
# Run all Python tests
make test-unit

# Or directly with pytest
python3 -m pytest tests/ -v

# Run specific test file
python3 -m pytest tests/test_config.py -v

# Run specific test
python3 -m pytest tests/test_config.py::TestMemConfig::test_default_config -v

# With coverage
python3 -m pytest tests/ --cov=scripts.lib --cov-report=html
open htmlcov/index.html
```

### Integration Tests (Bash)

```bash
# Run full integration test suite
make test-integration

# Or directly
bash tests/integration/test_workflow.sh

# This tests:
# - Diary creation
# - Pattern analysis
# - Cleanup script
# - End-to-end workflow
```

### All Tests

```bash
# Run everything
make test
```

### Test Guidelines

When writing tests:

1. **Use descriptive names**: `test_config_creates_defaults_if_missing`
2. **One assertion per test**: Focus on single behavior
3. **Use fixtures**: Share test data via `tests/fixtures/`
4. **Clean up**: Tests should not leave artifacts
5. **Mock external deps**: Don't rely on actual git repos, file systems (use tempfiles)

Example test:

```python
def test_diary_writer_creates_sequential_sessions(tmp_path):
    """Diary writer increments session number for same-day entries."""
    writer = DiaryWriter(tmp_path)

    # Create first entry
    content1 = {"summary": "First session"}
    path1 = writer.create_entry(content1)
    assert "session-1.md" in path1.name

    # Create second entry (same day)
    content2 = {"summary": "Second session"}
    path2 = writer.create_entry(content2)
    assert "session-2.md" in path2.name
```

## Code Style

### Python

**Formatter**: [Black](https://github.com/psf/black) (line length 88)

```bash
# Format all Python files
make format

# Or directly
black scripts/lib/ tests/

# Check without modifying
black --check scripts/lib/ tests/
```

**Linter**: [Flake8](https://flake8.pycqa.org/)

```bash
# Lint Python files
make lint-python

# Or directly
flake8 scripts/lib/ tests/
```

**Style Guidelines**:
- Use type hints for function signatures
- Docstrings for public functions (Google style)
- Descriptive variable names (no abbreviations)
- Prefer composition over inheritance
- Keep functions under 50 lines

**Example**:

```python
def create_entry(self, content: Dict[str, Any]) -> Path:
    """
    Create diary entry with session context.

    Args:
        content: Dict with keys: summary, work_done, decisions,
                preferences, challenges, patterns

    Returns:
        Path to created diary file

    Raises:
        IOError: If unable to write diary file
        ValueError: If content missing required fields
    """
    # Implementation here
```

### Bash

**Linter**: [ShellCheck](https://www.shellcheck.net/)

```bash
# Lint all bash scripts
make lint-bash

# Or directly
shellcheck scripts/hooks/*.sh tests/integration/*.sh
```

**Style Guidelines**:
- Use `set -euo pipefail` at script start
- Quote variables: `"$VAR"` not `$VAR`
- Use `[[` for conditionals, not `[`
- Descriptive function names: `create_diary_entry`, not `cde`
- Comments for non-obvious logic

**Example**:

```bash
#!/bin/bash
set -euo pipefail

# Creates diary entry for current session
create_diary_entry() {
    local diary_dir="$1"
    local session_num="$2"

    if [[ ! -d "$diary_dir" ]]; then
        mkdir -p "$diary_dir"
    fi

    # Implementation here
}
```

### Markdown

**Linter**: [markdownlint](https://github.com/DavidAnson/markdownlint)

**Style Guidelines**:
- One sentence per line (makes diffs cleaner)
- ATX headers (`#` not underlines)
- Fenced code blocks with language tags
- Lists with `-` (not `*`)

## Pull Request Process

### Before Creating PR

1. **Create feature branch**:
   ```bash
   git checkout -b feature/add-json-export
   ```

2. **Make changes**:
   - Write tests first (TDD)
   - Implement feature
   - Update documentation

3. **Run full test suite**:
   ```bash
   make test
   make lint
   ```

4. **Update CHANGELOG.md**:
   ```markdown
   ## [Unreleased]
   ### Added
   - JSON export feature via `/mem-export` command
   ```

5. **Commit with clear message**:
   ```bash
   git commit -m "feat: add JSON export command

   - Implements /mem-export for diary and reflection data
   - Adds tests for export functionality
   - Updates documentation with export examples"
   ```

### Creating PR

1. **Push to your fork**:
   ```bash
   git push origin feature/add-json-export
   ```

2. **Open PR on GitHub**

3. **Fill out PR template**:

   **Title**: Clear, concise (e.g., "Add JSON export command")

   **Description**:
   ```markdown
   ## Summary
   - Adds `/mem-export` command for exporting diary and reflection data
   - Outputs structured JSON for external analysis tools
   - Includes comprehensive tests and documentation

   ## Changes
   - `commands/mem-export.md`: New command definition
   - `scripts/lib/exporter.py`: Export logic
   - `tests/test_exporter.py`: Unit tests
   - `docs/INSTALLATION.md`: Export command docs

   ## Testing
   - [x] Unit tests pass
   - [x] Integration tests pass
   - [x] Manual testing completed (see checklist below)
   - [x] Documentation updated

   ## Manual Testing Checklist
   - [x] Export with 0 diary entries (empty JSON)
   - [x] Export with diary entries only
   - [x] Export with reflections only
   - [x] Export with both diary and reflections
   - [x] JSON validates against schema
   - [x] Large exports (100+ entries) complete without errors
   ```

4. **Link related issues**: "Closes #42"

### PR Review Process

1. **Automated checks run**:
   - Unit tests
   - Integration tests
   - Linters (Black, Flake8, ShellCheck)

2. **Maintainer review**:
   - Code quality
   - Test coverage
   - Documentation completeness

3. **Address feedback**:
   ```bash
   # Make requested changes
   git add .
   git commit -m "refactor: simplify export logic per review"
   git push origin feature/add-json-export
   ```

4. **Merge**:
   - Maintainer will merge once approved
   - PR closed, branch can be deleted

### Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring (no behavior change)
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples**:
```
feat(export): add JSON export command

fix(diary): prevent duplicate session numbers
Fixed race condition when creating multiple entries simultaneously.
Closes #123

docs(readme): add troubleshooting section for permission errors

test(config): add validation tests for edge cases
```

## Manual Testing Checklist

Before submitting PR, manually verify:

### Installation
- [ ] Install plugin from scratch in test environment
- [ ] Restart Claude Code
- [ ] Verify commands recognized via `/mem-status`

### Diary Creation
- [ ] `/diary` creates entry successfully
- [ ] Auto-diary prompts after 3+ turns
- [ ] Session numbers increment correctly (same day)
- [ ] Diary entries have correct structure (headers, sections)
- [ ] Git context included if in repository

### Reflection
- [ ] `/reflect` with 0 unprocessed entries shows appropriate message
- [ ] `/reflect` with 5+ entries analyzes correctly
- [ ] Strong patterns (3+ occurrences) detected
- [ ] Moderate patterns (2 occurrences) detected
- [ ] Emerging observations (1 occurrence) listed
- [ ] Processed.log updated after reflection

### Status Command
- [ ] `/mem-status` shows correct diary count
- [ ] `/mem-status` shows correct reflection count
- [ ] `/mem-status` displays storage sizes
- [ ] `/mem-status` shows config values
- [ ] Tip shown when 5+ unprocessed entries exist

### Cleanup
- [ ] Old diary entries (30+ days) deleted on session end
- [ ] Recent diary entries preserved
- [ ] Reflections never deleted
- [ ] Cleanup logged appropriately

### Error Handling
- [ ] Invalid config.json handled gracefully
- [ ] Permission errors show clear messages
- [ ] Missing directories created automatically
- [ ] Hook errors logged to `.state/errors.log`
- [ ] Errors don't interrupt user workflow

### CLAUDE.md Updates
- [ ] Reflection proposes CLAUDE.md updates
- [ ] Updates are relevant and actionable
- [ ] User can review before applying

### Cross-Platform (if applicable)
- [ ] Works on macOS
- [ ] Works on Linux
- [ ] Windows compatibility (if supported)

## Questions?

If you have questions about contributing:

1. **Check existing docs**: README, INSTALLATION, ARCHITECTURE
2. **Search issues**: Someone may have asked already
3. **Open discussion**: GitHub Discussions for general questions
4. **Ask in PR**: Comment on your PR if you need guidance

Thank you for contributing to michi-mem!
