#!/bin/bash
# Main test runner for kelsea.io
# Usage: ./run_tests.sh [suite] [--quick]
#   suite: content, build, deployment, live, all (default: all)
#   --quick: Skip slower tests (internal link validation)

# Note: We don't use 'set -e' because we handle test failures ourselves

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export TESTS_DIR="${SCRIPT_DIR}"

source "${SCRIPT_DIR}/lib/test_utils.sh"
source "${SCRIPT_DIR}/config.sh"

SUITE="${1:-all}"
QUICK_MODE=""
[[ "$2" == "--quick" ]] && QUICK_MODE="--quick"
[[ "$1" == "--quick" ]] && SUITE="all" && QUICK_MODE="--quick"

# Print header
echo ""
echo -e "${HEADER}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${HEADER}║                    kelsea.io Test Suite                      ║${RESET}"
echo -e "${HEADER}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${INFO}Suite:${RESET} ${SUITE}"
[[ -n "$QUICK_MODE" ]] && echo -e "${INFO}Mode:${RESET} Quick (skipping slow tests)"
echo -e "${INFO}Project:${RESET} ${PROJECT_ROOT}"
echo ""

# Test suites
run_content_tests() {
    echo -e "${HEADER}▶ CONTENT TESTS${RESET}"
    run_test "acceptance/content/test_frontmatter.sh" || true
    run_test "acceptance/content/test_markdown.sh" || true
    run_test "acceptance/content/test_images.sh" || true
    [[ -z "$QUICK_MODE" ]] && run_test "acceptance/content/test_internal_links.sh" || true
}

run_build_tests() {
    echo -e "${HEADER}▶ BUILD TESTS${RESET}"
    run_test "acceptance/build/test_zola_build.sh" || true
    run_test "acceptance/build/test_zola_check.sh" || true
    run_test "acceptance/build/test_html_validity.sh" || true
    run_test "acceptance/build/test_feed_validity.sh" || true
    run_test "acceptance/build/test_asset_integrity.sh" || true
}

run_deployment_tests() {
    echo -e "${HEADER}▶ DEPLOYMENT TESTS${RESET}"
    run_test "acceptance/deployment/test_s3_access.sh" || true
    run_test "acceptance/deployment/test_dry_run.sh" || true
    run_test "acceptance/deployment/test_cloudfront.sh" || true
}

run_live_tests() {
    echo -e "${HEADER}▶ LIVE SITE TESTS${RESET}"
    run_test "acceptance/live/test_http_status.sh" || true
    run_test "acceptance/live/test_feeds_accessible.sh" || true
    run_test "acceptance/live/test_theme_switcher.sh" || true
    run_test "acceptance/live/test_performance.sh" || true
}

# Main execution
case "$SUITE" in
    content)
        run_content_tests
        ;;
    build)
        run_build_tests
        ;;
    deployment)
        run_deployment_tests
        ;;
    live)
        run_live_tests
        ;;
    precommit)
        # Quick content validation for pre-commit hooks
        QUICK_MODE="--quick"
        run_content_tests
        ;;
    ci)
        # Full CI run (content + build)
        run_content_tests
        run_build_tests
        ;;
    all)
        run_content_tests
        run_build_tests
        ;;
    full)
        # Everything including deployment and live tests
        run_content_tests
        run_build_tests
        run_deployment_tests
        run_live_tests
        ;;
    *)
        echo "Usage: $0 {content|build|deployment|live|precommit|ci|all|full} [--quick]"
        echo ""
        echo "Suites:"
        echo "  content     - Frontmatter, markdown, images, internal links"
        echo "  build       - Zola build, HTML validity, feeds, assets"
        echo "  deployment  - S3 access, dry-run, CloudFront"
        echo "  live        - HTTP status, feeds, performance, theme switcher"
        echo "  precommit   - Quick content tests (for git hooks)"
        echo "  ci          - Content + build (for CI pipeline)"
        echo "  all         - Content + build (default)"
        echo "  full        - All tests including deployment and live"
        echo ""
        echo "Options:"
        echo "  --quick     - Skip slower tests"
        exit 1
        ;;
esac

# Print summary
print_summary

# Exit with failure count
exit $TEST_FAILURES
