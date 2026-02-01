.PHONY: help test install install-dev uninstall verify clean lint format

# Default target
help:
	@echo "michi-mem Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make test        - Run integration tests"
	@echo "  make install     - Install plugin to ~/.claude/plugins/repos/"
	@echo "  make install-dev - Install plugin in development mode (with symlink)"
	@echo "  make uninstall   - Remove plugin installation"
	@echo "  make verify      - Show instructions to verify command registration"
	@echo "  make clean       - Remove Python cache files"
	@echo "  make lint        - Run linters (shellcheck, flake8)"
	@echo "  make format      - Format code (black, prettier)"

# Run integration tests
test:
	@echo "Running integration tests..."
	@./tests/integration/test_workflow.sh

# Install plugin to Claude Code plugins directory
install:
	@echo "Installing michi-mem plugin..."
	@mkdir -p ~/.claude/plugins/repos
	@if [ -d ~/.claude/plugins/repos/michi-mem ]; then \
		echo "Removing existing installation..."; \
		rm -rf ~/.claude/plugins/repos/michi-mem; \
	fi
	@cp -r . ~/.claude/plugins/repos/michi-mem
	@echo ""
	@echo "✓ Plugin installed to ~/.claude/plugins/repos/michi-mem"
	@echo ""
	@echo "Next steps:"
	@echo "1. Add to ~/.claude/settings.json:"
	@echo "   \"plugins\": {"
	@echo "     \"michi-mem@local\": true"
	@echo "   }"
	@echo "2. Restart Claude Code (required for commands to register)"
	@echo "3. Run 'make verify' to check installation"

# Uninstall plugin
uninstall:
	@echo "Uninstalling michi-mem plugin..."
	@if [ -d ~/.claude/plugins/repos/michi-mem ]; then \
		rm -rf ~/.claude/plugins/repos/michi-mem; \
		echo "✓ Plugin uninstalled"; \
	else \
		echo "Plugin not found at ~/.claude/plugins/repos/michi-mem"; \
	fi
	@echo ""
	@echo "Don't forget to remove from ~/.claude/settings.json:"
	@echo "  \"michi-mem@local\": true"

# Verify installation
verify:
	@echo "Verifying michi-mem installation..."
	@echo ""
	@if [ -d ~/.claude/plugins/repos/michi-mem ]; then \
		echo "✓ Plugin directory exists"; \
	else \
		echo "✗ Plugin directory not found"; \
		echo "  Run 'make install' first"; \
		exit 1; \
	fi
	@echo ""
	@echo "Check plugin registration:"
	@echo "1. Restart Claude Code if you haven't already"
	@echo "2. In Claude Code, try these commands:"
	@echo "   /diary      - Create diary entry"
	@echo "   /reflect    - Analyze patterns"
	@echo "   /mem-status - Check plugin status"
	@echo ""
	@echo "If commands are not recognized:"
	@echo "- Verify ~/.claude/settings.json contains:"
	@echo "    \"michi-mem@local\": true"
	@echo "- Restart Claude Code"
	@echo "- Check logs at ~/.claude/logs/"

# Install plugin in development mode (symlink)
install-dev:
	@echo "Installing michi-mem plugin in development mode..."
	@mkdir -p ~/.claude/plugins/repos
	@if [ -L ~/.claude/plugins/repos/michi-mem ]; then \
		echo "Removing existing symlink..."; \
		rm ~/.claude/plugins/repos/michi-mem; \
	elif [ -d ~/.claude/plugins/repos/michi-mem ]; then \
		echo "Removing existing installation..."; \
		rm -rf ~/.claude/plugins/repos/michi-mem; \
	fi
	@ln -s "$(PWD)" ~/.claude/plugins/repos/michi-mem
	@echo ""
	@echo "✓ Plugin symlinked for development"
	@echo ""
	@echo "Next steps:"
	@echo "1. Add to ~/.claude/settings.json:"
	@echo "   \"plugins\": {"
	@echo "     \"michi-mem@local\": true"
	@echo "   }"
	@echo "2. Restart Claude Code (required for commands to register)"
	@echo "3. Changes to code will be reflected immediately (no reinstall needed)"

# Clean Python cache files
clean:
	@echo "Cleaning Python cache files..."
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@echo "✓ Cache files cleaned"

# Run linters
lint:
	@echo "Running linters..."
	@echo ""
	@echo "Checking bash scripts with shellcheck..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck scripts/hooks/*.sh tests/integration/*.sh || true; \
	else \
		echo "⚠ shellcheck not installed (install with: brew install shellcheck)"; \
	fi
	@echo ""
	@echo "Checking Python with flake8..."
	@if command -v flake8 >/dev/null 2>&1; then \
		flake8 scripts/lib/ tests/ --max-line-length=100 || true; \
	else \
		echo "⚠ flake8 not installed (install with: pip install flake8)"; \
	fi

# Format code
format:
	@echo "Formatting code..."
	@echo ""
	@echo "Formatting Python with black..."
	@if command -v black >/dev/null 2>&1; then \
		black scripts/lib/ tests/; \
	else \
		echo "⚠ black not installed (install with: pip install black)"; \
	fi
	@echo ""
	@echo "✓ Code formatted"
