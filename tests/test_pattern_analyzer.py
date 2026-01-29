import os
import tempfile
from pathlib import Path
import pytest
from scripts.lib.pattern_analyzer import PatternAnalyzer


@pytest.fixture
def test_env(tmp_path):
    diary_dir = tmp_path / "diaries"
    reflections_dir = tmp_path / "reflections"
    diary_dir.mkdir()
    reflections_dir.mkdir()

    fixtures_dir = Path(__file__).parent / "fixtures"
    for fixture_file in ["diary-1.md", "diary-2.md", "diary-3.md"]:
        src = fixtures_dir / fixture_file
        dst = diary_dir / fixture_file
        dst.write_text(src.read_text())

    return {
        "diary_dir": diary_dir,
        "reflections_dir": reflections_dir,
        "analyzer": PatternAnalyzer(str(diary_dir), str(reflections_dir))
    }


def test_finds_unprocessed_entries(test_env):
    analyzer = test_env["analyzer"]
    entries = analyzer.get_unprocessed_entries()

    assert len(entries) == 3
    assert all(entry.endswith(".md") for entry in entries)
    assert any("diary-1.md" in entry for entry in entries)
    assert any("diary-2.md" in entry for entry in entries)
    assert any("diary-3.md" in entry for entry in entries)


def test_excludes_processed_entries(test_env):
    analyzer = test_env["analyzer"]
    diary_dir = test_env["diary_dir"]
    reflections_dir = test_env["reflections_dir"]

    processed_log = reflections_dir / "processed.log"
    processed_log.write_text(str(diary_dir / "diary-1.md") + "\n")

    entries = analyzer.get_unprocessed_entries()

    assert len(entries) == 2
    assert all("diary-1.md" not in entry for entry in entries)
    assert any("diary-2.md" in entry for entry in entries)
    assert any("diary-3.md" in entry for entry in entries)


def test_detects_strong_patterns(test_env):
    analyzer = test_env["analyzer"]
    entries = analyzer.get_unprocessed_entries()

    results = analyzer.analyze(entries)

    assert "strong" in results
    assert len(results["strong"]) == 1
    assert results["strong"][0]["pattern"] == "Prefer pytest over unittest"
    assert results["strong"][0]["count"] == 3


def test_detects_moderate_patterns(test_env):
    analyzer = test_env["analyzer"]
    entries = analyzer.get_unprocessed_entries()

    results = analyzer.analyze(entries)

    assert "moderate" in results
    moderate_patterns = [p["pattern"] for p in results["moderate"]]

    assert "Use Black for formatting" in moderate_patterns
    assert "Write tests first (TDD)" in moderate_patterns
    assert "Use PostgreSQL for database" in moderate_patterns

    for pattern in results["moderate"]:
        assert pattern["count"] == 2


def test_detects_emerging_patterns(test_env):
    analyzer = test_env["analyzer"]
    entries = analyzer.get_unprocessed_entries()

    results = analyzer.analyze(entries)

    assert "emerging" in results
    emerging_patterns = [p["pattern"] for p in results["emerging"]]

    assert "Use JWT for authentication" in emerging_patterns

    for pattern in results["emerging"]:
        assert pattern["count"] == 1


def test_marks_entries_as_processed(test_env):
    analyzer = test_env["analyzer"]
    diary_dir = test_env["diary_dir"]
    reflections_dir = test_env["reflections_dir"]

    entries = analyzer.get_unprocessed_entries()
    analyzer.mark_processed(entries)

    processed_log = reflections_dir / "processed.log"
    assert processed_log.exists()

    processed_content = processed_log.read_text()
    assert str(diary_dir / "diary-1.md") in processed_content
    assert str(diary_dir / "diary-2.md") in processed_content
    assert str(diary_dir / "diary-3.md") in processed_content

    new_entries = analyzer.get_unprocessed_entries()
    assert len(new_entries) == 0
