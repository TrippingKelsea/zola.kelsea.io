#!/bin/bash
# Wrapper script for easy publishing from Obsidian to Zola
# Updated for flat vault structure (no subdirectories)

# Load configuration if it exists
if [ -f .publish-config ]; then
    source .publish-config
else
    echo "⚠️  No .publish-config found. Using defaults."
    echo "   Copy .publish-config.example to .publish-config and customize."
    VAULT_PATH="/mnt/OhShit-Local/Obsidian/Notes"
    ZOLA_PATH="."
    SCRIPT_PATH="scripts/publish.py"
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    --blog-only     Publish only blog posts (type: blog)
    --book-only     Publish only book chapters (type: book)
    --dry-run       Preview changes without copying files
    --build         Build the site after syncing
    --serve         Start development server after syncing
    -h, --help      Show this help message

How it works:
    Scans all .md files in vault root and uses frontmatter to determine
    content type:

    - Has 'type: blog' → blog post
    - Has 'type: book' → book chapter
    - Has 'weight' or 'chapter_number' → book chapter
    - Otherwise → blog post

    Control publishing with:
    - publish: true  → publishes
    - publish: false → skips

Examples:
    $0                      # Publish all files (blog + book)
    $0 --blog-only          # Publish only blog posts
    $0 --book-only          # Publish only book chapters
    $0 --dry-run            # Preview what would be published
    $0 --build              # Publish and build site
    $0 --serve              # Publish and start dev server

EOF
    exit 0
}

# Parse command line arguments
TYPE_FILTER=""
DRY_RUN=""
DO_BUILD=false
DO_SERVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --blog-only)
            TYPE_FILTER="--type blog"
            shift
            ;;
        --book-only)
            TYPE_FILTER="--type book"
            shift
            ;;
        --dry-run)
            DRY_RUN="--dry-run"
            shift
            ;;
        --build)
            DO_BUILD=true
            shift
            ;;
        --serve)
            DO_SERVE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Build the command
CMD="python3 $SCRIPT_PATH --vault \"$VAULT_PATH\" --zola \"$ZOLA_PATH\""

if [ -n "$TYPE_FILTER" ]; then
    CMD="$CMD $TYPE_FILTER"
fi

if [ -n "$DRY_RUN" ]; then
    CMD="$CMD $DRY_RUN"
fi

# Execute the publish command
echo -e "${GREEN}🚀 Publishing from Obsidian to Zola${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
eval $CMD

# Build if requested
if [ "$DO_BUILD" = true ] && [ -z "$DRY_RUN" ]; then
    echo ""
    echo -e "${GREEN}🔨 Building site...${NC}"
    zola build
fi

# Serve if requested
if [ "$DO_SERVE" = true ] && [ -z "$DRY_RUN" ]; then
    echo ""
    echo -e "${GREEN}🌐 Starting development server...${NC}"
    zola serve
fi

echo ""
echo -e "${GREEN}✅ Done!${NC}"
