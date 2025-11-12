#!/bin/bash
#===============================================================================
# Script Name: samtools_extract_bed.sh
#
# Description:
#   Extracts genomic regions from a BAM file using bed file and samtools.
#   Reason of using id instead of parameter -L is because it is faster, see benchmarking
#   Regions are defined in a BED file and converted into samtools-compatible
#   region strings (e.g., "chr1:1000-2000").
#
# Usage:
#   samtools_extract_bed.sh <bed_file> <input_bam> <threads> <output_bam> [benchmark]
#
# Example:
#   samtools_extract_bed.sh regions.bed sample.bam 4 sample_filtered.bam
#   samtools_extract_bed.sh regions.bed sample.bam 4 sample_filtered.bam benchmark
#
# Notes:
#   - With 'benchmark' as the 5th argument, the script will compare:
#       1) Standard extraction using pre-expanded regions
#       2) Direct 'samtools -L bed_file' extraction
#   - The benchmark results are written to a text file named:
#       <output_bam_basename>_benchmark.txt
#   - The comparison output BAM from samtools -L is named:
#       samtools_L_ref_<output_bam>
#   - This script is parallelizable with GNU parallel, for example:
#       ls *.bam | parallel -j 4 \
#         bash samtools_extract_bed.sh regions.bed {} 4 '{/.}_filtered.bam'
#
#   - BED coordinates are 0-based; this script converts to 1-based for samtools.
#   - Requires 'samtools' to be installed and in PATH.
#
# Author: Hefaistos
# Created: 2025-11-12
#===============================================================================



set -euo pipefail

#---------------------------#
# Function: extract_bam_regions
#---------------------------#
extract_bam_regions() {
    local bed_file="$1"
    local input_bam="$2"
    local threads="$3"
    local output_bam="$4"

    if [[ ! -f "$bed_file" ]]; then
        echo "Error: BED file not found: $bed_file" >&2
        exit 1
    fi
    if [[ ! -f "$input_bam" ]]; then
        echo "Error: Input BAM file not found: $input_bam" >&2
        exit 1
    fi

    echo "Preparing regions from BED file: $bed_file"
    local regions
    regions=$(awk '{print $1 ":" $2+1 "-" $3}' "$bed_file" | paste -sd' ' -)

    echo "Extracting regions from $input_bam using $threads threads..."
    samtools view -@ "$threads" -bh "$input_bam" $regions > "$output_bam"
    echo "Output written to: $output_bam"
}

#---------------------------#
# Function: benchmark_extraction
#---------------------------#
benchmark_extraction() {
    local bed_file="$1"
    local input_bam="$2"
    local threads="$3"
    local output_bam="$4"
    local ref_output="samtools_L_ref_$(basename "$output_bam")"
    local benchmark_log="${output_bam%.bam}_benchmark.txt"

    echo "Running benchmark mode..."
    echo "BED: $bed_file" > "$benchmark_log"
    echo "BAM: $input_bam" >> "$benchmark_log"
    echo "Threads: $threads" >> "$benchmark_log"
    echo "----------------------------------" >> "$benchmark_log"

    # --- Method 1: BED via -L (reference) ---
    local start1=$(date +%s.%N)
    samtools view -@ "$threads" -bh "$input_bam" -L "$bed_file" > "$ref_output"
    local end1=$(date +%s.%N)
    local elapsed1=$(echo "$end1 - $start1" | bc)

    echo "[Method 1] samtools -L (direct BED)" >> "$benchmark_log"
    echo "Elapsed: ${elapsed1}s" >> "$benchmark_log"
    echo "----------------------------------" >> "$benchmark_log"

    # --- Method 2: expanded region list ---
    local start2=$(date +%s.%N)
    extract_bam_regions "$bed_file" "$input_bam" "$threads" "$output_bam"
    local end2=$(date +%s.%N)
    local elapsed2=$(echo "$end2 - $start2" | bc)

    echo "[Method 2] expanded region list" >> "$benchmark_log"
    echo "Elapsed: ${elapsed2}s" >> "$benchmark_log"
    echo "----------------------------------" >> "$benchmark_log"

    echo "Benchmark complete."
    echo "Results saved to: $benchmark_log"
    echo "Outputs: $output_bam and $ref_output"
}

#---------------------------#
# Main entry point
#---------------------------#
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ "${1:-}" == "-h" || $# -lt 4 ]]; then
        grep '^#' "$0" | sed -E 's/^# ?//'
        exit 0
    fi

    bed_file="$1"
    input_bam="$2"
    threads="$3"
    output_bam="$4"
    mode="${5:-}"

    if [[ "$mode" == "benchmark" ]]; then
        benchmark_extraction "$bed_file" "$input_bam" "$threads" "$output_bam"
    else
        extract_bam_regions "$bed_file" "$input_bam" "$threads" "$output_bam"
    fi
fi
