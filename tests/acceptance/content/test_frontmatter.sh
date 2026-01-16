#!/bin/bash
# Test: Validate frontmatter in content files
# Checks that all markdown files have required frontmatter fields

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "Frontmatter Validation"

ERRORS=0

# Test blog posts
test_section "Blog Posts"

blog_files=$(find "${CONTENT_DIR}/blog" -name "*.md" -type f ! -name "_index.md" 2>/dev/null || true)

if [[ -z "$blog_files" ]]; then
    echo -e "  ${DIM}No blog posts found${RESET}"
else
    while IFS= read -r file; do
        filename=$(basename "$file")
        missing_fields=()

        for field in $BLOG_REQUIRED_FIELDS; do
            if ! has_frontmatter_field "$file" "$field"; then
                missing_fields+=("$field")
            fi
        done

        if [[ ${#missing_fields[@]} -eq 0 ]]; then
            echo -e "  ${PASS}✓${RESET} ${filename}"
        else
            echo -e "  ${FAIL}✗${RESET} ${filename}"
            echo -e "    ${DIM}Missing: ${missing_fields[*]}${RESET}"
            ERRORS=$((ERRORS + 1))
        fi
    done <<< "$blog_files"
fi

# Test book chapters
test_section "Book Chapters"

book_files=$(find "${CONTENT_DIR}/books" -name "*.md" -type f ! -name "_index.md" 2>/dev/null || true)

if [[ -z "$book_files" ]]; then
    echo -e "  ${DIM}No book chapters found${RESET}"
else
    while IFS= read -r file; do
        filename=$(basename "$file")
        relative_path="${file#${CONTENT_DIR}/}"
        missing_fields=()

        for field in $BOOK_REQUIRED_FIELDS; do
            if ! has_frontmatter_field "$file" "$field"; then
                missing_fields+=("$field")
            fi
        done

        if [[ ${#missing_fields[@]} -eq 0 ]]; then
            echo -e "  ${PASS}✓${RESET} ${relative_path}"
        else
            echo -e "  ${FAIL}✗${RESET} ${relative_path}"
            echo -e "    ${DIM}Missing: ${missing_fields[*]}${RESET}"
            ERRORS=$((ERRORS + 1))
        fi
    done <<< "$book_files"
fi

# Test section index files (_index.md)
test_section "Section Index Files"

index_files=$(find "${CONTENT_DIR}" -name "_index.md" -type f 2>/dev/null || true)

if [[ -z "$index_files" ]]; then
    echo -e "  ${DIM}No index files found${RESET}"
else
    while IFS= read -r file; do
        relative_path="${file#${CONTENT_DIR}/}"

        # Index files just need a title
        if has_frontmatter_field "$file" "title"; then
            echo -e "  ${PASS}✓${RESET} ${relative_path}"
        else
            echo -e "  ${FAIL}✗${RESET} ${relative_path}"
            echo -e "    ${DIM}Missing: title${RESET}"
            ERRORS=$((ERRORS + 1))
        fi
    done <<< "$index_files"
fi

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${PASS}All frontmatter validation passed${RESET}"
    exit 0
else
    echo -e "${FAIL}Frontmatter validation failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
