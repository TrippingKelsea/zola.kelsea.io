#!/bin/bash
# Common test utilities

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assertions.sh"

# Global counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TEST_FAILURES=0

# Project paths
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTENT_DIR="${PROJECT_ROOT}/content"
TEMPLATES_DIR="${PROJECT_ROOT}/templates"
STATIC_DIR="${PROJECT_ROOT}/static"
PUBLIC_DIR="${PROJECT_ROOT}/public"
TESTS_DIR="${PROJECT_ROOT}/tests"

# Site configuration
SITE_URL="${SITE_URL:-https://www.kelsea.io}"

# Print test header
# Usage: test_header "Test Suite Name"
test_header() {
    local name="$1"
    echo ""
    echo -e "${HEADER}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${HEADER}  ${name}${RESET}"
    echo -e "${HEADER}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# Print section header within a test
# Usage: test_section "Section Name"
test_section() {
    local name="$1"
    echo ""
    echo -e "${INFO}▸ ${name}${RESET}"
}

# Run a single test file
# Usage: run_test "path/to/test.sh"
run_test() {
    local test_file="${TESTS_DIR}/$1"
    local test_name="$(basename "$test_file" .sh)"

    if [[ ! -f "$test_file" ]]; then
        echo -e "${WARN}⚠${RESET} Test file not found: $test_file"
        return 1
    fi

    TESTS_RUN=$((TESTS_RUN + 1))

    # Run the test and capture exit code
    if bash "$test_file"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TEST_FAILURES=$((TEST_FAILURES + 1))
        return 1
    fi
}

# Print summary of test results
print_summary() {
    echo ""
    echo -e "${HEADER}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${HEADER}  TEST SUMMARY${RESET}"
    echo -e "${HEADER}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  Tests run:    ${TESTS_RUN}"
    echo -e "  ${PASS}Passed:      ${TESTS_PASSED}${RESET}"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "  ${FAIL}Failed:      ${TESTS_FAILED}${RESET}"
    else
        echo -e "  Failed:      0"
    fi

    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "  ${PASS}${BOLD}All tests passed!${RESET}"
    else
        echo -e "  ${FAIL}${BOLD}Some tests failed.${RESET}"
    fi

    echo ""
}

# Check if a command exists
# Usage: require_command "command_name"
require_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${FAIL}✗${RESET} Required command not found: ${cmd}"
        return 1
    fi
    return 0
}

# Get list of all markdown files in content directory
get_content_files() {
    find "$CONTENT_DIR" -name "*.md" -type f 2>/dev/null
}

# Get list of all HTML files in public directory
get_html_files() {
    find "$PUBLIC_DIR" -name "*.html" -type f 2>/dev/null
}

# Extract frontmatter from a markdown file
# Usage: get_frontmatter "file.md"
get_frontmatter() {
    local file="$1"
    # Handle both TOML (+++) and YAML (---) frontmatter
    if head -1 "$file" | grep -q "^+++"; then
        sed -n '/^+++$/,/^+++$/p' "$file" | sed '1d;$d'
    elif head -1 "$file" | grep -q "^---"; then
        sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d'
    fi
}

# Check if file has required frontmatter field
# Usage: has_frontmatter_field "file.md" "field_name"
has_frontmatter_field() {
    local file="$1"
    local field="$2"
    local frontmatter
    frontmatter=$(get_frontmatter "$file")

    # Check for TOML style (field = value) or YAML style (field: value)
    if echo "$frontmatter" | grep -qE "^${field}\s*=|^${field}\s*:"; then
        return 0
    fi
    return 1
}

# Random sample from array
# Usage: random_sample array_name count
random_sample() {
    local -n arr=$1
    local count=$2
    local total=${#arr[@]}

    if [[ $count -ge $total ]]; then
        printf '%s\n' "${arr[@]}"
        return
    fi

    printf '%s\n' "${arr[@]}" | shuf -n "$count"
}

# Measure response time for a URL (in milliseconds)
# Usage: measure_response_time "url"
measure_response_time() {
    local url="$1"
    curl -s -o /dev/null -w "%{time_total}" --max-time 30 "$url" 2>/dev/null | awk '{printf "%.0f", $1 * 1000}'
}

# Create a timestamp for logging
timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Log to results file
# Usage: log_result "test_name" "status" "message"
log_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    local results_file="${TESTS_DIR}/results/$(date +%Y%m%d_%H%M%S).log"

    mkdir -p "$(dirname "$results_file")"
    echo "[$(timestamp)] [$status] $test_name: $message" >> "$results_file"
}
