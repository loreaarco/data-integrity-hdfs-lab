#!/usr/bin/env bash
# set -e: Detiene el script si un comando falla.
# set -u: Lanza error si se usa una variable no definida.
# set -o pipefail: Asegura que los errores en tuberías (|) se detecten correctamente.
set -euo pipefail

# --- EXPLICACIÓN DE VARIANTES ---
# Variante A (este script): Copia interna usando 'hdfs dfs -cp'.
# Variante B (producción real): Se usaría 'distcp' para copiar entre clústeres físicos distintos.

# Nombre del contenedor NameNode (por defecto 'namenode').
NN_CONTAINER=${NN_CONTAINER:-namenode}
# Fecha de trabajo (AAAA-MM-DD).
DT=${DT:-$(date +%F)}

echo "[backup] DT=$DT"

# --- 1. DEFINICIÓN DE RUTAS DE ORIGEN Y DESTINO ---
# Definimos dónde están los datos actuales (Source) y dónde queremos respaldarlos (Destination).
LOGS_SRC="/data/logs/raw/dt=$DT"
IOT_SRC="/data/iot/raw/dt=$DT"

LOGS_DST="/backup/logs/raw/dt=$DT"
IOT_DST="/backup/iot/raw/dt=$DT"

# 

# --- 2. EJECUCIÓN DE LA COPIA EN HDFS ---
# Ejecutamos comandos de Hadoop dentro del contenedor.
# Se usa 'hdfs dfs -cp -f' para forzar la copia y asegurar la idempotencia (si el archivo ya existe, lo sobrescribe).

echo "[backup] Copiando datos de Logs..."
# Primero aseguramos que el directorio de destino existe y luego copiamos todo el contenido (*)
docker exec -i "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p $LOGS_DST && hdfs dfs -cp -f $LOGS_SRC/* $LOGS_DST/"

echo "[backup] Copiando datos de IoT..."
docker exec -i "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p $IOT_DST && hdfs dfs -cp -f $IOT_SRC/* $IOT_DST/"

# --- 3. VALIDACIÓN Y REGISTRO (LOGS DE AUDITORÍA) ---
echo "[backup] Validando consistencia del backup..."

# Generamos un informe de texto que compara visualmente ambas rutas.
docker exec -i "$NN_CONTAINER" bash -lc "
    # Crear un archivo temporal para el reporte
    echo '--- REPORTE DE BACKUP $DT ---' > /tmp/backup_val.txt
    
    echo 'ORIGEN (Producción):' >> /tmp/backup_val.txt
    hdfs dfs -ls -R /data | grep 'dt=$DT' >> /tmp/backup_val.txt
    
    echo -e '\nDESTINO (Backup):' >> /tmp/backup_val.txt
    hdfs dfs -ls -R /backup | grep 'dt=$DT' >> /tmp/backup_val.txt
    
    # --- 4. PERSISTENCIA DE EVIDENCIAS ---
    # Subimos el reporte generado a la carpeta de auditoría en HDFS para cumplimiento (compliance).
    hdfs dfs -put -f /tmp/backup_val.txt /audit/inventory/$DT/backup_validation.txt
    
    # Imprimir el reporte en la terminal para que el usuario lo vea de inmediato
    cat /tmp/backup_val.txt
"

echo "[backup] Proceso finalizado. Evidencias guardadas en /audit/inventory/$DT/"