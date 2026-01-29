"""
Configuration management for michi-mem.
"""
import json
from pathlib import Path
from typing import Any, Dict


class ConfigError(Exception):
    """Raised when configuration is invalid."""
    pass


class MemConfig:
    """Manages michi-mem configuration with validation."""

    DEFAULTS = {
        "retention_days": 30,
        "min_turns": 3,
        "plugins": {
            "mem": {"enabled": True}
        }
    }

    def __init__(self, config_path: Path | str | None = None):
        """
        Initialize configuration.

        Args:
            config_path: Path to config file. If None, uses ~/.michi-mem/config.json
        """
        if config_path is None:
            config_path = Path.home() / ".michi-mem" / "config.json"
        self.config_path = Path(config_path)
        self._data = self._load()

    def _load(self) -> Dict[str, Any]:
        """Load configuration from file or create defaults."""
        if not self.config_path.exists():
            self.config_path.parent.mkdir(parents=True, exist_ok=True)
            self._save(self.DEFAULTS)
            return self.DEFAULTS.copy()

        user_config = json.loads(self.config_path.read_text())
        merged_config = self._merge_with_defaults(user_config)
        self._validate(merged_config)
        return merged_config

    def _save(self, data: Dict[str, Any]) -> None:
        """Write configuration to file."""
        self.config_path.write_text(json.dumps(data, indent=2))

    def _merge_with_defaults(self, user_config: Dict[str, Any]) -> Dict[str, Any]:
        """Merge user configuration with defaults."""
        merged = self.DEFAULTS.copy()

        for key, value in user_config.items():
            if key == "plugins" and isinstance(value, dict):
                merged["plugins"] = {**merged["plugins"], **value}
            else:
                merged[key] = value

        return merged

    def _validate(self, config: Dict[str, Any]) -> None:
        """Validate configuration values."""
        if config.get("retention_days", 0) <= 0:
            raise ConfigError("retention_days must be positive")

        if config.get("min_turns", 0) <= 0:
            raise ConfigError("min_turns must be positive")

    def get(self, key: str, default: Any = None) -> Any:
        """
        Get configuration value.

        Args:
            key: Configuration key
            default: Default value if key not found

        Returns:
            Configuration value or default
        """
        return self._data.get(key, default)
