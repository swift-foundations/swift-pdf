#!/bin/bash
#
# run_benchmarks.sh
# Generate performance statistics for README
#
# Usage:
#   ./run_benchmarks.sh              # Run all benchmarks
#   ./run_benchmarks.sh --quick      # Run only 100 & 1k benchmarks
#   ./run_benchmarks.sh --stress     # Include 100k stress test
#

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  HtmlToPdf Performance Benchmarks${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check arguments
MODE="full"
if [ $# -gt 0 ]; then
    case "$1" in
        --quick)
            MODE="quick"
            echo -e "${YELLOW}Running quick benchmarks only (100 & 1k)${NC}"
            ;;
        --stress)
            MODE="stress"
            echo -e "${YELLOW}Including stress tests (may take 10-15 minutes)${NC}"
            ;;
        --help|-h)
            echo "Usage: $0 [--quick|--stress]"
            echo ""
            echo "Options:"
            echo "  --quick   Run only 100 & 1k benchmarks (fastest)"
            echo "  --stress  Include 100k stress test (slowest)"
            echo "  (none)    Run standard benchmarks (100, 1k, 10k)"
            exit 0
            ;;
    esac
fi

echo ""

# Run the benchmarks
if [ "$MODE" = "stress" ]; then
    echo -e "${GREEN}Running stress tests...${NC}"
    swift test --filter "Generate 100,000 PDFs" 2>&1 | \
        awk '/╔═══/,/━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━/{print}'
elif [ "$MODE" = "quick" ]; then
    echo -e "${GREEN}Running quick benchmarks...${NC}"
    swift test --filter "Performance Benchmarks" 2>&1 | \
        awk '/╔═══/,/━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━/{print}' | \
        grep -A 15 "Performance Results"
else
    echo -e "${GREEN}Running standard benchmarks...${NC}"
    swift test --filter "Performance Benchmarks" 2>&1 | \
        awk '/╔═══/,/━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━/{print}'
fi

echo ""
echo -e "${GREEN}✓ Benchmarks complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "To update README.md, copy the table above and replace the"
echo "Performance Benchmarks section."
echo ""
