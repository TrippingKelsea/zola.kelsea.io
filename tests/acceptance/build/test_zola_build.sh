#!/bin/bash
# Test: Verify zola build completes successfully
# Builds the site and checks for errors

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "Zola Build Test"

ERRORS=0

test_section "Checking prerequisites"

if ! require_command "zola"; then
    echo -e "${FAIL}Zola is required${RESET}"
    exit 1
fi

echo -e "  ${PASS}✓${RESET} Zola found: $(zola --version)"

test_section "Building site"

cd "${PROJECT_ROOT}"

# Clean previous build
if [[ -d "${PUBLIC_DIR}" ]]; then
    rm -rf "${PUBLIC_DIR}"
    echo -e "  ${DIM}Cleaned previous build${RESET}"
fi

# Run zola build with timeout
build_output=$(timeout "${BUILD_TIMEOUT:-120}" zola build 2>&1) || {
    exit_code=$?
    echo -e "  ${FAIL}✗${RESET} Build failed (exit code: ${exit_code})"
    echo -e "${DIM}${build_output}${RESET}"
    exit 1
}

echo -e "  ${PASS}✓${RESET} Build completed successfully"

# Parse build output for statistics
if [[ "$build_output" =~ Creating\ ([0-9]+)\ pages ]]; then
    page_count="${BASH_REMATCH[1]}"
    echo -e "  ${INFO}→${RESET} Generated ${page_count} pages"
fi

if [[ "$build_output" =~ ([0-9]+)\ orphan ]]; then
    orphan_count="${BASH_REMATCH[1]}"
    if [[ "$orphan_count" -gt 0 ]]; then
        echo -e "  ${WARN}⚠${RESET} ${orphan_count} orphan pages"
    fi
fi

if [[ "$build_output" =~ Done\ in\ ([0-9]+)ms ]]; then
    build_time="${BASH_REMATCH[1]}"
    echo -e "  ${INFO}→${RESET} Build time: ${build_time}ms"
fi

test_section "Verifying build output"

# Check that public directory was created
if ! assert_dir_exists "public/ directory created" "${PUBLIC_DIR}"; then
    ERRORS=$((ERRORS + 1))
fi

# Check for index.html
if ! assert_file_exists "index.html generated" "${PUBLIC_DIR}/index.html"; then
    ERRORS=$((ERRORS + 1))
fi

# Check for key directories
for dir in blog about projects; do
    if [[ -d "${PUBLIC_DIR}/${dir}" ]]; then
        echo -e "  ${PASS}✓${RESET} ${dir}/ directory generated"
    else
        echo -e "  ${WARN}⚠${RESET} ${dir}/ directory not found"
    fi
done

# Count generated files
html_count=$(find "${PUBLIC_DIR}" -name "*.html" -type f | wc -l)
echo -e "  ${INFO}→${RESET} Total HTML files: ${html_count}"

# Check build size
build_size=$(du -sh "${PUBLIC_DIR}" 2>/dev/null | cut -f1)
echo -e "  ${INFO}→${RESET} Build size: ${build_size}"

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${PASS}Zola build test passed${RESET}"
    exit 0
else
    echo -e "${FAIL}Zola build test failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
