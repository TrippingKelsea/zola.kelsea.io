#!/bin/bash
# Test: Verify page load performance
# Checks that p95 response time is under threshold (15ms)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "Performance Test"

ERRORS=0
WARNINGS=0

# Number of requests per URL for sampling
SAMPLE_SIZE=10

test_section "Measuring response times"

# URLs to test
test_urls=(
    "/"
    "/blog/"
    "/about/"
    "/terminal.css"
    "/terminal.js"
)

declare -A url_times
all_times=()

for url in "${test_urls[@]}"; do
    full_url="${SITE_URL}${url}"
    times=()

    echo -e "  ${INFO}→${RESET} Testing ${url}"

    # Collect samples
    for ((i=1; i<=SAMPLE_SIZE; i++)); do
        # Measure time in milliseconds
        time_ms=$(curl -s -o /dev/null -w "%{time_total}" --max-time 30 "$full_url" 2>/dev/null | awk '{printf "%.0f", $1 * 1000}')

        if [[ -n "$time_ms" ]] && [[ "$time_ms" =~ ^[0-9]+$ ]]; then
            times+=("$time_ms")
            all_times+=("$time_ms")
        fi
    done

    if [[ ${#times[@]} -gt 0 ]]; then
        # Calculate statistics
        sorted_times=($(printf '%s\n' "${times[@]}" | sort -n))
        min=${sorted_times[0]}
        max=${sorted_times[-1]}

        # Calculate p95 (95th percentile)
        p95_index=$(( (${#sorted_times[@]} * 95 + 99) / 100 - 1 ))
        [[ $p95_index -lt 0 ]] && p95_index=0
        p95=${sorted_times[$p95_index]}

        # Calculate average
        sum=0
        for t in "${times[@]}"; do
            ((sum += t))
        done
        avg=$((sum / ${#times[@]}))

        url_times["$url"]="$p95"

        # Report results
        if [[ $p95 -le ${RESPONSE_TIME_THRESHOLD_MS} ]]; then
            echo -e "    ${PASS}✓${RESET} p95: ${p95}ms (avg: ${avg}ms, min: ${min}ms, max: ${max}ms)"
        else
            echo -e "    ${FAIL}✗${RESET} p95: ${p95}ms exceeds ${RESPONSE_TIME_THRESHOLD_MS}ms threshold"
            echo -e "      ${DIM}(avg: ${avg}ms, min: ${min}ms, max: ${max}ms)${RESET}"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "    ${FAIL}✗${RESET} Failed to measure response time"
        ERRORS=$((ERRORS + 1))
    fi
done

test_section "Overall Statistics"

if [[ ${#all_times[@]} -gt 0 ]]; then
    # Calculate overall p95
    sorted_all=($(printf '%s\n' "${all_times[@]}" | sort -n))
    overall_p95_index=$(( (${#sorted_all[@]} * 95 + 99) / 100 - 1 ))
    [[ $overall_p95_index -lt 0 ]] && overall_p95_index=0
    overall_p95=${sorted_all[$overall_p95_index]}

    # Overall average
    total=0
    for t in "${all_times[@]}"; do
        ((total += t))
    done
    overall_avg=$((total / ${#all_times[@]}))

    echo -e "  ${INFO}→${RESET} Total samples: ${#all_times[@]}"
    echo -e "  ${INFO}→${RESET} Overall average: ${overall_avg}ms"

    if [[ $overall_p95 -le ${RESPONSE_TIME_THRESHOLD_MS} ]]; then
        echo -e "  ${PASS}✓${RESET} Overall p95: ${overall_p95}ms (threshold: ${RESPONSE_TIME_THRESHOLD_MS}ms)"
    else
        echo -e "  ${FAIL}✗${RESET} Overall p95: ${overall_p95}ms exceeds ${RESPONSE_TIME_THRESHOLD_MS}ms"
        # Don't increment errors again, individual URLs already counted
    fi
fi

test_section "Cache Headers Check"

# Check that static assets have proper caching
echo -e "  Checking cache headers for static assets..."

for asset in "terminal.css" "terminal.js"; do
    full_url="${SITE_URL}/${asset}"
    cache_header=$(curl -sI --max-time 10 "$full_url" 2>/dev/null | grep -i "cache-control" | head -1)

    if [[ -n "$cache_header" ]]; then
        if [[ "$cache_header" =~ max-age=([0-9]+) ]]; then
            max_age="${BASH_REMATCH[1]}"
            if [[ $max_age -ge 86400 ]]; then
                echo -e "  ${PASS}✓${RESET} ${asset}: max-age=${max_age} (good caching)"
            else
                echo -e "  ${WARN}⚠${RESET} ${asset}: max-age=${max_age} (short cache)"
                WARNINGS=$((WARNINGS + 1))
            fi
        else
            echo -e "  ${INFO}→${RESET} ${asset}: ${cache_header}"
        fi
    else
        echo -e "  ${WARN}⚠${RESET} ${asset}: No cache-control header"
        WARNINGS=$((WARNINGS + 1))
    fi
done

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${WARN}Performance test passed with ${WARNINGS} warning(s)${RESET}"
    else
        echo -e "${PASS}Performance test passed${RESET}"
    fi
    exit 0
else
    echo -e "${FAIL}Performance test failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
