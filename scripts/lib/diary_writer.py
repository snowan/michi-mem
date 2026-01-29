import os
from pathlib import Path
from datetime import datetime


class DiaryWriter:
    """Writes diary entries with session numbering and markdown formatting."""

    def __init__(self, diary_dir):
        """
        Initialize the diary writer.

        Args:
            diary_dir: Directory where diary entries will be stored
        """
        self.diary_dir = Path(diary_dir)
        self.diary_dir.mkdir(parents=True, exist_ok=True)

    def create_entry(self, content):
        """
        Create a new diary entry.

        Args:
            content: Dictionary containing entry data with keys:
                - project: Project path
                - branch: Git branch name
                - summary: Brief summary of the work
                - work_done: List of work items completed
                - decisions: List of decisions made
                - preferences: List of preferences learned

        Returns:
            Path to the created diary entry file
        """
        today = datetime.now().strftime("%Y-%m-%d")
        session_number = self._get_next_session_number(today)

        entry_content = self._format_entry(content, today, session_number)

        filename = f"{today}_session_{session_number:03d}.md"
        entry_path = self.diary_dir / filename

        # Atomic write: write to temp file, then rename
        temp_path = self.diary_dir / f"{filename}.tmp"
        try:
            with open(temp_path, "w") as f:
                f.write(entry_content)
            os.rename(temp_path, entry_path)
        finally:
            # Clean up temp file if it still exists
            if temp_path.exists():
                temp_path.unlink()

        return str(entry_path)

    def _get_next_session_number(self, date):
        """
        Get the next session number for a given date.

        Args:
            date: Date string in YYYY-MM-DD format

        Returns:
            Next session number (starting from 1)
        """
        existing_sessions = list(self.diary_dir.glob(f"{date}_session_*.md"))
        return len(existing_sessions) + 1

    def _format_entry(self, content, date, session):
        """
        Format the diary entry as markdown.

        Args:
            content: Dictionary containing entry data
            date: Date string in YYYY-MM-DD format
            session: Session number

        Returns:
            Formatted markdown string
        """
        lines = []

        # Metadata section
        lines.append(f"Project: {content.get('project', 'N/A')}")
        lines.append(f"Branch: {content.get('branch', 'N/A')}")
        lines.append(f"Date: {date}")
        lines.append(f"Session: {session:03d}")
        lines.append("")

        # Summary section
        if content.get("summary"):
            lines.append("## Summary")
            lines.append("")
            lines.append(content["summary"])
            lines.append("")

        # Work Done section
        work_done = content.get("work_done", [])
        if work_done:
            lines.append("## Work Done")
            lines.append("")
            for item in work_done:
                lines.append(f"- {item}")
            lines.append("")

        # Decisions Made section
        decisions = content.get("decisions", [])
        if decisions:
            lines.append("## Decisions Made")
            lines.append("")
            for item in decisions:
                lines.append(f"- {item}")
            lines.append("")

        # Preferences Learned section
        preferences = content.get("preferences", [])
        if preferences:
            lines.append("## Preferences Learned")
            lines.append("")
            for item in preferences:
                lines.append(f"- {item}")
            lines.append("")

        return "\n".join(lines).rstrip() + "\n"
