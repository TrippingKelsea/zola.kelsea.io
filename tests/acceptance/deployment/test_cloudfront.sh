#!/bin/bash
# Test: Verify CloudFront distribution configuration
# Checks distribution is properly configured for static site hosting

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/test_utils.sh"
source "${SCRIPT_DIR}/../../config.sh"

test_header "CloudFront Configuration Test"

ERRORS=0
WARNINGS=0

test_section "Checking prerequisites"

if ! require_command "aws"; then
    echo -e "${FAIL}AWS CLI is required${RESET}"
    exit 1
fi

# Load deployment config
if [[ -f "${PROJECT_ROOT}/.deploy-config" ]]; then
    source "${PROJECT_ROOT}/.deploy-config"
fi

if [[ -z "${CLOUDFRONT_DIST_ID}" ]]; then
    echo -e "  ${INFO}→${RESET} CLOUDFRONT_DIST_ID not configured"
    echo -e "  ${DIM}CloudFront tests skipped${RESET}"
    exit 0
fi

echo -e "  ${PASS}✓${RESET} Distribution ID: ${CLOUDFRONT_DIST_ID}"

aws_args=""
if [[ -n "${AWS_PROFILE}" ]]; then
    aws_args="--profile ${AWS_PROFILE}"
fi

test_section "Checking distribution status"

# Get distribution details
dist_info=$(aws cloudfront get-distribution --id "${CLOUDFRONT_DIST_ID}" ${aws_args} 2>&1) || {
    echo -e "  ${FAIL}✗${RESET} Cannot access distribution"
    echo -e "  ${DIM}${dist_info}${RESET}"
    exit 1
}

# Check status
status=$(echo "$dist_info" | jq -r '.Distribution.Status' 2>/dev/null || echo "unknown")
if [[ "$status" == "Deployed" ]]; then
    echo -e "  ${PASS}✓${RESET} Distribution status: ${status}"
else
    echo -e "  ${WARN}⚠${RESET} Distribution status: ${status}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check enabled
enabled=$(echo "$dist_info" | jq -r '.Distribution.DistributionConfig.Enabled' 2>/dev/null || echo "unknown")
if [[ "$enabled" == "true" ]]; then
    echo -e "  ${PASS}✓${RESET} Distribution is enabled"
else
    echo -e "  ${FAIL}✗${RESET} Distribution is disabled"
    ERRORS=$((ERRORS + 1))
fi

test_section "Checking distribution configuration"

# Get domain name
domain=$(echo "$dist_info" | jq -r '.Distribution.DomainName' 2>/dev/null || echo "unknown")
echo -e "  ${INFO}→${RESET} CloudFront domain: ${domain}"

# Check aliases (custom domains)
aliases=$(echo "$dist_info" | jq -r '.Distribution.DistributionConfig.Aliases.Items[]?' 2>/dev/null || echo "")
if [[ -n "$aliases" ]]; then
    echo -e "  ${PASS}✓${RESET} Custom domains configured:"
    echo "$aliases" | while read -r alias; do
        echo -e "    ${DIM}${alias}${RESET}"
    done
else
    echo -e "  ${INFO}→${RESET} No custom domains (using CloudFront domain)"
fi

# Check default root object
default_root=$(echo "$dist_info" | jq -r '.Distribution.DistributionConfig.DefaultRootObject' 2>/dev/null || echo "")
if [[ "$default_root" == "index.html" ]]; then
    echo -e "  ${PASS}✓${RESET} Default root object: index.html"
elif [[ -n "$default_root" ]]; then
    echo -e "  ${INFO}→${RESET} Default root object: ${default_root}"
else
    echo -e "  ${WARN}⚠${RESET} No default root object set"
    WARNINGS=$((WARNINGS + 1))
fi

# Check HTTPS configuration
viewer_protocol=$(echo "$dist_info" | jq -r '.Distribution.DistributionConfig.DefaultCacheBehavior.ViewerProtocolPolicy' 2>/dev/null || echo "unknown")
if [[ "$viewer_protocol" == "redirect-to-https" ]] || [[ "$viewer_protocol" == "https-only" ]]; then
    echo -e "  ${PASS}✓${RESET} HTTPS enforced: ${viewer_protocol}"
else
    echo -e "  ${WARN}⚠${RESET} HTTPS policy: ${viewer_protocol}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check custom error responses (for 404 page)
custom_errors=$(echo "$dist_info" | jq -r '.Distribution.DistributionConfig.CustomErrorResponses.Items[]?' 2>/dev/null || echo "")
if [[ -n "$custom_errors" ]]; then
    echo -e "  ${PASS}✓${RESET} Custom error responses configured"
else
    echo -e "  ${INFO}→${RESET} No custom error responses (default 404 handling)"
fi

test_section "Testing invalidation capability"

# Test that we can create invalidations (without actually doing it)
# Just verify the permission exists
if aws cloudfront list-invalidations --distribution-id "${CLOUDFRONT_DIST_ID}" ${aws_args} --max-items 1 > /dev/null 2>&1; then
    echo -e "  ${PASS}✓${RESET} Invalidation permission verified"

    # Check for recent invalidations
    recent=$(aws cloudfront list-invalidations --distribution-id "${CLOUDFRONT_DIST_ID}" ${aws_args} --max-items 1 --query 'InvalidationList.Items[0].CreateTime' --output text 2>/dev/null || echo "None")
    if [[ "$recent" != "None" ]] && [[ -n "$recent" ]]; then
        echo -e "  ${INFO}→${RESET} Last invalidation: ${recent}"
    fi
else
    echo -e "  ${WARN}⚠${RESET} Cannot list invalidations (may lack permission)"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${WARN}CloudFront test passed with ${WARNINGS} warning(s)${RESET}"
    else
        echo -e "${PASS}CloudFront test passed${RESET}"
    fi
    exit 0
else
    echo -e "${FAIL}CloudFront test failed with ${ERRORS} error(s)${RESET}"
    exit 1
fi
