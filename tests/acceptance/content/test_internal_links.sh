#!/bin/bash
# Test: Validate internal links in content files
# Uses zola check for comprehensive link validation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "Internal Link Validation"

ERRORS=0

test_section "Running zola check"

# Check if zola is available
if ! require_command "zola"; then
    echo -e "${FAIL}Zola is required for link checking${RESET}"
    exit 1
fi

# Run zola check and capture output
cd "${PROJECT_ROOT}"

# zola check returns non-zero if there are issues
if output=$(zola check 2>&1); then
    echo -e "  ${PASS}✓${RESET} All internal links valid"
else
    # Parse zola check output for errors
    echo -e "  ${FAIL}✗${RESET} Link validation issues found:"
    echo ""

    # zola check output includes warnings and errors
    # Filter for actual link errors
    while IFS= read -r line; do
        if [[ "$line" =~ "Error" ]] || [[ "$line" =~ "error" ]]; then
            echo -e "    ${FAIL}${line}${RESET}"
            ERRORS=$((ERRORS + 1))
        elif [[ "$line" =~ "Warning" ]] || [[ "$line" =~ "warning" ]]; then
            echo -e "    ${WARN}${line}${RESET}"
        elif [[ -n "$line" ]]; then
            echo -e "    ${DIM}${line}${RESET}"
        fi
    done <<< "$output"
fi

# Additional check: Look for potential broken internal links in markdown
test_section "Checking markdown internal links"

content_files=$(get_content_files)

if [[ -n "$content_files" ]]; then
    while IFS= read -r file; do
        relative_path="${file#${CONTENT_DIR}/}"

        # Find internal links that start with / or @/
        internal_links=$(grep -oE '\[([^\]]+)\]\((@/[^)]+|/[^)]+)\)' "$file" 2>/dev/null || true)

        if [[ -z "$internal_links" ]]; then
            continue
        fi

        while IFS= read -r link; do
            # Extract path from [text](path) using sed (bash regex has issues with brackets)
            link_path=$(echo "$link" | sed -E 's/.*\]\(([^)]+)\).*/\1/')

            # Skip anchor-only links
            if [[ "$link_path" =~ ^# ]]; then
                continue
            fi

            # For @/ paths (Zola internal links), just verify the content file exists
            if [[ "$link_path" =~ ^@/ ]]; then
                # Convert @/path/to/file.md to content/path/to/file.md
                content_path="${CONTENT_DIR}/${link_path#@/}"

                # Handle section links (without .md)
                if [[ ! -f "$content_path" ]] && [[ ! -f "${content_path}.md" ]] && [[ ! -d "$content_path" ]]; then
                    # Check if it's a section (_index.md)
                    if [[ ! -f "${content_path}/_index.md" ]]; then
                        echo -e "  ${WARN}⚠${RESET} ${relative_path}: Potentially broken @/ link"
                        echo -e "    ${DIM}Link: ${link_path}${RESET}"
                    fi
                fi
            fi
        done <<< "$internal_links"

    done <<< "$content_files"
fi

echo -e "  ${PASS}✓${RESET} Markdown internal link check complete"

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${PASS}All internal link validation passed${RESET}"
    exit 0
else
    echo -e "${FAIL}Internal link validation failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
