#!/bin/bash
# Test: Validate image references in content files
# Checks that all referenced images exist in the static directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "Image Reference Validation"

ERRORS=0
WARNINGS=0

test_section "Checking image references"

# Get all markdown files
content_files=$(get_content_files)

if [[ -z "$content_files" ]]; then
    echo -e "  ${DIM}No content files found${RESET}"
    exit 0
fi

while IFS= read -r file; do
    relative_path="${file#${CONTENT_DIR}/}"

    # Find markdown image references: ![alt](/path/to/image) or ![alt](path/to/image)
    # Also find HTML img tags: <img src="/path/to/image"
    images=$(grep -oE '!\[[^\]]*\]\([^)]+\)|<img[^>]+src="[^"]+"' "$file" 2>/dev/null || true)

    if [[ -z "$images" ]]; then
        continue
    fi

    file_has_errors=false

    while IFS= read -r img_ref; do
        # Extract the path from markdown syntax ![alt](path)
        # Use sed to extract the path more reliably
        if [[ "$img_ref" == "!"* ]]; then
            # Markdown image: ![alt](path)
            img_path=$(echo "$img_ref" | sed -E 's/.*\]\(([^)]+)\).*/\1/')
        elif [[ "$img_ref" == *"src="* ]]; then
            # HTML img: <img src="path">
            img_path=$(echo "$img_ref" | sed -E 's/.*src="([^"]+)".*/\1/')
        else
            continue
        fi

        # Skip if extraction failed
        [[ -z "$img_path" ]] && continue

        # Skip external URLs
        if [[ "$img_path" =~ ^https?:// ]]; then
            continue
        fi

        # Skip data URIs
        if [[ "$img_path" =~ ^data: ]]; then
            continue
        fi

        # Handle absolute paths (starting with /)
        if [[ "$img_path" =~ ^/ ]]; then
            full_path="${STATIC_DIR}${img_path}"
        else
            # Relative path - resolve from content file location
            content_dir=$(dirname "$file")
            full_path="${content_dir}/${img_path}"
        fi

        # Also check in static/images
        alt_path="${STATIC_DIR}/images/$(basename "$img_path")"

        if [[ -f "$full_path" ]] || [[ -f "$alt_path" ]]; then
            : # Image exists, no output needed for passing individual images
        else
            if [[ "$file_has_errors" == false ]]; then
                echo -e "  ${FAIL}✗${RESET} ${relative_path}"
                file_has_errors=true
            fi
            echo -e "    ${DIM}Missing image: ${img_path}${RESET}"
            ERRORS=$((ERRORS + 1))
        fi
    done <<< "$images"

    if [[ "$file_has_errors" == false ]] && [[ -n "$images" ]]; then
        # Only show pass if file had images to check
        img_count=$(echo "$images" | wc -l)
        echo -e "  ${PASS}✓${RESET} ${relative_path} (${img_count} images)"
    fi

done <<< "$content_files"

# Check for orphaned images (optional, just a warning)
test_section "Checking for orphaned images"

if [[ -d "${STATIC_DIR}/images" ]]; then
    image_files=$(find "${STATIC_DIR}/images" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.svg" -o -name "*.webp" \) 2>/dev/null || true)

    if [[ -n "$image_files" ]]; then
        orphaned=0
        while IFS= read -r img; do
            img_name=$(basename "$img")
            # Check if image is referenced anywhere in content
            if ! grep -rq "$img_name" "${CONTENT_DIR}" 2>/dev/null; then
                echo -e "  ${WARN}⚠${RESET} Possibly orphaned: ${img_name}"
                ((orphaned++))
                WARNINGS=$((WARNINGS + 1))
            fi
        done <<< "$image_files"

        if [[ $orphaned -eq 0 ]]; then
            echo -e "  ${PASS}✓${RESET} No orphaned images detected"
        fi
    else
        echo -e "  ${DIM}No images in static/images/${RESET}"
    fi
else
    echo -e "  ${DIM}No static/images/ directory${RESET}"
fi

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${WARN}Image validation passed with ${WARNINGS} warning(s)${RESET}"
    else
        echo -e "${PASS}All image validation passed${RESET}"
    fi
    exit 0
else
    echo -e "${FAIL}Image validation failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
