#!/bin/bash
# Test configuration for kelsea.io

# Site configuration
export SITE_URL="https://www.kelsea.io"
export SITE_NAME="kelsea.io"

# Performance thresholds
export RESPONSE_TIME_THRESHOLD_MS=15  # p95 response time in milliseconds

# Sampling configuration
export EXTERNAL_LINK_SAMPLE_SIZE=10   # Number of external links to check randomly

# Required frontmatter fields by content type
export BLOG_REQUIRED_FIELDS="title date"
export BOOK_REQUIRED_FIELDS="title date weight"

# Critical URLs that must always be checked
export CRITICAL_URLS=(
    "/"
    "/blog/"
    "/about/"
    "/projects/"
    "/books/waltzing-through-chaos/"
    "/rss.xml"
    "/atom.xml"
    "/404.html"
)

# Static assets that must exist and be non-empty
export REQUIRED_ASSETS=(
    "terminal.css"
    "terminal.js"
)

# HTML validation settings
export HTML_VALIDATOR_IGNORE=(
    # Patterns to ignore in HTML validation (if any)
)

# Timeouts (in seconds)
export HTTP_TIMEOUT=10
export BUILD_TIMEOUT=120
export DEPLOY_TIMEOUT=300

# AWS/Deployment settings (loaded from .deploy-config if available)
if [[ -f "${PROJECT_ROOT}/.deploy-config" ]]; then
    source "${PROJECT_ROOT}/.deploy-config"
fi
