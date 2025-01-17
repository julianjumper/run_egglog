#!/bin/bash

# Check if the input file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

file=$1

# Run the commands
egglog ${file} --to-svg && ./svg_conversion.sh png