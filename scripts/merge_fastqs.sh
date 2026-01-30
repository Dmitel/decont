#!/bin/bash
# scripts/merge_fastqs.sh

INPUT_DIR=$1
OUTPUT_DIR=$2
SAMPLE_ID=$3

echo "Fusionando archivos para $SAMPLE_ID..."
mkdir -p "$OUTPUT_DIR"

# Fusionar réplicas técnicas
cat "$INPUT_DIR/$SAMPLE_ID"*.fastq.gz > "$OUTPUT_DIR/$SAMPLE_ID.fastq.gz"
