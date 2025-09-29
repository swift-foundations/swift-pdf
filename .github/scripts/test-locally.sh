#!/bin/bash

# Script to test GitHub Actions workflows locally
# This simulates what the CI will run

set -e

echo "🔧 Testing GitHub Actions Locally"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to run a test
run_test() {
    local name="$1"
    local command="$2"

    echo -e "\n${YELLOW}Running: $name${NC}"
    if eval "$command"; then
        echo -e "${GREEN}✅ $name passed${NC}"
        return 0
    else
        echo -e "${RED}❌ $name failed${NC}"
        return 1
    fi
}

# Track failures
FAILED=0

# Test 1: Swift version
run_test "Swift Version Check" "swift --version" || FAILED=1

# Test 2: Build Debug
run_test "Build (Debug)" "swift build" || FAILED=1

# Test 3: Build Release
run_test "Build (Release)" "swift build -c release" || FAILED=1

# Test 4: Run Tests
export WEBVIEW_POOL_SILENT=1
run_test "Tests (Debug)" "swift test" || FAILED=1

# Test 5: Run Tests in Release
run_test "Tests (Release)" "swift test -c release" || FAILED=1

# Test 6: Run Integration Tests
run_test "Integration Tests" "swift test --filter collection -c release" || FAILED=1

# Test 7: Check if documentation builds (if swift-docc-plugin is available)
if swift package describe --type json | grep -q "swift-docc-plugin"; then
    run_test "Documentation" "swift package generate-documentation --target HtmlToPdf" || FAILED=1
else
    echo -e "${YELLOW}Skipping documentation (swift-docc-plugin not configured)${NC}"
fi

# Test 8: Check for Mac Catalyst support
if command -v xcodebuild &> /dev/null; then
    run_test "Mac Catalyst Build" \
        "xcodebuild build -scheme swift-html-to-pdf -destination 'platform=macOS,variant=Mac Catalyst' -quiet" || FAILED=1
else
    echo -e "${YELLOW}Skipping Mac Catalyst (Xcode not available)${NC}"
fi

echo -e "\n=================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo "Your code is ready for CI/CD"
else
    echo -e "${RED}❌ Some tests failed${NC}"
    echo "Please fix the issues before pushing"
    exit 1
fi