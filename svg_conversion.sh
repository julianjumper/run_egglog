#!/bin/bash

# Check if the correct format is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <jpg|png>"
    exit 1
fi

# Set the desired format (jpg or png)
FORMAT=$1

if [[ "$FORMAT" != "jpg" && "$FORMAT" != "png" ]]; then
    echo "Error: Format must be 'jpg' or 'png'."
    exit 1
fi

# Find and convert SVG files
find . -type f -name "*.svg" | while read -r file; do
    if [[ -f "$file" ]]; then
        # Get the filename without the extension
        filename=$(basename "${file%.*}")
        
        # Use rsvg-convert for better rendering
        rsvg-convert "$file" -f $FORMAT -o "./output-egraphs/${filename}.${FORMAT}"
        # Check if the conversion was successful
        if [[ $? -eq 0 ]]; then
            # Remove the original SVG file
            rm "$file"
        fi
    fi
done
