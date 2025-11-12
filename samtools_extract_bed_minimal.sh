#!/bin/bash
set -euo pipefail

extract_bam_regions() {
    local bed_file="$1"
    local input_bam="$2"
    local threads="$3"
    local output_bam="$4"

    local regions
    regions=$(awk '{print $1 ":" $2+1 "-" $3}' "$bed_file" | paste -sd' ' -)
    samtools view -@ "$threads" -bh "$input_bam" $regions > "$output_bam"
}

# If script is called directly, run the function with given args
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    extract_bam_regions "$@"
fi