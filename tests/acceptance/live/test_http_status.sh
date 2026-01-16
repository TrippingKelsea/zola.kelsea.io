#!/bin/bash
# Test: Verify HTTP status codes for critical URLs
# Checks that all critical pages return HTTP 200

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "HTTP Status Test"

ERRORS=0

test_section "Checking site availability"

# First check if site is reachable at all
if ! curl -s --max-time 10 "${SITE_URL}" > /dev/null 2>&1; then
    echo -e "  ${FAIL}✗${RESET} Site unreachable: ${SITE_URL}"
    echo -e "  ${DIM}Check that deployment completed and DNS is configured${RESET}"
    exit 1
fi

echo -e "  ${PASS}✓${RESET} Site is reachable"

test_section "Checking critical URLs"

# Load critical URLs from fixture file
FIXTURE_FILE="${TESTS_DIR}/fixtures/critical_urls.txt"

if [[ -f "$FIXTURE_FILE" ]]; then
    while IFS= read -r url; do
        # Skip comments and empty lines
        [[ -z "$url" ]] && continue
        [[ "$url" =~ ^# ]] && continue

        full_url="${SITE_URL}${url}"

        # Get HTTP status code
        status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "${HTTP_TIMEOUT:-10}" "$full_url" 2>/dev/null || echo "000")

        if [[ "$status" == "200" ]]; then
            echo -e "  ${PASS}✓${RESET} ${url} (HTTP ${status})"
        elif [[ "$status" == "301" ]] || [[ "$status" == "302" ]]; then
            # Redirects are acceptable but note them
            echo -e "  ${WARN}⚠${RESET} ${url} (HTTP ${status} redirect)"
        elif [[ "$status" == "000" ]]; then
            echo -e "  ${FAIL}✗${RESET} ${url} (Connection failed)"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "  ${FAIL}✗${RESET} ${url} (HTTP ${status})"
            ERRORS=$((ERRORS + 1))
        fi
    done < "$FIXTURE_FILE"
else
    # Use built-in critical URLs
    for url in "${CRITICAL_URLS[@]}"; do
        full_url="${SITE_URL}${url}"
        status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "${HTTP_TIMEOUT:-10}" "$full_url" 2>/dev/null || echo "000")

        if [[ "$status" == "200" ]]; then
            echo -e "  ${PASS}✓${RESET} ${url} (HTTP ${status})"
        else
            echo -e "  ${FAIL}✗${RESET} ${url} (HTTP ${status})"
            ERRORS=$((ERRORS + 1))
        fi
    done
fi

test_section "Checking static assets"

for asset in "${REQUIRED_ASSETS[@]}"; do
    full_url="${SITE_URL}/${asset}"
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "${HTTP_TIMEOUT:-10}" "$full_url" 2>/dev/null || echo "000")

    if [[ "$status" == "200" ]]; then
        echo -e "  ${PASS}✓${RESET} ${asset} (HTTP ${status})"
    else
        echo -e "  ${FAIL}✗${RESET} ${asset} (HTTP ${status})"
        ERRORS=$((ERRORS + 1))
    fi
done

test_section "Checking HTTPS redirect"

# Test that HTTP redirects to HTTPS
http_url="${SITE_URL/https:/http:}"
redirect_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -L "$http_url" 2>/dev/null || echo "000")
final_url=$(curl -s -o /dev/null -w "%{url_effective}" --max-time 10 -L "$http_url" 2>/dev/null || echo "")

if [[ "$final_url" =~ ^https:// ]]; then
    echo -e "  ${PASS}✓${RESET} HTTP correctly redirects to HTTPS"
else
    echo -e "  ${WARN}⚠${RESET} HTTP may not redirect to HTTPS"
fi

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${PASS}HTTP status test passed${RESET}"
    exit 0
else
    echo -e "${FAIL}HTTP status test failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
