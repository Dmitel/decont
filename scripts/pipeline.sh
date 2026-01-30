#!/bin/bash
# scripts/pipeline.sh
# Pipeline principal de ejecución para el proyecto de descontaminación

set -e

# Crear carpetas de logs
mkdir -p log/cutadapt log/star
LOGFILE="log/pipeline_summary.log"

echo "Iniciando Pipeline..."
echo "Informe de Ejecución del Pipeline" > "$LOGFILE"
date >> "$LOGFILE"
echo "------------------------------------------------" >> "$LOGFILE"

# ==============================================================================
# PASO 1: Descarga de Muestras
# ==============================================================================
echo "Paso 1: Descargando muestras crudas..."

if [ ! -f data/urls ]; then
    echo "Error: No se encuentra el archivo data/urls."
    exit 1
fi

for url in $(cat data/urls); do
    # El script de descarga ya usa 'wget -nc', así que no descarga si existe
    bash scripts/download.sh "$url" data
done

# ==============================================================================
# PASO 2: Preparar Base de Datos de Contaminantes
# ==============================================================================
echo "Paso 2: Preparando referencia de contaminantes..."

URL_CONTAMINANTES="https://masterbioinformatica.com/decont/contaminants.fasta.gz"

# Comprobar si el índice ya existe para saltar este paso
if [ -d "res/contaminants_idx" ]; then
    echo "  > Índice de contaminantes detectado. Saltando descarga e indexado."
else
    bash scripts/download.sh "$URL_CONTAMINANTES" res yes "small nuclear"
    bash scripts/index.sh res/contaminants.fasta res/contaminants_idx
fi

# ==============================================================================
# PASO 3: Fusionar Réplicas Técnicas
# ==============================================================================
echo "Paso 3: Fusionando réplicas técnicas..."
IDS_MUESTRAS=$(ls data/*.fastq.gz | xargs -n 1 basename | cut -d"-" -f1 | sort | uniq)

for sid in $IDS_MUESTRAS; do
    if [ -f "out/merged/${sid}.fastq.gz" ]; then
        echo "  > Fusión para $sid ya existe. Saltando..."
    else
        bash scripts/merge_fastqs.sh data out/merged "$sid"
    fi
done

# ==============================================================================
# PASO 4: Análisis (Recorte y Alineamiento)
# ==============================================================================
echo "Paso 4: Ejecutando Cutadapt y STAR..."

for fname in out/merged/*.fastq.gz; do
    sid=$(basename "$fname" .fastq.gz)
    echo "Procesando muestra: $sid"
    echo "Muestra: $sid" >> "$LOGFILE"

    # --- 4.1 Cutadapt ---
    mkdir -p out/trimmed
    ARCHIVO_RECORTADO="out/trimmed/${sid}.trimmed.fastq.gz"
    LOG_CUTADAPT="log/cutadapt/${sid}.log"
    
    if [ -f "$ARCHIVO_RECORTADO" ]; then
        echo "  > Cutadapt ya ejecutado para $sid. Saltando..."
    else
        cutadapt -m 18 -a TGGAATTCTCGGGTGCCAAGG --discard-untrimmed \
                 -o "$ARCHIVO_RECORTADO" "$fname" > "$LOG_CUTADAPT"
    fi

    # --- 4.2 STAR ---
    mkdir -p "out/star/$sid"
    PREFIJO_STAR="out/star/$sid/"
    ARCHIVO_BAM="${PREFIJO_STAR}Aligned.sortedByCoord.out.bam"

    if [ -f "$ARCHIVO_BAM" ]; then
        echo "  > Alineamiento STAR ya ejecutado para $sid. Saltando..."
    else
        STAR --runThreadN 4 --genomeDir res/contaminants_idx \
             --outReadsUnmapped Fastx --readFilesIn "$ARCHIVO_RECORTADO" \
             --readFilesCommand zcat --outFileNamePrefix "$PREFIJO_STAR" \
             --outSAMtype BAM SortedByCoordinate --outSAMmode NoQS > /dev/null
    fi

    # --- 4.3 Logging ---
    echo "  [Métricas Cutadapt]" >> "$LOGFILE"
    if [ -f "$LOG_CUTADAPT" ]; then
        grep "Reads with adapters:" "$LOG_CUTADAPT" >> "$LOGFILE" || true
        grep "Total basepairs processed:" "$LOG_CUTADAPT" >> "$LOGFILE" || true
    fi
    
    echo "  [Métricas STAR]" >> "$LOGFILE"
    LOG_FINAL_STAR="${PREFIJO_STAR}Log.final.out"
    if [ -f "$LOG_FINAL_STAR" ]; then
        grep "Uniquely mapped reads %" "$LOG_FINAL_STAR" >> "$LOGFILE" || true
        grep "% of reads mapped to multiple loci" "$LOG_FINAL_STAR" >> "$LOGFILE" || true
        grep "% of reads mapped to too many loci" "$LOG_FINAL_STAR" >> "$LOGFILE" || true
    fi
    echo "------------------------------------------------" >> "$LOGFILE"
done

echo "Pipeline finalizado con éxito."
