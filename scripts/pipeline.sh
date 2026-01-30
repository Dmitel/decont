#!/bin/bash
# scripts/pipeline.sh
# Pipeline principal de ejecución para el proyecto de descontaminación

set -e # Detener si hay errores

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

# Descargar todas las muestras listadas
for url in $(cat data/urls); do
    bash scripts/download.sh "$url" data
done


# ==============================================================================
# PASO 2: Preparar Base de Datos de Contaminantes
# ==============================================================================
echo "Paso 2: Preparando referencia de contaminantes..."

# URL del archivo FASTA de contaminantes
# TODO: Verificar que el enlace es correcto antes de entregar
URL_CONTAMINANTES="https://masterbioinformatica.com/decont/contaminants.fasta.gz"

# Descargar y filtrar contaminantes.
# NOTA: Filtramos específicamente "small nuclear" para eliminar snRNAs
# respetando los snoRNAs (small nucleolar), según requisitos del enunciado.
bash scripts/download.sh "$URL_CONTAMINANTES" res yes "small nuclear"

# Indexar el archivo de contaminantes limpio para STAR
bash scripts/index.sh res/contaminants.fasta res/contaminants_idx


# ==============================================================================
# PASO 3: Fusionar Réplicas Técnicas
# ==============================================================================
echo "Paso 3: Fusionando réplicas técnicas..."

# Extraer IDs únicos de las muestras (ej: SRR88...)
IDS_MUESTRAS=$(ls data/*.fastq.gz | xargs -n 1 basename | cut -d"-" -f1 | sort | uniq)

for sid in $IDS_MUESTRAS; do
    bash scripts/merge_fastqs.sh data out/merged "$sid"
done


# ==============================================================================
# PASO 4: Análisis (Recorte y Alineamiento)
# ==============================================================================
echo "Paso 4: Ejecutando Cutadapt y STAR..."

for fname in out/merged/*.fastq.gz; do
    
    # Extraer ID de la muestra
    sid=$(basename "$fname" .fastq.gz)
    
    echo "Procesando muestra: $sid"
    echo "Muestra: $sid" >> "$LOGFILE"

    # --- 4.1 Cutadapt (Limpieza) ---
    mkdir -p out/trimmed
    ARCHIVO_RECORTADO="out/trimmed/${sid}.trimmed.fastq.gz"
    LOG_CUTADAPT="log/cutadapt/${sid}.log"
    
    # Secuencia adaptadora proporcionada en el enunciado
    cutadapt -m 18 -a TGGAATTCTCGGGTGCCAAGG --discard-untrimmed \
             -o "$ARCHIVO_RECORTADO" "$fname" > "$LOG_CUTADAPT"

    # --- 4.2 STAR (Alineamiento) ---
    mkdir -p "out/star/$sid"
    PREFIJO_STAR="out/star/$sid/"
    
    # Alinear lecturas contra el índice de contaminantes
    STAR --runThreadN 4 --genomeDir res/contaminants_idx \
         --outReadsUnmapped Fastx --readFilesIn "$ARCHIVO_RECORTADO" \
         --readFilesCommand zcat --outFileNamePrefix "$PREFIJO_STAR" \
         --outSAMtype BAM SortedByCoordinate --outSAMmode NoQS > /dev/null

    # --- 4.3 Logging (Extracción de métricas) ---
    # Añadimos las estadísticas al archivo de log único
    
    echo "  [Métricas Cutadapt]" >> "$LOGFILE"
    grep "Reads with adapters:" "$LOG_CUTADAPT" >> "$LOGFILE"
    grep "Total basepairs processed:" "$LOG_CUTADAPT" >> "$LOGFILE"
    
    echo "  [Métricas STAR]" >> "$LOGFILE"
    LOG_FINAL_STAR="${PREFIJO_STAR}Log.final.out"
    grep "Uniquely mapped reads %" "$LOG_FINAL_STAR" >> "$LOGFILE"
    grep "% of reads mapped to multiple loci" "$LOG_FINAL_STAR" >> "$LOGFILE"
    grep "% of reads mapped to too many loci" "$LOG_FINAL_STAR" >> "$LOGFILE"
    
    echo "------------------------------------------------" >> "$LOGFILE"
done

echo "Pipeline finalizado con éxito. Ver detalles en $LOGFILE"
