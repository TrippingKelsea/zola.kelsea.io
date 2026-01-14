#!/usr/bin/env bash
#
# Deploy script for kelsea.io
#
# Builds the Zola site and syncs to S3 bucket
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/public"
S3_BUCKET="${S3_BUCKET:-}"
AWS_PROFILE="${AWS_PROFILE:-default}"
CLOUDFRONT_DIST_ID="${CLOUDFRONT_DIST_ID:-}"
DRY_RUN=false
SKIP_BUILD=false

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy the Zola site to S3.

OPTIONS:
    -b, --bucket BUCKET    S3 bucket name (required, or set S3_BUCKET env var)
    -p, --profile PROFILE  AWS profile to use (default: default)
    -d, --dry-run          Show what would be deployed without actually deploying
    -s, --skip-build       Skip the build step, deploy existing public/ directory
    -h, --help             Show this help message

EXAMPLES:
    # Deploy to S3 bucket
    $0 --bucket my-site-bucket

    # Use specific AWS profile
    $0 --bucket my-site-bucket --profile production

    # Preview what would be deployed
    $0 --bucket my-site-bucket --dry-run

    # Deploy existing build without rebuilding
    $0 --bucket my-site-bucket --skip-build

ENVIRONMENT VARIABLES:
    S3_BUCKET      Default S3 bucket name
    AWS_PROFILE    Default AWS profile (default: default)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--bucket)
            S3_BUCKET="$2"
            shift 2
            ;;
        -p|--profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -s|--skip-build)
            SKIP_BUILD=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$S3_BUCKET" ]]; then
    print_error "S3 bucket name is required"
    echo ""
    usage
    exit 1
fi

# Print configuration
echo "============================================================"
print_info "Deployment Configuration"
echo "============================================================"
echo "  Project:     $PROJECT_DIR"
echo "  S3 Bucket:   s3://$S3_BUCKET"
echo "  AWS Profile: $AWS_PROFILE"
if [[ -n "$CLOUDFRONT_DIST_ID" ]]; then
    echo "  CloudFront:  $CLOUDFRONT_DIST_ID"
fi
echo "  Dry Run:     $DRY_RUN"
echo "  Skip Build:  $SKIP_BUILD"
echo "============================================================"
echo ""

# Check if zola is installed
if ! command -v zola &> /dev/null; then
    print_error "Zola is not installed. Please install it first:"
    echo "  https://www.getzola.org/documentation/getting-started/installation/"
    exit 1
fi

# Check if aws CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first:"
    echo "  https://aws.amazon.com/cli/"
    exit 1
fi

# Verify AWS credentials
print_info "Verifying AWS credentials..."
if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
    print_error "AWS credentials verification failed for profile: $AWS_PROFILE"
    exit 1
fi
print_success "AWS credentials verified"

# Build the site (unless skipped)
if [[ "$SKIP_BUILD" == false ]]; then
    print_info "Building Zola site..."

    cd "$PROJECT_DIR"

    # Clean previous build
    if [[ -d "$BUILD_DIR" ]]; then
        print_info "Cleaning previous build..."
        rm -rf "$BUILD_DIR"
    fi

    # Build
    if ! zola build; then
        print_error "Zola build failed"
        exit 1
    fi

    print_success "Site built successfully"
else
    print_warning "Skipping build step"

    # Check if build directory exists
    if [[ ! -d "$BUILD_DIR" ]]; then
        print_error "Build directory does not exist: $BUILD_DIR"
        print_error "Run without --skip-build to build the site first"
        exit 1
    fi
fi

# Show build statistics
print_info "Build statistics:"
FILE_COUNT=$(find "$BUILD_DIR" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$BUILD_DIR" | cut -f1)
echo "  Files: $FILE_COUNT"
echo "  Total size: $TOTAL_SIZE"
echo ""

# Prepare sync command
SYNC_CMD="aws s3 sync"
SYNC_CMD="$SYNC_CMD \"$BUILD_DIR\""
SYNC_CMD="$SYNC_CMD \"s3://$S3_BUCKET\""
SYNC_CMD="$SYNC_CMD --profile \"$AWS_PROFILE\""
SYNC_CMD="$SYNC_CMD --delete"  # Remove files from S3 that don't exist locally

# Add cache control headers for different file types
SYNC_CMD="$SYNC_CMD --cache-control \"public,max-age=31536000,immutable\" --exclude \"*\""
SYNC_CMD="$SYNC_CMD --include \"*.css\" --include \"*.js\" --include \"*.woff*\" --include \"*.ttf\" --include \"*.eot\""
SYNC_CMD="$SYNC_CMD --cache-control \"public,max-age=3600\" --exclude \"*\""
SYNC_CMD="$SYNC_CMD --include \"*.html\" --include \"*.xml\" --include \"*.json\""

if [[ "$DRY_RUN" == true ]]; then
    SYNC_CMD="$SYNC_CMD --dryrun"
fi

# Deploy to S3
if [[ "$DRY_RUN" == true ]]; then
    print_warning "DRY RUN - Preview of changes:"
else
    print_info "Deploying to S3..."
fi

echo "============================================================"

# Execute sync (simplified version without complex cache control for now)
if [[ "$DRY_RUN" == true ]]; then
    aws s3 sync "$BUILD_DIR" "s3://$S3_BUCKET" \
        --profile "$AWS_PROFILE" \
        --delete \
        --dryrun
else
    aws s3 sync "$BUILD_DIR" "s3://$S3_BUCKET" \
        --profile "$AWS_PROFILE" \
        --delete
fi

SYNC_EXIT=$?

echo "============================================================"
echo ""

if [[ $SYNC_EXIT -eq 0 ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        print_success "Dry run completed successfully"
        print_info "Run without --dry-run to actually deploy"
    else
        print_success "Deployment completed successfully!"
        echo ""

        # Invalidate CloudFront cache if distribution ID is set
        if [[ -n "$CLOUDFRONT_DIST_ID" ]]; then
            print_info "Invalidating CloudFront cache..."

            INVALIDATION_OUTPUT=$(aws cloudfront create-invalidation \
                --distribution-id "$CLOUDFRONT_DIST_ID" \
                --paths "/*" \
                --profile "$AWS_PROFILE" \
                2>&1)

            if [[ $? -eq 0 ]]; then
                INVALIDATION_ID=$(echo "$INVALIDATION_OUTPUT" | grep -o '"Id": "[^"]*"' | head -1 | cut -d'"' -f4)
                print_success "CloudFront cache invalidation created: $INVALIDATION_ID"
                print_info "Changes will be visible globally once invalidation completes (usually 1-5 minutes)"
            else
                print_warning "CloudFront invalidation failed:"
                echo "$INVALIDATION_OUTPUT"
                print_info "You can manually invalidate with:"
                echo "  aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_DIST_ID --paths \"/*\" --profile $AWS_PROFILE"
            fi
            echo ""
        fi

        print_info "Your site should be live at:"
        echo "  https://$S3_BUCKET"
        echo ""
        print_info "Next steps:"
        echo "  1. Verify the deployment in your browser"
        if [[ -z "$CLOUDFRONT_DIST_ID" ]]; then
            echo "  2. If using CloudFront, set CLOUDFRONT_DIST_ID in .deploy-config for automatic cache invalidation"
        fi
    fi
else
    print_error "Deployment failed"
    exit 1
fi
