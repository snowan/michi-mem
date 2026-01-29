# Installation Guide

Complete installation instructions for michi-mem, including prerequisites, setup steps, and troubleshooting.

## Prerequisites

Before installing michi-mem, ensure you have:

### Required

- **Claude Code CLI** - Latest version
- **Python 3.7+** - For analysis scripts
  ```bash
  python3 --version  # Should show 3.7 or higher
  ```
- **Bash** - For hooks (pre-installed on macOS/Linux)

### Optional

- **git** - For project context in diary entries (branch, repo info)

### Permissions

michi-mem needs write access to:
```
~/.claude/memory/michi-mem/  # Data storage
~/.claude/settings.json      # Plugin configuration
```

## Installation Methods

### Method 1: Local Repository (Recommended)

Best for development or if you want to customize the plugin.

#### Step 1: Clone Repository

```bash
# Navigate to Claude Code plugins directory
cd ~/.claude/plugins/repos/

# Clone the repository
git clone https://github.com/<username>/michi-mem

# Verify files
ls -la michi-mem/
# Should see: .claude-plugin/, commands/, scripts/, tests/, README.md
```

#### Step 2: Enable Plugin

Add to `~/.claude/settings.json`:

```json
{
  "plugins": {
    "michi-mem@local": true
  }
}
```

**Note**: If the file doesn't exist, create it with the above content.

#### Step 3: Restart Claude Code

**Critical**: Commands won't be recognized until you restart Claude Code.

```bash
# Exit current Claude Code session
exit

# Start new session
claude-code
```

#### Step 4: Verify Installation

```bash
/mem-status
```

**Expected output**:
```
michi-mem Status
================

Diary Entries
  Total:         0
  Last 30 days:  0
  Unprocessed:   0
  Last entry:    none

Reflections
  Total:         0
  Last entry:    none
```

If you see this, installation succeeded!

### Method 2: Plugin Marketplace (Coming Soon)

Once michi-mem is published to the Claude Code plugin marketplace:

```bash
# In Claude Code
/plugin install michi-mem

# Restart Claude Code
exit
claude-code

# Verify
/mem-status
```

## Verification Steps

After installation, verify each component:

### 1. Commands Available

Test each command:

```bash
/mem-status    # Should show system statistics
/diary         # Should prompt for diary entry
/reflect       # Should say "no unprocessed entries"
```

### 2. Hooks Registered

Check hooks configuration:

```bash
cat ~/.claude/plugins/repos/michi-mem/scripts/hooks/hooks.json
```

Expected content:
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

### 3. Python Scripts Executable

```bash
cd ~/.claude/plugins/repos/michi-mem/

# Test config module
python3 -c "from scripts.lib.config import MemConfig; print('Config OK')"

# Test diary writer
python3 -c "from scripts.lib.diary_writer import DiaryWriter; print('Diary OK')"

# Test pattern analyzer
python3 -c "from scripts.lib.pattern_analyzer import PatternAnalyzer; print('Analyzer OK')"
```

All should print "OK" messages.

### 4. Directory Structure Created

After running any command, verify directories exist:

```bash
ls -la ~/.claude/memory/michi-mem/
```

Expected structure:
```
~/.claude/memory/michi-mem/
├── config.json
├── diary/
├── reflections/
└── .state/
```

## Configuration

### Default Configuration

On first use, michi-mem creates `~/.claude/memory/michi-mem/config.json` with defaults:

```json
{
  "diary_retention_days": 30,
  "reflection_retention": "permanent",
  "auto_reflect_threshold": 5,
  "auto_record": true,
  "auto_record_min_turns": 3
}
```

### Customizing Configuration

Edit the config file directly:

```bash
# Open in editor
nano ~/.claude/memory/michi-mem/config.json

# Or use sed for specific changes
# Example: Change diary retention to 60 days
cd ~/.claude/memory/michi-mem/
cp config.json config.json.bak
python3 -c "
import json
with open('config.json', 'r') as f:
    config = json.load(f)
config['diary_retention_days'] = 60
with open('config.json', 'w') as f:
    json.dump(config, f, indent=2)
"
```

### Configuration Validation

After editing, verify config is valid:

```bash
cd ~/.claude/plugins/repos/michi-mem/
python3 -c "
from scripts.lib.config import MemConfig
try:
    config = MemConfig()
    print('Config valid!')
    print(f'Diary retention: {config.get(\"diary_retention_days\")} days')
except Exception as e:
    print(f'Config error: {e}')
"
```

## Troubleshooting

### Commands Not Recognized

**Symptom**: `/diary` shows "command not found"

**Diagnosis**:
```bash
# Check plugin enabled in settings
cat ~/.claude/settings.json | grep michi-mem

# Check commands directory exists
ls -la ~/.claude/plugins/repos/michi-mem/commands/

# Check plugin.json
cat ~/.claude/plugins/repos/michi-mem/.claude-plugin/plugin.json
```

**Solutions**:

1. **Plugin not enabled**: Add to settings.json
   ```json
   {
     "plugins": {
       "michi-mem@local": true
     }
   }
   ```

2. **Need to restart**: Exit and restart Claude Code
   ```bash
   exit
   claude-code
   ```

3. **Files missing**: Re-clone repository
   ```bash
   cd ~/.claude/plugins/repos/
   rm -rf michi-mem
   git clone https://github.com/<username>/michi-mem
   ```

### Auto-Diary Not Prompting

**Symptom**: No diary prompt after conversations

**Diagnosis**:
```bash
# Check config
cat ~/.claude/memory/michi-mem/config.json

# Check hook errors
cat ~/.claude/memory/michi-mem/.state/errors.log
```

**Solutions**:

1. **Auto-record disabled**: Edit config.json
   ```json
   {
     "auto_record": true,
     "auto_record_min_turns": 3
   }
   ```

2. **Session too short**: Have 3+ conversation turns before expecting prompt

3. **Hook errors**: Check error log for details
   ```bash
   tail -20 ~/.claude/memory/michi-mem/.state/errors.log
   ```

4. **Manual fallback**: Create entry manually
   ```bash
   /diary
   ```

### Permission Errors

**Symptom**: "Cannot write to ~/.claude/memory/michi-mem/"

**Diagnosis**:
```bash
# Check directory exists
ls -ld ~/.claude/memory/michi-mem/

# Check permissions
ls -la ~/.claude/memory/michi-mem/
```

**Solutions**:

1. **Fix permissions**:
   ```bash
   chmod -R u+w ~/.claude/memory/michi-mem/
   ```

2. **Recreate directory**:
   ```bash
   rm -rf ~/.claude/memory/michi-mem/
   # Will be recreated on next use
   ```

3. **Check disk space**:
   ```bash
   df -h ~
   ```

### Python Import Errors

**Symptom**: "ModuleNotFoundError: No module named 'scripts.lib'"

**Diagnosis**:
```bash
# Check Python version
python3 --version

# Check files exist
ls -la ~/.claude/plugins/repos/michi-mem/scripts/lib/
```

**Solutions**:

1. **Wrong Python version**: Upgrade to Python 3.7+
   ```bash
   # macOS with Homebrew
   brew install python@3.11

   # Linux (Ubuntu/Debian)
   sudo apt update
   sudo apt install python3.11
   ```

2. **Files missing**: Re-clone repository

3. **Wrong directory**: Scripts must be run from plugin root or with correct PYTHONPATH

### Reflection Not Finding Patterns

**Symptom**: `/reflect` says "No patterns found" despite having diary entries

**Diagnosis**:
```bash
# Check unprocessed entries
cat ~/.claude/memory/michi-mem/reflections/processed.log

# Count diary entries
ls -1 ~/.claude/memory/michi-mem/diary/*.md | wc -l
```

**Solutions**:

1. **All entries already processed**: Check processed.log
   ```bash
   # See which entries were analyzed
   cat ~/.claude/memory/michi-mem/reflections/processed.log
   ```

2. **Diary entries lack structure**: Verify diary format
   ```bash
   # Check diary structure
   head -30 ~/.claude/memory/michi-mem/diary/*.md | head -1
   ```

3. **Need more entries**: Create 5+ entries before meaningful patterns emerge

### Hook Errors

**Symptom**: Errors in `~/.claude/memory/michi-mem/.state/errors.log`

**Diagnosis**:
```bash
# View recent errors
tail -50 ~/.claude/memory/michi-mem/.state/errors.log
```

**Common errors and solutions**:

1. **"python3: command not found"**
   - Install Python 3.7+

2. **"Permission denied"**
   - Fix directory permissions (see above)

3. **"Config validation failed"**
   - Fix or delete config.json (will be recreated with defaults)

4. **"Git command failed"**
   - Normal if not in a git repository
   - Diary entries will still be created without git context

## Uninstallation

### Complete Removal

Remove plugin and all data:

```bash
# 1. Remove plugin files
rm -rf ~/.claude/plugins/repos/michi-mem

# 2. Remove data
rm -rf ~/.claude/memory/michi-mem

# 3. Remove from settings.json
# Edit ~/.claude/settings.json and remove:
#   "michi-mem@local": true

# 4. Restart Claude Code
exit
claude-code
```

### Keep Data, Remove Plugin

Remove plugin but preserve diary entries and reflections:

```bash
# 1. Backup data
cp -r ~/.claude/memory/michi-mem ~/michi-mem-backup

# 2. Remove plugin
rm -rf ~/.claude/plugins/repos/michi-mem

# 3. Update settings.json (remove plugin entry)

# 4. Restart Claude Code
```

### Reinstall

To reinstall after uninstalling:

```bash
# 1. Follow installation steps again
cd ~/.claude/plugins/repos/
git clone https://github.com/<username>/michi-mem

# 2. If you kept data, it will be reused
# 3. If you removed data, fresh directories will be created
```

## Next Steps

After successful installation:

1. **Try creating a diary entry**: `/diary`
2. **Have 5+ conversations**, then run `/reflect`
3. **Review system status**: `/mem-status`
4. **Customize configuration** if needed (see Configuration section)
5. **Read the architecture docs**: [ARCHITECTURE.md](ARCHITECTURE.md)

## Getting Help

If you encounter issues not covered here:

1. **Check error logs**:
   ```bash
   cat ~/.claude/memory/michi-mem/.state/errors.log
   ```

2. **Run diagnostics**:
   ```bash
   /mem-status
   ```

3. **Report bugs**: See [CONTRIBUTING.md](CONTRIBUTING.md) for bug report process

4. **Ask for help**: Open an issue on GitHub with:
   - Steps to reproduce
   - Error messages
   - Output of `/mem-status`
   - Relevant logs
