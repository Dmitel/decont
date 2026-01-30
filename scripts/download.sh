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

# 1. Descargar archivo principal
echo "Descargando $FILENAME..."
wget -nc -O "$OUTFILE" "$URL"

# 2. BONUS MD5: Verificar integridad sin bajar el archivo .md5 al disco
echo "  > Verificando MD5..."
MD5_URL="${URL}.md5"

# Usamos wget -qO- para leer el contenido de la URL directamente en la variable
# 'awk' se asegura de coger solo el primer campo (el hash) por si el archivo trae nombre
EXPECTED_MD5=$(wget -qO- "$MD5_URL" | awk '{print $1}')

# Calculamos el MD5 del archivo que acabamos de bajar
ACTUAL_MD5=$(md5sum "$OUTFILE" | awk '{print $1}')

if [ "$EXPECTED_MD5" == "$ACTUAL_MD5" ]; then
    echo "  > Integridad confirmada: $ACTUAL_MD5"
else
    echo "  > ERROR: El MD5 no coincide."
    echo "    Esperado: $EXPECTED_MD5"
    echo "    Obtenido: $ACTUAL_MD5"
    # Borramos el archivo corrupto y salimos con error
    rm "$OUTFILE"
    exit 1
fi

# 3. Descomprimir (Si se solicita)
if [[ "$UNCOMPRESS" == "yes" ]]; then
    echo "  > Descomprimiendo..."
    gunzip -f "$OUTFILE"
    OUTFILE="${OUTFILE%.gz}"
fi

# 4. Filtrar (Si se solicita)
if [[ -n "$FILTER_WORD" ]]; then
    echo "  > Filtrando secuencias con '$FILTER_WORD'..."
    seqkit grep -n -v -p "$FILTER_WORD" "$OUTFILE" > "${OUTFILE}.tmp"
    mv "${OUTFILE}.tmp" "$OUTFILE"
fi
