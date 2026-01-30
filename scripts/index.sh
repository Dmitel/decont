#!/bin/bash
# scripts/index.sh

GENOME_FILE=$1
OUT_DIR=$2

echo "Generando índice STAR..."
mkdir -p "$OUT_DIR"

# Comando STAR:
STAR --runThreadN 4 --runMode genomeGenerate --genomeDir "$OUT_DIR" \
     --genomeFastaFiles "$GENOME_FILE" --genomeSAindexNbases 9
