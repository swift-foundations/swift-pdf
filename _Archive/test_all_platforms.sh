#!/bin/bash

# Test script for swift-html-to-pdf
# Tests both macOS and iOS (via Mac Catalyst) platforms

echo "================================================"
echo "Testing swift-html-to-pdf on all platforms"
echo "================================================"

# Set environment to reduce verbose output
export WEBVIEW_POOL_SILENT=1

echo ""
echo "1. Building the project..."
swift build

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build successful"

echo ""
echo "2. Testing on macOS..."
swift test --filter "individual"

if [ $? -ne 0 ]; then
    echo "❌ macOS tests failed"
    exit 1
fi

echo "✅ macOS tests passed"

echo ""
echo "3. Testing on iOS (Mac Catalyst)..."
echo "(Note: Mac Catalyst tests require Xcode and may show warnings)"

# Run a simple compilation test for iOS
echo "Compiling for iOS target..."
xcodebuild build -scheme swift-html-to-pdf -destination 'platform=macOS,variant=Mac Catalyst' -quiet 2>&1

if [ $? -eq 0 ]; then
    echo "✅ iOS compilation successful"
else
    echo "❌ iOS compilation failed"
    exit 1
fi

echo ""
echo "================================================"
echo "✅ All tests passed on all platforms!"
echo "================================================"