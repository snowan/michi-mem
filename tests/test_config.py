"""
Tests for configuration module.
"""
import json
import pytest
from pathlib import Path
from scripts.lib.config import MemConfig, ConfigError


def test_creates_default_config_if_missing(tmp_path):
    """Creates default config.json if it doesn't exist."""
    config_file = tmp_path / "config.json"
    assert not config_file.exists()

    config = MemConfig(config_path=config_file)

    assert config_file.exists()
    data = json.loads(config_file.read_text())
    assert data["retention_days"] == 30
    assert data["min_turns"] == 3
    assert data["plugins"]["mem"]["enabled"] is True


def test_loads_existing_config(tmp_path):
    """Loads custom values from existing config file."""
    config_file = tmp_path / "config.json"
    custom_config = {
        "retention_days": 60,
        "min_turns": 5,
        "plugins": {
            "mem": {"enabled": False}
        }
    }
    config_file.write_text(json.dumps(custom_config))

    config = MemConfig(config_path=config_file)

    assert config.get("retention_days") == 60
    assert config.get("min_turns") == 5
    assert config.get("plugins")["mem"]["enabled"] is False


def test_validates_positive_retention_days(tmp_path):
    """Rejects negative retention days."""
    config_file = tmp_path / "config.json"
    invalid_config = {
        "retention_days": -10,
        "min_turns": 3,
        "plugins": {"mem": {"enabled": True}}
    }
    config_file.write_text(json.dumps(invalid_config))

    with pytest.raises(ConfigError, match="retention_days must be positive"):
        MemConfig(config_path=config_file)


def test_validates_positive_min_turns(tmp_path):
    """Rejects zero or negative min turns."""
    config_file = tmp_path / "config.json"
    invalid_config = {
        "retention_days": 30,
        "min_turns": 0,
        "plugins": {"mem": {"enabled": True}}
    }
    config_file.write_text(json.dumps(invalid_config))

    with pytest.raises(ConfigError, match="min_turns must be positive"):
        MemConfig(config_path=config_file)


def test_merges_with_defaults(tmp_path):
    """Merges partial user config with defaults."""
    config_file = tmp_path / "config.json"
    partial_config = {
        "retention_days": 90
    }
    config_file.write_text(json.dumps(partial_config))

    config = MemConfig(config_path=config_file)

    assert config.get("retention_days") == 90
    assert config.get("min_turns") == 3
    assert config.get("plugins")["mem"]["enabled"] is True
