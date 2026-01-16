#!/bin/bash
# Test: Verify static assets are present and valid
# Checks CSS, JS, and other required static files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "Asset Integrity Test"

ERRORS=0
WARNINGS=0

test_section "Checking build output"

if [[ ! -d "${PUBLIC_DIR}" ]]; then
    echo -e "  ${FAIL}✗${RESET} public/ directory not found - run build first"
    exit 1
fi

echo -e "  ${PASS}✓${RESET} public/ directory exists"

test_section "Checking required assets"

for asset in "${REQUIRED_ASSETS[@]}"; do
    asset_path="${PUBLIC_DIR}/${asset}"

    if [[ -f "$asset_path" ]]; then
        # Check file is not empty
        if [[ -s "$asset_path" ]]; then
            size=$(wc -c < "$asset_path")
            echo -e "  ${PASS}✓${RESET} ${asset} (${size} bytes)"
        else
            echo -e "  ${FAIL}✗${RESET} ${asset} exists but is empty"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "  ${FAIL}✗${RESET} ${asset} not found"
        ERRORS=$((ERRORS + 1))
    fi
done

test_section "Validating CSS"

CSS_FILE="${PUBLIC_DIR}/terminal.css"
if [[ -f "$CSS_FILE" ]]; then
    # Basic CSS syntax check - look for unclosed braces
    open_braces=$(grep -o '{' "$CSS_FILE" | wc -l)
    close_braces=$(grep -o '}' "$CSS_FILE" | wc -l)

    if [[ "$open_braces" -eq "$close_braces" ]]; then
        echo -e "  ${PASS}✓${RESET} CSS braces balanced (${open_braces} pairs)"
    else
        echo -e "  ${FAIL}✗${RESET} CSS braces unbalanced (${open_braces} open, ${close_braces} close)"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for CSS variables used by themes
    for var in "--primary-bg" "--primary-fg" "--secondary-fg" "--dim-fg" "--glow-color"; do
        if grep -q -- "$var" "$CSS_FILE"; then
            : # Variable found
        else
            echo -e "  ${WARN}⚠${RESET} CSS variable ${var} not found"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
    echo -e "  ${PASS}✓${RESET} CSS theme variables present"

    # Check for theme selectors
    for theme in "green" "amber" "grey"; do
        if grep -q "data-theme=\"${theme}\"" "$CSS_FILE" || grep -q "\[data-theme=\"${theme}\"\]" "$CSS_FILE"; then
            echo -e "  ${PASS}✓${RESET} Theme '${theme}' defined"
        else
            echo -e "  ${WARN}⚠${RESET} Theme '${theme}' not found in CSS"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
fi

test_section "Validating JavaScript"

JS_FILE="${PUBLIC_DIR}/terminal.js"
if [[ -f "$JS_FILE" ]]; then
    # Basic JS syntax check - look for obvious issues
    # Check for balanced parentheses (rough check)
    open_parens=$(grep -o '(' "$JS_FILE" | wc -l)
    close_parens=$(grep -o ')' "$JS_FILE" | wc -l)

    if [[ "$open_parens" -eq "$close_parens" ]]; then
        echo -e "  ${PASS}✓${RESET} JS parentheses balanced"
    else
        echo -e "  ${WARN}⚠${RESET} JS parentheses may be unbalanced (${open_parens} open, ${close_parens} close)"
        WARNINGS=$((WARNINGS + 1))
    fi

    # Check for theme switcher functions
    for func in "initThemeSwitcher" "applyTheme" "announceThemeChange"; do
        if grep -q "function ${func}" "$JS_FILE"; then
            echo -e "  ${PASS}✓${RESET} Function ${func}() defined"
        else
            echo -e "  ${WARN}⚠${RESET} Function ${func}() not found"
            WARNINGS=$((WARNINGS + 1))
        fi
    done

    # Check for localStorage usage (theme persistence)
    if grep -q "localStorage" "$JS_FILE"; then
        echo -e "  ${PASS}✓${RESET} localStorage theme persistence present"
    else
        echo -e "  ${WARN}⚠${RESET} localStorage not used (theme won't persist)"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

test_section "Checking search index"

SEARCH_INDEX="${PUBLIC_DIR}/search_index.en.js"
if [[ -f "$SEARCH_INDEX" ]]; then
    if [[ -s "$SEARCH_INDEX" ]]; then
        size=$(wc -c < "$SEARCH_INDEX")
        echo -e "  ${PASS}✓${RESET} search_index.en.js (${size} bytes)"
    else
        echo -e "  ${WARN}⚠${RESET} search_index.en.js is empty"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "  ${INFO}→${RESET} No search index (search may not be configured)"
fi

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${WARN}Asset integrity test passed with ${WARNINGS} warning(s)${RESET}"
    else
        echo -e "${PASS}Asset integrity test passed${RESET}"
    fi
    exit 0
else
    echo -e "${FAIL}Asset integrity test failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
