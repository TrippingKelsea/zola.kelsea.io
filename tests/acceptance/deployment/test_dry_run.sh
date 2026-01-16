#!/bin/bash
# Test: Perform deployment dry-run
# Validates that sync would succeed without actually deploying

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "Deployment Dry-Run Test"

ERRORS=0

test_section "Checking prerequisites"

if ! require_command "aws"; then
    echo -e "${FAIL}AWS CLI is required${RESET}"
    exit 1
fi

# Load deployment config
if [[ -f "${PROJECT_ROOT}/.deploy-config" ]]; then
    source "${PROJECT_ROOT}/.deploy-config"
fi

if [[ -z "${S3_BUCKET}" ]]; then
    echo -e "  ${FAIL}✗${RESET} S3_BUCKET not configured"
    exit 1
fi

# Check build exists
if [[ ! -d "${PUBLIC_DIR}" ]]; then
    echo -e "  ${FAIL}✗${RESET} public/ directory not found - run build first"
    exit 1
fi

file_count=$(find "${PUBLIC_DIR}" -type f | wc -l)
echo -e "  ${PASS}✓${RESET} Build ready (${file_count} files)"

test_section "Running deployment dry-run"

aws_args=""
if [[ -n "${AWS_PROFILE}" ]]; then
    aws_args="--profile ${AWS_PROFILE}"
fi

# Run sync with --dryrun
echo -e "  ${INFO}→${RESET} Simulating sync to s3://${S3_BUCKET}/"

dry_run_output=$(aws s3 sync "${PUBLIC_DIR}/" "s3://${S3_BUCKET}/" \
    --dryrun \
    --delete \
    ${aws_args} 2>&1) || {
    echo -e "  ${FAIL}✗${RESET} Dry-run failed"
    echo -e "${DIM}${dry_run_output}${RESET}"
    ERRORS=$((ERRORS + 1))
}

if [[ $ERRORS -eq 0 ]]; then
    echo -e "  ${PASS}✓${RESET} Dry-run completed successfully"

    # Parse dry-run output for statistics
    upload_count=$(echo "$dry_run_output" | grep -c "upload:" || echo "0")
    delete_count=$(echo "$dry_run_output" | grep -c "delete:" || echo "0")

    echo -e "  ${INFO}→${RESET} Would upload: ${upload_count} files"
    echo -e "  ${INFO}→${RESET} Would delete: ${delete_count} files"

    # Show sample of what would be uploaded
    if [[ $upload_count -gt 0 ]]; then
        echo ""
        echo -e "  ${DIM}Sample uploads:${RESET}"
        echo "$dry_run_output" | grep "upload:" | head -5 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
        if [[ $upload_count -gt 5 ]]; then
            echo -e "    ${DIM}... and $((upload_count - 5)) more${RESET}"
        fi
    fi

    # Warn about deletions
    if [[ $delete_count -gt 0 ]]; then
        echo ""
        echo -e "  ${WARN}⚠${RESET} Files to be deleted:"
        echo "$dry_run_output" | grep "delete:" | head -5 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
        if [[ $delete_count -gt 5 ]]; then
            echo -e "    ${DIM}... and $((delete_count - 5)) more${RESET}"
        fi
    fi
fi

test_section "Verifying deployment script"

# Check that deploy.sh exists and is executable
deploy_script="${PROJECT_ROOT}/scripts/deploy.sh"
if [[ -x "$deploy_script" ]]; then
    echo -e "  ${PASS}✓${RESET} deploy.sh is executable"
else
    echo -e "  ${WARN}⚠${RESET} deploy.sh not found or not executable"
fi

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${PASS}Deployment dry-run test passed${RESET}"
    exit 0
else
    echo -e "${FAIL}Deployment dry-run test failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
