#!/bin/bash
# Run tests and generate metrics report

# Run swift test and capture output
swift test "$@" 2>&1 | tee /tmp/test-output.log

# Extract metrics from the test output
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    METRICS SUMMARY                               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Extract throughput metrics
grep -E "throughput|PDFs/sec|Avg per PDF|p95" /tmp/test-output.log | tail -20

echo ""
echo "╚══════════════════════════════════════════════════════════════════╝"
