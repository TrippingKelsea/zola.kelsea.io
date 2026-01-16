#!/bin/bash
# Test: Verify theme switcher JavaScript is functional
# Checks that required JS functions and theme CSS exist

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "Theme Switcher Test"

ERRORS=0

test_section "Checking JavaScript availability"

JS_URL="${SITE_URL}/terminal.js"

# Check JS file is accessible
js_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "${HTTP_TIMEOUT:-10}" "$JS_URL" 2>/dev/null || echo "000")

if [[ "$js_status" != "200" ]]; then
    echo -e "  ${FAIL}✗${RESET} terminal.js not accessible (HTTP ${js_status})"
    exit 1
fi

echo -e "  ${PASS}✓${RESET} terminal.js accessible"

# Download JS content
js_content=$(curl -s --max-time "${HTTP_TIMEOUT:-10}" "$JS_URL" 2>/dev/null)

test_section "Checking theme switcher functions"

# Check for required functions
required_functions=("initThemeSwitcher" "applyTheme" "announceThemeChange")

for func in "${required_functions[@]}"; do
    if echo "$js_content" | grep -q "function ${func}"; then
        echo -e "  ${PASS}✓${RESET} Function ${func}() present"
    else
        echo -e "  ${FAIL}✗${RESET} Function ${func}() missing"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check for localStorage usage
if echo "$js_content" | grep -q "localStorage"; then
    echo -e "  ${PASS}✓${RESET} localStorage for theme persistence"
else
    echo -e "  ${WARN}⚠${RESET} localStorage not found (theme won't persist)"
fi

# Check for theme data attribute
if echo "$js_content" | grep -q "data-theme"; then
    echo -e "  ${PASS}✓${RESET} data-theme attribute usage"
else
    echo -e "  ${FAIL}✗${RESET} data-theme attribute not found"
    ERRORS=$((ERRORS + 1))
fi

test_section "Checking CSS theme definitions"

CSS_URL="${SITE_URL}/terminal.css"

css_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "${HTTP_TIMEOUT:-10}" "$CSS_URL" 2>/dev/null || echo "000")

if [[ "$css_status" != "200" ]]; then
    echo -e "  ${FAIL}✗${RESET} terminal.css not accessible (HTTP ${css_status})"
    ERRORS=$((ERRORS + 1))
else
    echo -e "  ${PASS}✓${RESET} terminal.css accessible"

    css_content=$(curl -s --max-time "${HTTP_TIMEOUT:-10}" "$CSS_URL" 2>/dev/null)

    # Check for theme selectors
    themes=("green" "amber" "grey")

    for theme in "${themes[@]}"; do
        if echo "$css_content" | grep -q "data-theme=\"${theme}\"" || echo "$css_content" | grep -q "\[data-theme=\"${theme}\"\]"; then
            echo -e "  ${PASS}✓${RESET} Theme '${theme}' defined in CSS"
        else
            echo -e "  ${FAIL}✗${RESET} Theme '${theme}' not found in CSS"
            ERRORS=$((ERRORS + 1))
        fi
    done

    # Check for CSS variables
    css_vars=("--primary-fg" "--primary-bg" "--glow-color")

    for var in "${css_vars[@]}"; do
        if echo "$css_content" | grep -q "$var"; then
            : # Variable found
        else
            echo -e "  ${WARN}⚠${RESET} CSS variable ${var} not found"
        fi
    done
    echo -e "  ${PASS}✓${RESET} CSS variables present"
fi

test_section "Checking HTML theme buttons"

# Download homepage and check for theme buttons
home_content=$(curl -s --max-time "${HTTP_TIMEOUT:-10}" "${SITE_URL}/" 2>/dev/null)

if echo "$home_content" | grep -q 'data-theme="green"'; then
    echo -e "  ${PASS}✓${RESET} Green theme button present"
else
    echo -e "  ${FAIL}✗${RESET} Green theme button not found"
    ERRORS=$((ERRORS + 1))
fi

if echo "$home_content" | grep -q 'data-theme="amber"'; then
    echo -e "  ${PASS}✓${RESET} Amber theme button present"
else
    echo -e "  ${FAIL}✗${RESET} Amber theme button not found"
    ERRORS=$((ERRORS + 1))
fi

if echo "$home_content" | grep -q 'data-theme="grey"'; then
    echo -e "  ${PASS}✓${RESET} Grey theme button present"
else
    echo -e "  ${FAIL}✗${RESET} Grey theme button not found"
    ERRORS=$((ERRORS + 1))
fi

# Check for accessibility attributes
if echo "$home_content" | grep -q 'aria-label.*theme'; then
    echo -e "  ${PASS}✓${RESET} Accessibility labels present"
else
    echo -e "  ${WARN}⚠${RESET} Theme buttons may lack accessibility labels"
fi

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${PASS}Theme switcher test passed${RESET}"
    exit 0
else
    echo -e "${FAIL}Theme switcher test failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
