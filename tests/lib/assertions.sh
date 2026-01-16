#!/bin/bash
# Test assertion functions

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Assert that a command succeeds (exit code 0)
# Usage: assert_success "description" command args...
assert_success() {
    local description="$1"
    shift

    if "$@" > /dev/null 2>&1; then
        echo -e "  ${PASS}✓${RESET} ${description}"
        return 0
    else
        echo -e "  ${FAIL}✗${RESET} ${description}"
        echo -e "    ${DIM}Command: $*${RESET}"
        return 1
    fi
}

# Assert that a command fails (non-zero exit code)
# Usage: assert_failure "description" command args...
assert_failure() {
    local description="$1"
    shift

    if ! "$@" > /dev/null 2>&1; then
        echo -e "  ${PASS}✓${RESET} ${description}"
        return 0
    else
        echo -e "  ${FAIL}✗${RESET} ${description}"
        echo -e "    ${DIM}Expected failure but command succeeded${RESET}"
        return 1
    fi
}

# Assert that a file exists
# Usage: assert_file_exists "description" filepath
assert_file_exists() {
    local description="$1"
    local filepath="$2"

    if [[ -f "$filepath" ]]; then
        echo -e "  ${PASS}✓${RESET} ${description}"
        return 0
    else
        echo -e "  ${FAIL}✗${RESET} ${description}"
        echo -e "    ${DIM}File not found: ${filepath}${RESET}"
        return 1
    fi
}

# Assert that a file is not empty
# Usage: assert_file_not_empty "description" filepath
assert_file_not_empty() {
    local description="$1"
    local filepath="$2"

    if [[ -s "$filepath" ]]; then
        echo -e "  ${PASS}✓${RESET} ${description}"
        return 0
    else
        echo -e "  ${FAIL}✗${RESET} ${description}"
        echo -e "    ${DIM}File is empty or missing: ${filepath}${RESET}"
        return 1
    fi
}

# Assert that a directory exists
# Usage: assert_dir_exists "description" dirpath
assert_dir_exists() {
    local description="$1"
    local dirpath="$2"

    if [[ -d "$dirpath" ]]; then
        echo -e "  ${PASS}✓${RESET} ${description}"
        return 0
    else
        echo -e "  ${FAIL}✗${RESET} ${description}"
        echo -e "    ${DIM}Directory not found: ${dirpath}${RESET}"
        return 1
    fi
}

# Assert that a string contains a substring
# Usage: assert_contains "description" "haystack" "needle"
assert_contains() {
    local description="$1"
    local haystack="$2"
    local needle="$3"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "  ${PASS}✓${RESET} ${description}"
        return 0
    else
        echo -e "  ${FAIL}✗${RESET} ${description}"
        echo -e "    ${DIM}Expected to find: ${needle}${RESET}"
        return 1
    fi
}

# Assert that a string matches a regex
# Usage: assert_matches "description" "string" "regex"
assert_matches() {
    local description="$1"
    local string="$2"
    local regex="$3"

    if [[ "$string" =~ $regex ]]; then
        echo -e "  ${PASS}✓${RESET} ${description}"
        return 0
    else
        echo -e "  ${FAIL}✗${RESET} ${description}"
        echo -e "    ${DIM}String did not match regex: ${regex}${RESET}"
        return 1
    fi
}

# Assert that two values are equal
# Usage: assert_equals "description" "expected" "actual"
assert_equals() {
    local description="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${PASS}✓${RESET} ${description}"
        return 0
    else
        echo -e "  ${FAIL}✗${RESET} ${description}"
        echo -e "    ${DIM}Expected: ${expected}${RESET}"
        echo -e "    ${DIM}Actual:   ${actual}${RESET}"
        return 1
    fi
}

# Assert that a numeric value is less than or equal to threshold
# Usage: assert_lte "description" value threshold
assert_lte() {
    local description="$1"
    local value="$2"
    local threshold="$3"

    if (( $(echo "$value <= $threshold" | bc -l) )); then
        echo -e "  ${PASS}✓${RESET} ${description} (${value} <= ${threshold})"
        return 0
    else
        echo -e "  ${FAIL}✗${RESET} ${description}"
        echo -e "    ${DIM}Value ${value} exceeds threshold ${threshold}${RESET}"
        return 1
    fi
}

# Assert HTTP status code
# Usage: assert_http_status "description" url expected_status
assert_http_status() {
    local description="$1"
    local url="$2"
    local expected="$3"

    local actual
    actual=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null)

    if [[ "$actual" == "$expected" ]]; then
        echo -e "  ${PASS}✓${RESET} ${description} (HTTP ${actual})"
        return 0
    else
        echo -e "  ${FAIL}✗${RESET} ${description}"
        echo -e "    ${DIM}Expected HTTP ${expected}, got HTTP ${actual}${RESET}"
        return 1
    fi
}
