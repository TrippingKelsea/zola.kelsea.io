#!/bin/bash
# Test: Verify AWS S3 access and credentials
# Checks that deployment credentials are valid

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "S3 Access Test"

ERRORS=0

test_section "Checking prerequisites"

# Check for AWS CLI
if ! require_command "aws"; then
    echo -e "${FAIL}AWS CLI is required for deployment${RESET}"
    exit 1
fi

echo -e "  ${PASS}✓${RESET} AWS CLI found: $(aws --version 2>&1 | head -1)"

# Check for deployment config
if [[ ! -f "${PROJECT_ROOT}/.deploy-config" ]]; then
    echo -e "  ${WARN}⚠${RESET} .deploy-config not found"
    echo -e "  ${DIM}Copy .deploy-config.example and configure${RESET}"

    # Check if we have environment variables instead
    if [[ -z "${S3_BUCKET}" ]]; then
        echo -e "  ${FAIL}✗${RESET} S3_BUCKET not configured"
        exit 1
    fi
else
    source "${PROJECT_ROOT}/.deploy-config"
    echo -e "  ${PASS}✓${RESET} .deploy-config loaded"
fi

test_section "Validating configuration"

# Check required variables
if [[ -z "${S3_BUCKET}" ]]; then
    echo -e "  ${FAIL}✗${RESET} S3_BUCKET not set"
    ERRORS=$((ERRORS + 1))
else
    echo -e "  ${PASS}✓${RESET} S3_BUCKET: ${S3_BUCKET}"
fi

if [[ -n "${AWS_PROFILE}" ]]; then
    echo -e "  ${INFO}→${RESET} AWS_PROFILE: ${AWS_PROFILE}"
fi

if [[ -n "${CLOUDFRONT_DIST_ID}" ]]; then
    echo -e "  ${PASS}✓${RESET} CLOUDFRONT_DIST_ID configured"
else
    echo -e "  ${WARN}⚠${RESET} CLOUDFRONT_DIST_ID not set (cache invalidation disabled)"
fi

test_section "Testing AWS credentials"

# Test AWS credentials
aws_args=""
if [[ -n "${AWS_PROFILE}" ]]; then
    aws_args="--profile ${AWS_PROFILE}"
fi

if aws sts get-caller-identity ${aws_args} > /dev/null 2>&1; then
    caller_id=$(aws sts get-caller-identity ${aws_args} --query 'Arn' --output text 2>/dev/null)
    echo -e "  ${PASS}✓${RESET} AWS credentials valid"
    echo -e "  ${DIM}Identity: ${caller_id}${RESET}"
else
    echo -e "  ${FAIL}✗${RESET} AWS credentials invalid or expired"
    ERRORS=$((ERRORS + 1))
fi

test_section "Testing S3 bucket access"

if [[ $ERRORS -eq 0 ]] && [[ -n "${S3_BUCKET}" ]]; then
    # Test bucket exists and is accessible
    if aws s3 ls "s3://${S3_BUCKET}" ${aws_args} > /dev/null 2>&1; then
        echo -e "  ${PASS}✓${RESET} S3 bucket accessible"

        # Count objects in bucket
        object_count=$(aws s3 ls "s3://${S3_BUCKET}" ${aws_args} --recursive 2>/dev/null | wc -l || echo "0")
        echo -e "  ${INFO}→${RESET} Bucket contains ~${object_count} objects"
    else
        echo -e "  ${FAIL}✗${RESET} Cannot access S3 bucket: ${S3_BUCKET}"
        echo -e "  ${DIM}Check bucket name and permissions${RESET}"
        ERRORS=$((ERRORS + 1))
    fi

    # Test write permission (without actually writing)
    # We can't easily test this without writing, so we'll check the bucket policy
    if aws s3api get-bucket-location --bucket "${S3_BUCKET}" ${aws_args} > /dev/null 2>&1; then
        echo -e "  ${PASS}✓${RESET} Bucket metadata accessible"
    else
        echo -e "  ${WARN}⚠${RESET} Cannot read bucket metadata (may lack permissions)"
    fi
fi

test_section "Testing CloudFront access"

if [[ -n "${CLOUDFRONT_DIST_ID}" ]]; then
    if aws cloudfront get-distribution --id "${CLOUDFRONT_DIST_ID}" ${aws_args} > /dev/null 2>&1; then
        # Get distribution status
        status=$(aws cloudfront get-distribution --id "${CLOUDFRONT_DIST_ID}" ${aws_args} --query 'Distribution.Status' --output text 2>/dev/null)
        echo -e "  ${PASS}✓${RESET} CloudFront distribution accessible (Status: ${status})"

        # Check if distribution is enabled
        enabled=$(aws cloudfront get-distribution --id "${CLOUDFRONT_DIST_ID}" ${aws_args} --query 'Distribution.DistributionConfig.Enabled' --output text 2>/dev/null)
        if [[ "$enabled" == "true" ]]; then
            echo -e "  ${PASS}✓${RESET} Distribution is enabled"
        else
            echo -e "  ${WARN}⚠${RESET} Distribution is disabled"
        fi
    else
        echo -e "  ${FAIL}✗${RESET} Cannot access CloudFront distribution: ${CLOUDFRONT_DIST_ID}"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${PASS}S3 access test passed${RESET}"
    exit 0
else
    echo -e "${FAIL}S3 access test failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
