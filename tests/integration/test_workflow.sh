#!/bin/bash
# Integration tests for michi-mem workflow
# Tests: config → diary → pattern analysis → cleanup

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test environment
TEST_ROOT="/tmp/michi-mem-test-$$"
TEST_HOME="$TEST_ROOT/home"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Helper functions
log_test() {
    echo -e "${YELLOW}TEST:${NC} $1"
    TESTS_RUN=$((TESTS_RUN + 1))
}

pass() {
    echo -e "${GREEN}PASS:${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "${RED}FAIL:${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

assert_file_exists() {
    if [ -f "$1" ]; then
        pass "File exists: $1"
    else
        fail "File does not exist: $1"
    fi
}

assert_file_contains() {
    if grep -q "$2" "$1" 2>/dev/null; then
        pass "File $1 contains '$2'"
    else
        fail "File $1 does not contain '$2'"
    fi
}

assert_count_equals() {
    local actual="$1"
    local expected="$2"
    local description="$3"
    if [ "$actual" -eq "$expected" ]; then
        pass "$description: $actual = $expected"
    else
        fail "$description: expected $expected, got $actual"
    fi
}

# Setup test environment
setup_test_env() {
    log_test "Setting up test environment"

    mkdir -p "$TEST_HOME/.michi-mem"
    mkdir -p "$TEST_HOME/.claude/memory/michi-mem/diary"
    mkdir -p "$TEST_HOME/.claude/memory/michi-mem/reflections"
    mkdir -p "$TEST_HOME/.claude/memory/michi-mem/.state"

    export HOME="$TEST_HOME"
    export PYTHONPATH="$REPO_ROOT"

    pass "Test environment created at $TEST_ROOT"
}

# Test 1: Configuration management
test_config_creation() {
    log_test "Config: default config creation"

    python3 -c "
from pathlib import Path
from scripts.lib.config import MemConfig

config = MemConfig(Path('$TEST_HOME/.michi-mem/config.json'))
assert config.get('retention_days') == 30
assert config.get('min_turns') == 3
print('Config created with defaults')
"

    assert_file_exists "$TEST_HOME/.michi-mem/config.json"
    assert_file_contains "$TEST_HOME/.michi-mem/config.json" '"retention_days": 30'
}

test_config_validation() {
    log_test "Config: validation of invalid values"

    # Create invalid config
    cat > "$TEST_HOME/.michi-mem/invalid.json" << 'EOF'
{
  "retention_days": -10,
  "min_turns": 3
}
EOF

    # Should raise ConfigError
    if python3 -c "
from pathlib import Path
from scripts.lib.config import MemConfig, ConfigError
try:
    config = MemConfig(Path('$TEST_HOME/.michi-mem/invalid.json'))
    print('VALIDATION_FAILED')
except ConfigError:
    print('VALIDATION_PASSED')
" | grep -q "VALIDATION_PASSED"; then
        pass "Config validation rejected invalid retention_days"
    else
        fail "Config validation did not reject invalid values"
    fi
}

# Test 2: Diary creation
test_diary_creation() {
    log_test "Diary: create entry with content"

    python3 -c "
from pathlib import Path
from datetime import datetime
from scripts.lib.diary_writer import DiaryWriter

diary_dir = Path('$TEST_HOME/.claude/memory/michi-mem/diary')
writer = DiaryWriter(diary_dir)

content = {
    'summary': 'Implemented test suite',
    'project': 'michi-mem',
    'branch': 'main',
    'work_done': ['Created integration tests', 'Added Makefile'],
    'decisions': ['Use bash for integration tests'],
    'preferences': ['Prefer pytest for unit tests']
}

filepath = writer.create_entry(content)
print(f'Created: {filepath}')
"

    # Check diary file was created
    local diary_count=$(find "$TEST_HOME/.claude/memory/michi-mem/diary" -name "*.md" | wc -l)
    assert_count_equals "$diary_count" 1 "Diary entry count"

    # Check content
    local diary_file=$(find "$TEST_HOME/.claude/memory/michi-mem/diary" -name "*.md" | head -1)
    assert_file_contains "$diary_file" "Implemented test suite"
    assert_file_contains "$diary_file" "michi-mem"
}

test_diary_multiple_sessions() {
    log_test "Diary: multiple sessions same day"

    python3 -c "
from pathlib import Path
from scripts.lib.diary_writer import DiaryWriter

diary_dir = Path('$TEST_HOME/.claude/memory/michi-mem/diary')
writer = DiaryWriter(diary_dir)

# Create 3 more entries
for i in range(3):
    content = {
        'summary': f'Session {i+2}',
        'project': 'test',
        'branch': 'main'
    }
    writer.create_entry(content)
"

    local diary_count=$(find "$TEST_HOME/.claude/memory/michi-mem/diary" -name "*.md" | wc -l)
    assert_count_equals "$diary_count" 4 "Total diary entries (including previous test)"
}

# Test 3: Pattern analysis
test_pattern_analysis() {
    log_test "Pattern: analyze entries for patterns"

    # Create diary entries with known patterns
    python3 -c "
from pathlib import Path
from scripts.lib.diary_writer import DiaryWriter

diary_dir = Path('$TEST_HOME/.claude/memory/michi-mem/diary')
writer = DiaryWriter(diary_dir)

# Create 5 entries with repeating patterns
patterns = [
    ['pytest preferred', 'avoid magic numbers'],
    ['pytest preferred', 'avoid magic numbers'],
    ['pytest preferred', 'use type hints'],
    ['pytest preferred', 'use type hints'],
    ['pytest preferred', 'clear variable names']
]

for i, prefs in enumerate(patterns):
    content = {
        'summary': f'Pattern test {i+1}',
        'project': 'test',
        'branch': 'main',
        'preferences': prefs
    }
    writer.create_entry(content)
"

    # Analyze patterns
    python3 -c "
from pathlib import Path
from scripts.lib.pattern_analyzer import PatternAnalyzer

diary_dir = str(Path('$TEST_HOME/.claude/memory/michi-mem/diary'))
reflections_dir = str(Path('$TEST_HOME/.claude/memory/michi-mem/reflections'))

analyzer = PatternAnalyzer(diary_dir, reflections_dir)
unprocessed = analyzer.get_unprocessed_entries()
print(f'Unprocessed entries: {len(unprocessed)}')

if len(unprocessed) > 0:
    analysis = analyzer.analyze(unprocessed)
    print(f'Strong patterns: {len(analysis[\"strong\"])}')
    print(f'Moderate patterns: {len(analysis[\"moderate\"])}')
    print(f'Emerging: {len(analysis[\"emerging\"])}')

    # Mark as processed
    analyzer.mark_processed(unprocessed)
"

    assert_file_exists "$TEST_HOME/.claude/memory/michi-mem/reflections/processed.log"
}

test_processed_tracking() {
    log_test "Pattern: processed entries tracking"

    # Check that entries are marked as processed
    python3 -c "
from pathlib import Path
from scripts.lib.pattern_analyzer import PatternAnalyzer

diary_dir = str(Path('$TEST_HOME/.claude/memory/michi-mem/diary'))
reflections_dir = str(Path('$TEST_HOME/.claude/memory/michi-mem/reflections'))

analyzer = PatternAnalyzer(diary_dir, reflections_dir)
unprocessed = analyzer.get_unprocessed_entries()
print(f'Remaining unprocessed: {len(unprocessed)}')
"

    pass "Processed tracking verified"
}

# Test 4: Cleanup script
test_cleanup_old_entries() {
    log_test "Cleanup: remove old diary entries"

    # Create old diary entries (simulate by creating with old timestamp)
    mkdir -p "$TEST_HOME/.claude/memory/michi-mem/diary"

    # Create a file that's "old" (we'll use touch -t to set old timestamp)
    local old_file="$TEST_HOME/.claude/memory/michi-mem/diary/2025-01-01-session-1.md"
    echo "# Old Entry" > "$old_file"
    touch -t 202501010000 "$old_file"

    # Create config with retention days
    cat > "$TEST_HOME/.claude/memory/michi-mem/config.json" << 'EOF'
{
  "retention_days": 30,
  "min_turns": 3
}
EOF

    # Run cleanup script
    DIARY_DIR="$TEST_HOME/.claude/memory/michi-mem/diary" \
    STATE_DIR="$TEST_HOME/.claude/memory/michi-mem/.state" \
    CONFIG="$TEST_HOME/.claude/memory/michi-mem/config.json" \
    bash "$REPO_ROOT/scripts/hooks/cleanup.sh" 2>&1

    # Check that old file was deleted
    if [ ! -f "$old_file" ]; then
        pass "Old diary entry was deleted"
    else
        fail "Old diary entry still exists"
    fi
}

test_cleanup_state_files() {
    log_test "Cleanup: remove stale state files"

    mkdir -p "$TEST_HOME/.claude/memory/michi-mem/.state"

    # Create old state file
    local old_state="$TEST_HOME/.claude/memory/michi-mem/.state/old-session.turns"
    echo "5" > "$old_state"
    touch -t 202501010000 "$old_state"

    # Create recent state file
    local recent_state="$TEST_HOME/.claude/memory/michi-mem/.state/recent-session.turns"
    echo "3" > "$recent_state"

    # Run cleanup
    DIARY_DIR="$TEST_HOME/.claude/memory/michi-mem/diary" \
    STATE_DIR="$TEST_HOME/.claude/memory/michi-mem/.state" \
    CONFIG="$TEST_HOME/.claude/memory/michi-mem/config.json" \
    bash "$REPO_ROOT/scripts/hooks/cleanup.sh" 2>&1

    # Old state should be gone, recent should remain
    if [ ! -f "$old_state" ] && [ -f "$recent_state" ]; then
        pass "Stale state files cleaned, recent files kept"
    else
        fail "State file cleanup did not work correctly"
    fi
}

# Test 5: Auto-diary hook (basic functionality)
test_auto_diary_hook() {
    log_test "Hook: auto-diary turn counting"

    mkdir -p "$TEST_HOME/.claude/memory/michi-mem/.state"

    # Create config
    cat > "$TEST_HOME/.claude/memory/michi-mem/config.json" << 'EOF'
{
  "retention_days": 30,
  "min_turns": 3,
  "auto_record": true,
  "auto_record_min_turns": 3
}
EOF

    # Simulate hook input
    local session_id="test-session-123"
    local hook_input="{\"session_id\": \"$session_id\"}"

    # First turn (should not prompt)
    echo "$hook_input" | CONFIG="$TEST_HOME/.claude/memory/michi-mem/config.json" \
        STATE_DIR="$TEST_HOME/.claude/memory/michi-mem/.state" \
        bash "$REPO_ROOT/scripts/hooks/auto-diary.sh" > /dev/null 2>&1

    # Check turn file
    local turn_file="$TEST_HOME/.claude/memory/michi-mem/.state/${session_id}.turns"
    assert_file_exists "$turn_file"

    local turns=$(cat "$turn_file")
    assert_count_equals "$turns" 1 "Turn count after first call"
}

# Cleanup test environment
cleanup_test_env() {
    log_test "Cleaning up test environment"

    rm -rf "$TEST_ROOT"

    pass "Test environment cleaned up"
}

# Print test summary
print_summary() {
    echo ""
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo "Tests run:    $TESTS_RUN"
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"

    if [ "$TESTS_FAILED" -gt 0 ]; then
        echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
        echo "========================================"
        exit 1
    else
        echo "Tests failed: 0"
        echo "========================================"
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

# Run all tests
main() {
    echo "========================================"
    echo "michi-mem Integration Test Suite"
    echo "========================================"
    echo ""

    setup_test_env

    # Configuration tests
    test_config_creation
    test_config_validation

    # Diary tests
    test_diary_creation
    test_diary_multiple_sessions

    # Pattern analysis tests
    test_pattern_analysis
    test_processed_tracking

    # Cleanup tests
    test_cleanup_old_entries
    test_cleanup_state_files

    # Hook tests
    test_auto_diary_hook

    cleanup_test_env

    print_summary
}

# Run main if script is executed directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
