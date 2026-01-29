import os
import re
from pathlib import Path
from collections import Counter
from typing import List, Dict, Any


class PatternAnalyzer:
    def __init__(self, diary_dir: str, reflections_dir: str):
        self.diary_dir = Path(diary_dir)
        self.reflections_dir = Path(reflections_dir)
        self.processed_log = self.reflections_dir / "processed.log"

    def get_unprocessed_entries(self) -> List[str]:
        processed_files = set()

        if self.processed_log.exists():
            with open(self.processed_log, 'r') as f:
                processed_files = set(line.strip() for line in f if line.strip())

        all_entries = []
        for entry in self.diary_dir.glob("*.md"):
            entry_path = str(entry)
            if entry_path not in processed_files:
                all_entries.append(entry_path)

        return sorted(all_entries)

    def analyze(self, entries: List[str]) -> Dict[str, List[Dict[str, Any]]]:
        all_patterns = []

        for entry_path in entries:
            patterns = self._parse_entry(entry_path)
            all_patterns.extend(patterns)

        pattern_counts = Counter(all_patterns)

        strong = []
        moderate = []
        emerging = []

        for pattern, count in pattern_counts.items():
            pattern_data = {"pattern": pattern, "count": count}

            if count >= 3:
                strong.append(pattern_data)
            elif count == 2:
                moderate.append(pattern_data)
            elif count == 1:
                emerging.append(pattern_data)

        return {
            "strong": sorted(strong, key=lambda x: x["count"], reverse=True),
            "moderate": sorted(moderate, key=lambda x: x["pattern"]),
            "emerging": sorted(emerging, key=lambda x: x["pattern"])
        }

    def _parse_entry(self, entry_path: str) -> List[str]:
        with open(entry_path, 'r') as f:
            content = f.read()

        patterns = []
        patterns.extend(self._extract_section(content, "Preferences Observed"))
        patterns.extend(self._extract_section(content, "Decisions Made"))

        return patterns

    def _extract_section(self, content: str, section_name: str) -> List[str]:
        pattern = rf"^## {re.escape(section_name)}\s*\n((?:^- .+\n?)*)"
        match = re.search(pattern, content, re.MULTILINE)

        if not match:
            return []

        section_content = match.group(1)
        items = re.findall(r"^- (.+)$", section_content, re.MULTILINE)

        return items

    def mark_processed(self, entries: List[str]) -> None:
        with open(self.processed_log, 'a') as f:
            for entry in entries:
                f.write(entry + "\n")
