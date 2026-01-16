#!/bin/bash
# Terminal color definitions for test output

# Check if we're in a terminal that supports colors
if [[ -t 1 ]] && [[ -n "$TERM" ]] && [[ "$TERM" != "dumb" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[0;37m'
    BOLD='\033[1m'
    DIM='\033[2m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    WHITE=''
    BOLD=''
    DIM=''
    RESET=''
fi

# Semantic colors
PASS="${GREEN}"
FAIL="${RED}"
WARN="${YELLOW}"
INFO="${CYAN}"
HEADER="${BOLD}${WHITE}"
