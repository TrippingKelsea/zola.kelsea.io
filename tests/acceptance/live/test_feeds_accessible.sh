#!/bin/bash
# Test: Verify RSS and Atom feeds are accessible and valid
# Checks that feeds return valid XML with expected content

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "Live Feeds Test"

ERRORS=0

test_section "Checking RSS feed"

RSS_URL="${SITE_URL}/rss.xml"

# Check RSS feed is accessible
rss_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "${HTTP_TIMEOUT:-10}" "$RSS_URL" 2>/dev/null || echo "000")

if [[ "$rss_status" == "200" ]]; then
    echo -e "  ${PASS}✓${RESET} RSS feed accessible (HTTP ${rss_status})"

    # Download and validate
    rss_content=$(curl -s --max-time "${HTTP_TIMEOUT:-10}" "$RSS_URL" 2>/dev/null)

    # Check content type
    content_type=$(curl -s -I --max-time 10 "$RSS_URL" 2>/dev/null | grep -i "content-type" | head -1)
    if [[ "$content_type" =~ xml|rss ]]; then
        echo -e "  ${PASS}✓${RESET} Correct content type"
    else
        echo -e "  ${WARN}⚠${RESET} Unexpected content type: ${content_type}"
    fi

    # Check for XML declaration
    if echo "$rss_content" | head -1 | grep -q "<?xml"; then
        echo -e "  ${PASS}✓${RESET} Valid XML declaration"
    else
        echo -e "  ${FAIL}✗${RESET} Missing XML declaration"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for RSS structure
    if echo "$rss_content" | grep -q "<rss\|<channel>"; then
        echo -e "  ${PASS}✓${RESET} Valid RSS structure"
    else
        echo -e "  ${FAIL}✗${RESET} Missing RSS structure"
        ERRORS=$((ERRORS + 1))
    fi

    # Count items
    item_count=$(echo "$rss_content" | grep -c "<item>" || echo "0")
    echo -e "  ${INFO}→${RESET} Contains ${item_count} items"
else
    echo -e "  ${FAIL}✗${RESET} RSS feed not accessible (HTTP ${rss_status})"
    ERRORS=$((ERRORS + 1))
fi

test_section "Checking Atom feed"

ATOM_URL="${SITE_URL}/atom.xml"

atom_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "${HTTP_TIMEOUT:-10}" "$ATOM_URL" 2>/dev/null || echo "000")

if [[ "$atom_status" == "200" ]]; then
    echo -e "  ${PASS}✓${RESET} Atom feed accessible (HTTP ${atom_status})"

    atom_content=$(curl -s --max-time "${HTTP_TIMEOUT:-10}" "$ATOM_URL" 2>/dev/null)

    # Check for XML declaration
    if echo "$atom_content" | head -1 | grep -q "<?xml"; then
        echo -e "  ${PASS}✓${RESET} Valid XML declaration"
    else
        echo -e "  ${FAIL}✗${RESET} Missing XML declaration"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for Atom structure
    if echo "$atom_content" | grep -q "<feed\|<entry>"; then
        echo -e "  ${PASS}✓${RESET} Valid Atom structure"
    else
        echo -e "  ${FAIL}✗${RESET} Missing Atom structure"
        ERRORS=$((ERRORS + 1))
    fi

    # Count entries
    entry_count=$(echo "$atom_content" | grep -c "<entry>" || echo "0")
    echo -e "  ${INFO}→${RESET} Contains ${entry_count} entries"
else
    echo -e "  ${FAIL}✗${RESET} Atom feed not accessible (HTTP ${atom_status})"
    ERRORS=$((ERRORS + 1))
fi

test_section "Checking section feeds"

# Check blog feed if it exists
BLOG_RSS="${SITE_URL}/blog/rss.xml"
blog_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "${HTTP_TIMEOUT:-10}" "$BLOG_RSS" 2>/dev/null || echo "000")

if [[ "$blog_status" == "200" ]]; then
    echo -e "  ${PASS}✓${RESET} Blog RSS feed accessible"
elif [[ "$blog_status" == "404" ]]; then
    echo -e "  ${INFO}→${RESET} Blog RSS feed not found (may not be configured)"
else
    echo -e "  ${WARN}⚠${RESET} Blog RSS feed returned HTTP ${blog_status}"
fi

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${PASS}Live feeds test passed${RESET}"
    exit 0
else
    echo -e "${FAIL}Live feeds test failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
