#!/bin/bash
# Install git hooks for kelsea.io local development
# Usage: ./scripts/install-hooks.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOKS_SOURCE="${PROJECT_ROOT}/.githooks"
HOOKS_DEST="${PROJECT_ROOT}/.git/hooks"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

echo ""
echo "Installing git hooks for kelsea.io..."
echo ""

# Check if .git directory exists
if [[ ! -d "${PROJECT_ROOT}/.git" ]]; then
    echo "Error: Not a git repository. Run 'git init' first."
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "${HOOKS_DEST}"

# Install pre-commit hook
if [[ -f "${HOOKS_SOURCE}/pre-commit" ]]; then
    cp "${HOOKS_SOURCE}/pre-commit" "${HOOKS_DEST}/pre-commit"
    chmod +x "${HOOKS_DEST}/pre-commit"
    echo -e "${GREEN}✓${RESET} Installed pre-commit hook"
else
    echo -e "${YELLOW}⚠${RESET} pre-commit hook not found in .githooks/"
fi

# Make test scripts executable
chmod +x "${PROJECT_ROOT}/tests/run_tests.sh" 2>/dev/null || true
chmod +x "${PROJECT_ROOT}/tests/acceptance"/*/*.sh 2>/dev/null || true
chmod +x "${PROJECT_ROOT}/tests/lib"/*.sh 2>/dev/null || true

echo ""
echo -e "${GREEN}Git hooks installed successfully!${RESET}"
echo ""
echo "The following hooks are now active:"
echo "  - pre-commit: Runs content validation before each commit"
echo ""
echo "To bypass hooks temporarily, use: git commit --no-verify"
echo ""
