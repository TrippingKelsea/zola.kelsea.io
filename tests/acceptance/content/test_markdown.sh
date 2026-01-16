#!/bin/bash
# Test: Validate markdown syntax in content files
# Checks for common markdown issues

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "Markdown Syntax Validation"

ERRORS=0
WARNINGS=0

test_section "Checking markdown files"

content_files=$(get_content_files)

if [[ -z "$content_files" ]]; then
    echo -e "  ${DIM}No content files found${RESET}"
    exit 0
fi

while IFS= read -r file; do
    relative_path="${file#${CONTENT_DIR}/}"
    file_issues=()
    file_warnings=()

    # Read file content (skip frontmatter)
    if head -1 "$file" | grep -q "^+++"; then
        content=$(sed '1,/^+++$/d' "$file" | sed '1,/^+++$/d')
    elif head -1 "$file" | grep -q "^---"; then
        content=$(sed '1,/^---$/d' "$file" | sed '1,/^---$/d')
    else
        content=$(cat "$file")
    fi

    # Check for unclosed code blocks
    code_block_count=$(echo "$content" | grep -c '```' || true)
    if [[ $((code_block_count % 2)) -ne 0 ]]; then
        file_issues+=("Unclosed code block (odd number of \`\`\`)")
    fi

    # Check for broken wikilinks that weren't converted
    if echo "$content" | grep -qE '\[\[[^\]]+\]\]'; then
        file_warnings+=("Contains unconverted wikilinks [[...]]")
    fi

    # Check for empty links [text]()
    if echo "$content" | grep -qE '\[[^\]]+\]\(\s*\)'; then
        file_issues+=("Contains empty link references")
    fi

    # Check for malformed image references ![](
    if echo "$content" | grep -qE '!\[\]\([^)]+\)'; then
        file_warnings+=("Image without alt text")
    fi

    # Check for very long lines (might indicate formatting issues)
    # Skip code blocks for this check
    non_code_content=$(echo "$content" | sed '/```/,/```/d')
    if echo "$non_code_content" | grep -qE '.{500,}'; then
        file_warnings+=("Contains very long lines (>500 chars)")
    fi

    # Check for consecutive blank lines (more than 2)
    # Use awk to count consecutive blank lines instead of grep with literal newlines
    excessive_blanks=$(echo "$content" | awk '/^$/{n++;if(n>3)exit 1}!/^$/{n=0}' && echo "no" || echo "yes")
    if [[ "$excessive_blanks" == "yes" ]]; then
        file_warnings+=("Excessive blank lines")
    fi

    # Check for trailing whitespace (common issue)
    if echo "$content" | grep -qE '[[:space:]]$'; then
        # This is very common and usually not a problem, skip warning
        :
    fi

    # Report results
    if [[ ${#file_issues[@]} -eq 0 ]] && [[ ${#file_warnings[@]} -eq 0 ]]; then
        echo -e "  ${PASS}✓${RESET} ${relative_path}"
    elif [[ ${#file_issues[@]} -eq 0 ]]; then
        echo -e "  ${WARN}⚠${RESET} ${relative_path}"
        for warning in "${file_warnings[@]}"; do
            echo -e "    ${DIM}Warning: ${warning}${RESET}"
            WARNINGS=$((WARNINGS + 1))
        done
    else
        echo -e "  ${FAIL}✗${RESET} ${relative_path}"
        for issue in "${file_issues[@]}"; do
            echo -e "    ${DIM}Error: ${issue}${RESET}"
            ERRORS=$((ERRORS + 1))
        done
        for warning in "${file_warnings[@]}"; do
            echo -e "    ${DIM}Warning: ${warning}${RESET}"
            WARNINGS=$((WARNINGS + 1))
        done
    fi

done <<< "$content_files"

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${WARN}Markdown validation passed with ${WARNINGS} warning(s)${RESET}"
    else
        echo -e "${PASS}All markdown validation passed${RESET}"
    fi
    exit 0
else
    echo -e "${FAIL}Markdown validation failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
