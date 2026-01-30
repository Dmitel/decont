#!/bin/bash
# scripts/download.sh

URL=$1
OUTDIR=$2
UNCOMPRESS=$3
FILTER_WORD=$4

if [ -z "$URL" ] || [ -z "$OUTDIR" ]; then
    echo "Error: Faltan argumentos. Uso: $0 <url> <outdir> [uncompress] [filter_word]"
    exit 1
fi

mkdir -p "$OUTDIR"
FILENAME=$(basename "$URL")
OUTFILE="$OUTDIR/$FILENAME"

# Descargar
echo "Descargando $FILENAME..."
wget -nc -O "$OUTFILE" "$URL"

# Descomprimir (Si $3 contiene "yes")
if [[ "$UNCOMPRESS" == "yes" ]]; then
    echo "Descomprimiendo..."
    gunzip -f "$OUTFILE"
    OUTFILE="${OUTFILE%.gz}" # Actualizamos nombre quitando .gz
fi

# Filtrar (Si $4 existe)
if [[ -n "$FILTER_WORD" ]]; then
    echo "Filtrando secuencias con '$FILTER_WORD'..."
    seqkit grep -n -v -p "$FILTER_WORD" "$OUTFILE" > "${OUTFILE}.tmp"
    mv "${OUTFILE}.tmp" "$OUTFILE"
fi
