#!/bin/bash
# Test: Validate RSS and Atom feed XML
# Checks that generated feeds are valid XML

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "Feed Validity Test"

ERRORS=0

test_section "Checking prerequisites"

# Check for xmllint
if ! require_command "xmllint"; then
    echo -e "${WARN}xmllint not found, using basic XML validation${RESET}"
    USE_XMLLINT=false
else
    echo -e "  ${PASS}✓${RESET} xmllint available"
    USE_XMLLINT=true
fi

test_section "Validating feeds"

# Check if public directory exists
if [[ ! -d "${PUBLIC_DIR}" ]]; then
    echo -e "  ${WARN}⚠${RESET} public/ directory not found - run build first"
    echo -e "  ${DIM}Skipping feed validation${RESET}"
    exit 0
fi

# Validate RSS feed
RSS_FEED="${PUBLIC_DIR}/rss.xml"
if [[ -f "$RSS_FEED" ]]; then
    if [[ "$USE_XMLLINT" == true ]]; then
        if xmllint --noout "$RSS_FEED" 2>/dev/null; then
            echo -e "  ${PASS}✓${RESET} rss.xml is valid XML"

            # Check for required RSS elements
            if grep -q "<channel>" "$RSS_FEED" && grep -q "<item>" "$RSS_FEED"; then
                echo -e "  ${PASS}✓${RESET} rss.xml has required RSS structure"
            else
                echo -e "  ${FAIL}✗${RESET} rss.xml missing RSS structure"
                ERRORS=$((ERRORS + 1))
            fi
        else
            echo -e "  ${FAIL}✗${RESET} rss.xml is not valid XML"
            ERRORS=$((ERRORS + 1))
        fi
    else
        # Basic validation without xmllint
        if head -1 "$RSS_FEED" | grep -q "<?xml"; then
            echo -e "  ${PASS}✓${RESET} rss.xml has XML declaration"
        else
            echo -e "  ${FAIL}✗${RESET} rss.xml missing XML declaration"
            ERRORS=$((ERRORS + 1))
        fi
    fi

    # Check feed is not empty
    item_count=$(grep -c "<item>" "$RSS_FEED" 2>/dev/null || echo "0")
    echo -e "  ${INFO}→${RESET} RSS feed contains ${item_count} items"
else
    echo -e "  ${WARN}⚠${RESET} rss.xml not found"
fi

# Validate Atom feed
ATOM_FEED="${PUBLIC_DIR}/atom.xml"
if [[ -f "$ATOM_FEED" ]]; then
    if [[ "$USE_XMLLINT" == true ]]; then
        if xmllint --noout "$ATOM_FEED" 2>/dev/null; then
            echo -e "  ${PASS}✓${RESET} atom.xml is valid XML"

            # Check for required Atom elements
            if grep -q "<feed" "$ATOM_FEED" && grep -q "<entry" "$ATOM_FEED"; then
                echo -e "  ${PASS}✓${RESET} atom.xml has required Atom structure"
            else
                echo -e "  ${FAIL}✗${RESET} atom.xml missing Atom structure"
                ERRORS=$((ERRORS + 1))
            fi
        else
            echo -e "  ${FAIL}✗${RESET} atom.xml is not valid XML"
            ERRORS=$((ERRORS + 1))
        fi
    else
        if head -1 "$ATOM_FEED" | grep -q "<?xml"; then
            echo -e "  ${PASS}✓${RESET} atom.xml has XML declaration"
        else
            echo -e "  ${FAIL}✗${RESET} atom.xml missing XML declaration"
            ERRORS=$((ERRORS + 1))
        fi
    fi

    entry_count=$(grep -c "<entry" "$ATOM_FEED" 2>/dev/null || echo "0")
    echo -e "  ${INFO}→${RESET} Atom feed contains ${entry_count} entries"
else
    echo -e "  ${WARN}⚠${RESET} atom.xml not found"
fi

# Check for section-specific feeds (blog, books)
test_section "Checking section feeds"

for section in blog books; do
    section_rss="${PUBLIC_DIR}/${section}/rss.xml"
    section_atom="${PUBLIC_DIR}/${section}/atom.xml"

    if [[ -f "$section_rss" ]]; then
        if [[ "$USE_XMLLINT" == true ]] && xmllint --noout "$section_rss" 2>/dev/null; then
            echo -e "  ${PASS}✓${RESET} ${section}/rss.xml is valid"
        elif [[ "$USE_XMLLINT" != true ]]; then
            echo -e "  ${PASS}✓${RESET} ${section}/rss.xml exists"
        else
            echo -e "  ${FAIL}✗${RESET} ${section}/rss.xml is invalid"
            ERRORS=$((ERRORS + 1))
        fi
    fi

    if [[ -f "$section_atom" ]]; then
        if [[ "$USE_XMLLINT" == true ]] && xmllint --noout "$section_atom" 2>/dev/null; then
            echo -e "  ${PASS}✓${RESET} ${section}/atom.xml is valid"
        elif [[ "$USE_XMLLINT" != true ]]; then
            echo -e "  ${PASS}✓${RESET} ${section}/atom.xml exists"
        else
            echo -e "  ${FAIL}✗${RESET} ${section}/atom.xml is invalid"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${PASS}Feed validity test passed${RESET}"
    exit 0
else
    echo -e "${FAIL}Feed validity test failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
