#!/bin/bash
# Test: Validate HTML structure of generated pages
# Performs basic HTML validation checks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "HTML Validity Test"

ERRORS=0
WARNINGS=0

test_section "Checking build output"

if [[ ! -d "${PUBLIC_DIR}" ]]; then
    echo -e "  ${FAIL}✗${RESET} public/ directory not found - run build first"
    exit 1
fi

# Get HTML files
html_files=$(get_html_files)
html_count=$(echo "$html_files" | grep -c . || echo "0")

echo -e "  ${INFO}→${RESET} Found ${html_count} HTML files"

test_section "Basic HTML structure validation"

# Check a sample of HTML files for common issues
sample_size=10
checked=0

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    checked=$((checked + 1))
    [[ $checked -gt $sample_size ]] && break

    relative_path="${file#${PUBLIC_DIR}/}"
    file_issues=()

    # Read file content
    content=$(cat "$file")

    # Skip Zola redirect pages (minimal HTML by design)
    if echo "$content" | grep -q '<title>Redirect</title>'; then
        echo -e "  ${DIM}→${RESET} ${relative_path} (redirect page, skipped)"
        continue
    fi

    # Check for DOCTYPE
    if ! echo "$content" | head -1 | grep -qi "<!DOCTYPE html>"; then
        file_issues+=("Missing DOCTYPE")
    fi

    # Check for html lang attribute
    if ! echo "$content" | grep -q '<html[^>]*lang='; then
        file_issues+=("Missing lang attribute on <html>")
    fi

    # Check for meta charset
    if ! echo "$content" | grep -qi 'charset.*utf-8\|utf-8.*charset'; then
        file_issues+=("Missing charset declaration")
    fi

    # Check for viewport meta tag
    if ! echo "$content" | grep -q 'name="viewport"'; then
        file_issues+=("Missing viewport meta tag")
    fi

    # Check for title tag (may span multiple lines)
    if ! echo "$content" | tr '\n' ' ' | grep -q '<title>.*</title>'; then
        file_issues+=("Missing or empty title tag")
    fi

    # Check for unclosed tags (basic check)
    # Count opening and closing main structural tags
    for tag in "div" "section" "article" "main" "header" "footer" "nav"; do
        open_count=$(echo "$content" | grep -o "<${tag}[^>]*>" | wc -l)
        close_count=$(echo "$content" | grep -o "</${tag}>" | wc -l)
        # Allow for self-closing or void elements by checking if significantly different
        if [[ $((open_count - close_count)) -gt 2 ]] || [[ $((close_count - open_count)) -gt 2 ]]; then
            file_issues+=("Possibly unclosed <${tag}> tags (${open_count} open, ${close_count} close)")
        fi
    done

    # Check for broken image tags
    if echo "$content" | grep -qE '<img[^>]*src=""'; then
        file_issues+=("Empty img src attribute")
    fi

    # Check for empty href
    if echo "$content" | grep -qE '<a[^>]*href=""[^>]*>'; then
        file_issues+=("Empty anchor href")
    fi

    # Report results
    if [[ ${#file_issues[@]} -eq 0 ]]; then
        echo -e "  ${PASS}✓${RESET} ${relative_path}"
    else
        echo -e "  ${FAIL}✗${RESET} ${relative_path}"
        for issue in "${file_issues[@]}"; do
            echo -e "    ${DIM}${issue}${RESET}"
            ERRORS=$((ERRORS + 1))
        done
    fi

done <<< "$html_files"

if [[ $html_count -gt $sample_size ]]; then
    echo -e "  ${DIM}... and $((html_count - sample_size)) more files${RESET}"
fi

test_section "Accessibility checks"

# Check key pages for accessibility elements
key_pages=("index.html" "blog/index.html" "about/index.html" "404.html")

for page in "${key_pages[@]}"; do
    page_path="${PUBLIC_DIR}/${page}"
    [[ ! -f "$page_path" ]] && continue

    content=$(cat "$page_path")
    page_warnings=()

    # Check for skip link
    if ! echo "$content" | grep -q 'skip.*main\|skip.*content'; then
        : # Skip links are optional, no warning needed
    fi

    # Check for main landmark
    if ! echo "$content" | grep -q '<main'; then
        page_warnings+=("Missing <main> landmark")
    fi

    # Check for nav landmark
    if ! echo "$content" | grep -q '<nav'; then
        page_warnings+=("Missing <nav> landmark")
    fi

    # Check for aria-label on interactive elements
    if echo "$content" | grep -q 'role="button"' && ! echo "$content" | grep -q 'aria-label'; then
        page_warnings+=("Buttons may be missing aria-label")
    fi

    if [[ ${#page_warnings[@]} -gt 0 ]]; then
        echo -e "  ${WARN}⚠${RESET} ${page}"
        for warning in "${page_warnings[@]}"; do
            echo -e "    ${DIM}${warning}${RESET}"
            WARNINGS=$((WARNINGS + 1))
        done
    else
        echo -e "  ${PASS}✓${RESET} ${page} accessibility OK"
    fi
done

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${WARN}HTML validity test passed with ${WARNINGS} warning(s)${RESET}"
    else
        echo -e "${PASS}HTML validity test passed${RESET}"
    fi
    exit 0
else
    echo -e "${FAIL}HTML validity test failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
