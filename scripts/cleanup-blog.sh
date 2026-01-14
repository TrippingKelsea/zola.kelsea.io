#!/bin/bash
# Script to help clean up accidentally published files

BLOG_DIR="content/blog"

echo "🔍 Checking for files in $BLOG_DIR..."
echo ""

# Count files (excluding _index.md)
FILE_COUNT=$(find "$BLOG_DIR" -type f -name "*.md" ! -name "_index.md" | wc -l)

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "✓ Blog directory is clean (only _index.md)"
    exit 0
fi

echo "Found $FILE_COUNT file(s) in blog directory:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
find "$BLOG_DIR" -type f -name "*.md" ! -name "_index.md" -exec basename {} \; | sort
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Delete all files except _index.md? [y/N]: " response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo ""
    echo "🗑️  Deleting files..."
    find "$BLOG_DIR" -type f -name "*.md" ! -name "_index.md" -delete
    echo "✓ Blog directory cleaned"
    echo ""
    echo "Remaining files:"
    ls -la "$BLOG_DIR"
else
    echo "❌ Cancelled"
fi
