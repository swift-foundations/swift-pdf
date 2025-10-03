#!/bin/bash
# Cleanup script for leftover test PDF files
# Run this if tests are interrupted or timeout before cleanup

echo "🧹 Cleaning up test PDF files..."

TEMP_DIR="/private/var/folders/zh/1w0zshh16kl26vbbnj4v9q000000gn/T/html-to-pdf"

if [ -d "$TEMP_DIR" ]; then
    echo "Found test directory: $TEMP_DIR"
    
    # Count directories and estimate size
    DIR_COUNT=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
    SIZE=$(du -sh "$TEMP_DIR" 2>/dev/null | cut -f1)
    
    echo "Directories to clean: $DIR_COUNT"
    echo "Total size: $SIZE"
    echo ""
    echo "Removing files (this may take a while for large directories)..."
    
    # Use find for faster deletion
    find "$TEMP_DIR" -type f -delete
    find "$TEMP_DIR" -mindepth 1 -type d -delete
    rmdir "$TEMP_DIR" 2>/dev/null
    
    echo "✅ Cleanup complete!"
else
    echo "No test directories found. Nothing to clean up."
fi
