#!/bin/bash

output_file="all-tests.swift"
> "$output_file"

find Tests -name "*.swift" -type f | sort | while read -r file; do
    echo "// ========================================" >> "$output_file"
    echo "// File: $file" >> "$output_file"
    echo "// ========================================" >> "$output_file"
    echo "" >> "$output_file"
    cat "$file" >> "$output_file"
    echo "" >> "$output_file"
    echo "" >> "$output_file"
done

echo "Exported all Tests files to $output_file"
