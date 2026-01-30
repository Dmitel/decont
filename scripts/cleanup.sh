#!/bin/bash
# scripts/cleanup.sh
# Uso: bash scripts/cleanup.sh [data] [resources] [output] [logs]
# Si no se pasan argumentos, borra todo.

# 1. Definir qué borrar
# Si el número de argumentos ($#) es 0, definimos la lista completa.
if [ $# -eq 0 ]; then
    echo "Sin argumentos: Se borrará TODO (data, resources, output, logs)."
    TARGETS="data resources output logs"
else
    # Si hay argumentos, usamos la lista que ha pasado el usuario ($@)
    TARGETS="$@"
    echo "Modo selectivo: Se borrará solo -> $TARGETS"
fi

# 2. Bucle para procesar cada objetivo
for item in $TARGETS; do
    case "$item" in
        "data")
            # Borramos solo los fastq descargados, NO el archivo urls
            rm -f data/*.fastq.gz
            echo " [OK] Limpiado: data (muestras)"
            ;;
        "resources")
            # Borramos carpeta de recursos (contaminantes e índices)
            rm -rf res/
            echo " [OK] Limpiado: resources"
            ;;
        "output")
            # Borramos resultados (merged, trimmed, star)
            rm -rf out/
            echo " [OK] Limpiado: output"
            ;;
        "logs")
            # Borramos logs
            rm -rf log/
            echo " [OK] Limpiado: logs"
            ;;
        *)
            echo " [AVISO] Argumento desconocido: '$item'. Ignorando."
            ;;
    esac
done

echo "Limpieza finalizada."
