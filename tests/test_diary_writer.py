import os
import json
import tempfile
import shutil
from pathlib import Path
from datetime import datetime
import pytest
from scripts.lib.diary_writer import DiaryWriter


@pytest.fixture
def temp_diary_dir():
    temp_dir = tempfile.mkdtemp()
    yield temp_dir
    shutil.rmtree(temp_dir)


@pytest.fixture
def sample_content():
    fixture_path = Path(__file__).parent / "fixtures" / "sample_content.json"
    with open(fixture_path) as f:
        return json.load(f)


def test_creates_diary_entry(temp_diary_dir, sample_content):
    """Test that diary entry is created with correct filename."""
    writer = DiaryWriter(temp_diary_dir)
    entry_path = writer.create_entry(sample_content)

    assert os.path.exists(entry_path)

    today = datetime.now().strftime("%Y-%m-%d")
    expected_filename = f"{today}_session_001.md"
    assert entry_path.endswith(expected_filename)


def test_increments_session_number(temp_diary_dir, sample_content):
    """Test that session numbers increment correctly."""
    writer = DiaryWriter(temp_diary_dir)

    # Create first entry
    entry1 = writer.create_entry(sample_content)
    assert "_session_001.md" in entry1

    # Create second entry (same day)
    entry2 = writer.create_entry(sample_content)
    assert "_session_002.md" in entry2

    # Create third entry
    entry3 = writer.create_entry(sample_content)
    assert "_session_003.md" in entry3


def test_formats_markdown_correctly(temp_diary_dir, sample_content):
    """Test that markdown is formatted correctly with all sections."""
    writer = DiaryWriter(temp_diary_dir)
    entry_path = writer.create_entry(sample_content)

    with open(entry_path) as f:
        content = f.read()

    # Check metadata
    assert "Project: /Users/test/project" in content
    assert "Branch: main" in content
    today = datetime.now().strftime("%Y-%m-%d")
    assert f"Date: {today}" in content
    assert "Session: 001" in content

    # Check summary
    assert "## Summary" in content
    assert "Implemented user authentication" in content

    # Check work done section
    assert "## Work Done" in content
    assert "- Added login endpoint" in content
    assert "- Created user model" in content

    # Check decisions section
    assert "## Decisions Made" in content
    assert "- Use JWT for authentication" in content

    # Check preferences section
    assert "## Preferences Learned" in content
    assert "- Prefer pytest over unittest" in content


def test_skips_empty_sections(temp_diary_dir):
    """Test that empty sections are omitted from output."""
    writer = DiaryWriter(temp_diary_dir)

    # Content with only summary and work_done
    partial_content = {
        "project": "/Users/test/project",
        "branch": "main",
        "summary": "Simple change",
        "work_done": ["Updated README"],
        "decisions": [],
        "preferences": []
    }

    entry_path = writer.create_entry(partial_content)

    with open(entry_path) as f:
        content = f.read()

    # Should have summary and work done
    assert "## Summary" in content
    assert "## Work Done" in content

    # Should NOT have empty sections
    assert "## Decisions Made" not in content
    assert "## Preferences Learned" not in content


def test_atomic_write(temp_diary_dir, sample_content):
    """Test that entries are written atomically (no .tmp files left)."""
    writer = DiaryWriter(temp_diary_dir)
    entry_path = writer.create_entry(sample_content)

    # Check that the final file exists
    assert os.path.exists(entry_path)

    # Check that no .tmp files are left behind
    diary_files = os.listdir(temp_diary_dir)
    tmp_files = [f for f in diary_files if f.endswith('.tmp')]
    assert len(tmp_files) == 0, "Temporary files should not be left behind"
