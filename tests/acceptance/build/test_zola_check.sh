#!/bin/bash
# Test: Run zola check for comprehensive validation
# Validates internal links, orphan pages, and other issues

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "Zola Check Test"

ERRORS=0
WARNINGS=0

test_section "Running zola check"

if ! require_command "zola"; then
    echo -e "${FAIL}Zola is required${RESET}"
    exit 1
fi

cd "${PROJECT_ROOT}"

# Run zola check and capture both stdout and stderr
check_output=$(zola check 2>&1) || {
    exit_code=$?

    # zola check returns non-zero for warnings too
    # Parse output to distinguish errors from warnings

    while IFS= read -r line; do
        if [[ "$line" =~ ^Error|error: ]]; then
            echo -e "  ${FAIL}✗${RESET} ${line}"
            ERRORS=$((ERRORS + 1))
        elif [[ "$line" =~ ^Warning|warning: ]]; then
            echo -e "  ${WARN}⚠${RESET} ${line}"
            WARNINGS=$((WARNINGS + 1))
        elif [[ "$line" =~ "-> " ]]; then
            # Info lines from zola
            echo -e "  ${INFO}${line}${RESET}"
        fi
    done <<< "$check_output"

    # If only warnings, that's okay
    if [[ $ERRORS -eq 0 ]]; then
        echo -e "  ${PASS}✓${RESET} No errors (${WARNINGS} warnings)"
    fi
}

if [[ $ERRORS -eq 0 ]] && [[ -z "$check_output" || ! "$check_output" =~ [Ee]rror ]]; then
    echo -e "  ${PASS}✓${RESET} All checks passed"
fi

# Additional checks
test_section "Checking for common issues"

# Check for draft content that might be accidentally published
draft_count=$(grep -rl "^draft\s*=\s*true" "${CONTENT_DIR}" 2>/dev/null | wc -l || echo "0")
if [[ "$draft_count" -gt 0 ]]; then
    echo -e "  ${INFO}→${RESET} ${draft_count} draft file(s) (will be excluded from build)"
fi

# Check for future-dated content
future_count=0
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        date_line=$(grep -E "^date\s*=" "$file" 2>/dev/null | head -1 || true)
        if [[ -n "$date_line" ]]; then
            # Extract date value
            if [[ "$date_line" =~ =\s*\"?([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
                file_date="${BASH_REMATCH[1]}"
                today=$(date +%Y-%m-%d)
                if [[ "$file_date" > "$today" ]]; then
                    ((future_count++))
                fi
            fi
        fi
    fi
done < <(get_content_files)

if [[ "$future_count" -gt 0 ]]; then
    echo -e "  ${INFO}→${RESET} ${future_count} future-dated file(s)"
fi

echo -e "  ${PASS}✓${RESET} Additional checks complete"

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${WARN}Zola check passed with ${WARNINGS} warning(s)${RESET}"
    else
        echo -e "${PASS}Zola check passed${RESET}"
    fi
    exit 0
else
    echo -e "${FAIL}Zola check failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
