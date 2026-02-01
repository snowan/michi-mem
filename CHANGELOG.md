# Changelog

All notable changes to michi-mem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-28

Initial release of michi-mem - automated memory lifecycle for Claude Code.

### Added

#### Core Features
- **Diary system** for recording session context automatically
  - Auto-diary prompts after 3+ conversation turns
  - Manual diary creation via `/diary` command
  - Structured markdown format with sections for work done, decisions, preferences, challenges, and patterns
  - Git context integration (project, branch) when available
  - Sequential session numbering for same-day entries

- **Reflection system** for pattern analysis
  - `/reflect` command analyzes unprocessed diary entries
  - Frequency-based pattern detection (strong: 3+ occurrences, moderate: 2, emerging: 1)
  - Generates structured reflection documents with pattern classification
  - Proposes CLAUDE.md updates based on identified patterns
  - Tracks processed entries to avoid duplicate analysis

- **Status command** for system monitoring
  - `/mem-status` displays comprehensive statistics
  - Shows diary entry counts (total, recent, unprocessed)
  - Displays reflection counts and dates
  - Reports storage usage
  - Shows current configuration
  - Provides tips when 5+ unprocessed entries exist

- **Automated cleanup** system
  - Auto-deletes diary entries older than configured retention period (default: 30 days)
  - Preserves reflections permanently
  - Runs automatically on Claude Code exit (SessionEnd hook)
  - Maintains minimal storage footprint while keeping insights

#### Technical Implementation
- **Python analysis modules** (testable, maintainable)
  - `config.py`: Configuration management with validation and defaults
  - `diary_writer.py`: Diary entry creation with atomic writes
  - `pattern_analyzer.py`: Pattern detection and frequency analysis

- **Bash hook scripts** (fast, zero-overhead)
  - `auto-diary.sh`: Triggers diary prompts after sessions
  - `cleanup.sh`: Manages diary entry retention
  - Async execution (never blocks user workflow)
  - Error logging to `.state/errors.log`

- **Command skills** (markdown-based)
  - `/diary`: Create diary entry from current session
  - `/reflect`: Analyze patterns from diary entries
  - `/mem-status`: Show system statistics

#### Documentation
- **README.md**: Comprehensive overview with quick start, how it works, commands reference, and troubleshooting
- **docs/INSTALLATION.md**: Detailed installation guide with prerequisites, verification steps, and troubleshooting
- **docs/CONTRIBUTING.md**: Community guidelines with bug reporting, feature proposals, development setup, and PR process
- **docs/ARCHITECTURE.md**: Technical deep dive with design philosophy, system components, data flow, and extension points

#### Testing
- **Unit tests** for all Python modules
  - `test_config.py`: Configuration validation and defaults
  - `test_diary_writer.py`: Diary creation and formatting
  - `test_pattern_analyzer.py`: Pattern detection and classification
  - Test coverage: ~90%

- **Integration tests**
  - `test_workflow.sh`: End-to-end testing of diary creation, reflection, and cleanup
  - Test fixtures with sample diary entries
  - Automated test suite via `make test`

#### Developer Tools
- **Makefile** with common tasks
  - `make install`: Install plugin locally
  - `make test`: Run all tests (unit + integration)
  - `make lint`: Run code linters (Black, Flake8, ShellCheck)
  - `make format`: Auto-format Python code with Black
  - `make verify`: Verify plugin installation

#### Examples
- Sample diary entry in `examples/`
- Sample reflection in `examples/`
- Example CLAUDE.md updates in `examples/`

#### Licensing
- MIT License for open-source distribution

### Fixed
- Command recognition issues after plugin installation (now requires Claude Code restart, clearly documented)
- Race conditions in diary session numbering (atomic writes prevent conflicts)
- Hook errors silently failing without user feedback (now logged to `.state/errors.log`)

### Testing Summary

**Unit Tests**: 16 tests passing
- Configuration: 5 tests (validation, defaults, edge cases)
- Diary Writer: 5 tests (creation, formatting, session numbering)
- Pattern Analyzer: 6 tests (unprocessed entries, pattern classification, processed log)

**Integration Tests**: 11 assertions passing
- Config module creation and validation
- Diary creation workflow with session numbering
- Pattern analysis with known patterns (strong/moderate/emerging)
- Cleanup with retention policy and state file management
- End-to-end multi-session workflow
- Error handling and recovery

**Manual Testing**: Completed
- Installation from scratch
- Command recognition after restart
- Auto-diary prompts after 3+ turns
- Reflection with 5+ entries
- CLAUDE.md update proposals
- Cleanup on session end
- Error handling (permissions, invalid config)

**Code Quality**:
- Python: Black formatted, Flake8 compliant
- Bash: ShellCheck compliant
- Documentation: Complete and reviewed

### Known Limitations

- No custom diary templates (planned for future release)
- No export features (JSON, CSV) yet
- Pattern detection is frequency-based only (no semantic analysis)
- Single-user only (no multi-user support)
- No GUI or web interface
- Not yet published to plugin marketplace

These limitations are intentional for v1.0 (minimal viable release). Features will be added based on community feedback.

## [Unreleased]

### Planned Features
- Custom diary templates
- Export to JSON/CSV
- Advanced pattern detection (ML-based)
- Plugin marketplace submission
- Multi-user support
- Web interface for browsing history

See [README.md roadmap](README.md#roadmap) for details.

---

**Note**: This changelog follows the [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format with sections:
- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security vulnerability fixes
