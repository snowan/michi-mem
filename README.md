# michi-mem

**Automated memory lifecycle for Claude Code** - diary, reflect, and cleanup without manual intervention.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://img.shields.io/badge/tests-passing-brightgreen.svg)]()

## What is michi-mem?

michi-mem helps Claude Code remember what matters from your conversations through an automated 3-stage pipeline:

1. **📝 Diary** - Records session details automatically after each conversation
2. **🔍 Reflect** - Analyzes diary entries to identify patterns and preferences
3. **♻️ Cleanup** - Manages storage by removing old raw data while keeping insights

The system keeps ephemeral raw data (diaries) and permanent processed insights (reflections), ensuring Claude Code builds lasting context without accumulating clutter.

## Quick Start

### Installation

```bash
# 1. Clone to local plugins directory
cd ~/.claude/plugins/repos/
git clone https://github.com/<username>/michi-mem

# 2. Enable in Claude Code settings
# Add to ~/.claude/settings.json:
{
  "plugins": {
    "michi-mem@local": true
  }
}

# 3. Restart Claude Code (required for command registration)
```

### Verify Installation

```bash
/mem-status
```

You should see statistics about diary entries and reflections.

## How It Works

michi-mem uses a **3-stage pipeline** to build lasting memory:

```
┌─────────────┐
│   Session   │
│   Context   │
└──────┬──────┘
       │ Auto-diary hook
       ▼
┌─────────────┐
│   Diary     │  ← Ephemeral (30 days default)
│   Entries   │    Raw session details
└──────┬──────┘
       │ Pattern analysis
       ▼
┌─────────────┐
│ Reflections │  ← Permanent
│  (Insights) │    Patterns & preferences
└──────┬──────┘
       │ CLAUDE.md updates
       ▼
┌─────────────┐
│   Claude    │
│   Context   │
└─────────────┘
```

### Stage 1: Diary (Ephemeral)

After each conversation (3+ turns), Claude Code automatically prompts to create a diary entry:

```
Session recorded:
  ~/.claude/memory/michi-mem/diary/2026-01-28-session-1.md

Summary: Fixed authentication bug in login flow
Work done:
  - Debugged token validation logic
  - Added error handling for expired tokens
  - Updated tests to cover edge cases
```

**Retention**: Configurable (default 30 days). Old diaries are auto-deleted.

### Stage 2: Reflect (Permanent)

When you have 5+ unprocessed diary entries, run `/reflect` to analyze patterns:

```
Analyzed 7 diary entries
Found 3 strong patterns, 2 emerging observations

Strong patterns (3+ occurrences):
  ✓ Prefers verbose error messages over error codes
  ✓ Always writes tests before implementation
  ✓ Uses descriptive variable names over abbreviations

Moderate patterns (2 occurrences):
  • Requests confirmation before destructive operations
  • Prefers functional over object-oriented style
```

**Retention**: Permanent. Reflections are never auto-deleted.

### Stage 3: Cleanup (Automatic)

When you close Claude Code, old diary entries are automatically removed:

```
Cleaned up 3 diary entries older than 30 days
Kept 12 recent entries
All reflections retained (permanent)
```

**Why cleanup?** Diary entries are detailed and verbose (for reflection accuracy). Reflections are concise summaries (for long-term context). This keeps storage minimal while preserving insights.

## Commands

| Command | Description | Example |
|---------|-------------|---------|
| `/diary` | Manually create a diary entry for the current session | `/diary` |
| `/reflect` | Analyze unprocessed diary entries for patterns | `/reflect` |
| `/mem-status` | Show system statistics (diary count, storage, config) | `/mem-status` |

### Command Details

#### `/diary`

Creates a structured diary entry from the current session. Normally triggered automatically by the Stop hook, but you can run manually if needed.

**What gets captured:**
- Session summary
- Work completed
- Decisions made
- Preferences expressed
- Challenges encountered
- Patterns observed

**Output:**
```
Diary entry created: ~/.claude/memory/michi-mem/diary/2026-01-28-session-2.md
(5 unprocessed entries total)
```

#### `/reflect`

Analyzes all unprocessed diary entries to identify recurring patterns, then proposes updates to your project's `CLAUDE.md` file.

**Process:**
1. Reads unprocessed diary entries
2. Identifies patterns by frequency:
   - **Strong patterns**: 3+ occurrences
   - **Moderate patterns**: 2 occurrences
   - **Emerging observations**: 1 occurrence
3. Generates reflection document
4. Proposes CLAUDE.md updates (you review before applying)

**Output:**
```
Reflection saved: ~/.claude/memory/michi-mem/reflections/2026-01-28.md

Proposed CLAUDE.md updates:
  - Add preference: "Prefer descriptive error messages"
  - Add workflow: "Write tests before implementation"
```

#### `/mem-status`

Displays comprehensive system statistics:

```
michi-mem Status
================

Diary Entries
  Total:         12
  Last 30 days:  12
  Unprocessed:   5
  Last entry:    2026-01-28

Reflections
  Total:         2
  Last entry:    2026-01-25

Storage
  Total:         156 KB
  Diary:         98 KB
  Reflections:   24 KB

Config
  Diary retention:      30 days
  Reflect threshold:    5 unprocessed entries
  Reflection retention: permanent
```

## Configuration

Configuration is stored in `~/.claude/memory/michi-mem/config.json`:

```json
{
  "diary_retention_days": 30,
  "reflection_retention": "permanent",
  "auto_reflect_threshold": 5,
  "auto_record": true,
  "auto_record_min_turns": 3
}
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `diary_retention_days` | `30` | Days to keep diary entries before auto-deletion |
| `reflection_retention` | `"permanent"` | Retention for reflections (always permanent) |
| `auto_reflect_threshold` | `5` | Number of unprocessed entries before suggesting `/reflect` |
| `auto_record` | `true` | Enable auto-diary prompts after sessions |
| `auto_record_min_turns` | `3` | Minimum conversation turns before auto-diary prompt |

**Note**: Configuration is created automatically with defaults on first use. Edit manually if needed.

## File Locations

All michi-mem data is stored under `~/.claude/memory/michi-mem/`:

```
~/.claude/memory/michi-mem/
├── config.json                    # Configuration
├── diary/                         # Ephemeral session records
│   ├── 2026-01-28-session-1.md
│   ├── 2026-01-28-session-2.md
│   └── ...
├── reflections/                   # Permanent pattern insights
│   ├── 2026-01-25.md
│   ├── 2026-01-28.md
│   ├── processed.log              # Tracks which diaries were analyzed
│   └── ...
└── .state/                        # Internal tracking
    └── errors.log                 # Hook error log
```

## Documentation

- **[Installation Guide](docs/INSTALLATION.md)** - Detailed setup instructions with troubleshooting
- **[Contributing Guide](docs/CONTRIBUTING.md)** - Development setup, testing, and PR process
- **[Architecture](docs/ARCHITECTURE.md)** - Technical deep dive into system design

## Troubleshooting

### Commands not recognized after install

**Symptom**: `/diary`, `/reflect`, and `/mem-status` show "command not found"

**Solution**:
1. Verify plugin is enabled in `~/.claude/settings.json`
2. **Restart Claude Code** (required for command registration)
3. Run `/mem-status` to verify

### Auto-diary not prompting

**Symptom**: No diary prompt after conversations

**Possible causes**:
- Session too short (less than 3 turns by default)
- `auto_record` disabled in config
- Hook errors (check `~/.claude/memory/michi-mem/.state/errors.log`)

**Solution**:
1. Run `/mem-status` to check config
2. Check error log: `cat ~/.claude/memory/michi-mem/.state/errors.log`
3. Manually create entry: `/diary`

### Permission errors

**Symptom**: "Cannot write to ~/.claude/memory/michi-mem/"

**Solution**:
```bash
# Fix directory permissions
chmod -R u+w ~/.claude/memory/michi-mem/

# Or recreate directory
rm -rf ~/.claude/memory/michi-mem/
# Plugin will recreate on next use
```

For more troubleshooting, see [INSTALLATION.md](docs/INSTALLATION.md).

## Examples

Sample outputs are available in the [`examples/`](examples/) directory:
- Diary entry example
- Reflection analysis example
- CLAUDE.md update proposals

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions welcome! See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for:
- Bug reports and feature requests
- Development setup
- Testing guidelines
- Code style requirements
- Pull request process

## Roadmap

Future enhancements based on community feedback:
- Custom diary templates
- Export features (JSON, CSV)
- Advanced pattern detection
- Plugin marketplace submission

## Credits

Created by michi for the Claude Code community.
