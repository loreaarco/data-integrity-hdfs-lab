#!/usr/bin/env bash
# set -e: Detiene el script si un comando falla.
# set -u: Lanza error si se usa una variable no definida.
# set -o pipefail: Detecta fallos en cualquier comando de una tubería (|).
set -euo pipefail

# --- VARIABLES DE CONFIGURACIÓN ---
# Nombre del contenedor del NameNode (por defecto 'namenode').
NN_CONTAINER=${NN_CONTAINER:-namenode}
# Fecha de trabajo para filtrar los datos (AAAA-MM-DD).
DT=${DT:-$(date +%F)}

echo "[inventory] DT=$DT"

# 1. DEFINICIÓN DE RUTAS A COMPARAR
# Establecemos los puntos de montaje lógicos dentro de HDFS.
DATA_PATH="/data"
BACKUP_PATH="/backup"

# 

# 2. GENERACIÓN DE INVENTARIOS DETALLADOS
echo "[inventory] Generando listado de archivos y tamaños..."
# Entramos al contenedor para listar archivos.
# awk extrae la columna 8 (nombre) y la 5 (tamaño en bytes) del comando 'ls -R'.
docker exec -i "$NN_CONTAINER" bash -lc "
    echo '--- INVENTARIO ORIGEN ($DATA_PATH) ---' > /tmp/inv_data.txt
    hdfs dfs -ls -R $DATA_PATH | grep 'dt=$DT' | awk '{print \$8 \" - Size: \" \$5}' >> /tmp/inv_data.txt
    
    echo '--- INVENTARIO BACKUP ($BACKUP_PATH) ---' > /tmp/inv_backup.txt
    hdfs dfs -ls -R $BACKUP_PATH | grep 'dt=$DT' | awk '{print \$8 \" - Size: \" \$5}' >> /tmp/inv_backup.txt
"

# 3. COMPARAR INVENTARIOS (RESUMEN EJECUTIVO)
echo "[inventory] Comparando origen vs destino..."
docker exec -i "$NN_CONTAINER" bash -lc "
    echo '--- REPORTE DE DISCREPANCIAS ---' > /tmp/discrepancias.txt
    echo 'Resumen de tamaños totales:' >> /tmp/discrepancias.txt
    
    # hdfs dfs -du -s -h: Muestra el tamaño total sumado (-s) en formato legible (-h).
    hdfs dfs -du -s -h $DATA_PATH/logs/raw/dt=$DT >> /tmp/discrepancias.txt
    hdfs dfs -du -s -h $BACKUP_PATH/logs/raw/dt=$DT >> /tmp/discrepancias.txt
    
    echo -e '\nConteo de archivos:' >> /tmp/discrepancias.txt
    
    # Contamos las líneas (wc -l) tras filtrar por la fecha para saber cuántos ficheros hay.
    echo -n 'Archivos en Data: ' >> /tmp/discrepancias.txt
    hdfs dfs -ls -R $DATA_PATH | grep 'dt=$DT' | wc -l >> /tmp/discrepancias.txt
    
    echo -n 'Archivos en Backup: ' >> /tmp/discrepancias.txt
    hdfs dfs -ls -R $BACKUP_PATH | grep 'dt=$DT' | wc -l >> /tmp/discrepancias.txt
"

# 4. GUARDAR EVIDENCIAS Y PERSISTENCIA
echo "[inventory] Guardando evidencias de inventario en HDFS..."
docker exec -i "$NN_CONTAINER" bash -lc "
    # Creamos el directorio de auditoría específico para la fecha si no existe.
    hdfs dfs -mkdir -p /audit/inventory/$DT/
    
    # Subimos los archivos temporales generados al sistema HDFS para su archivo histórico.
    hdfs dfs -put -f /tmp/inv_data.txt /audit/inventory/$DT/origen.txt
    hdfs dfs -put -f /tmp/inv_backup.txt /audit/inventory/$DT/destino.txt
    hdfs dfs -put -f /tmp/discrepancias.txt /audit/inventory/$DT/reporte_comparativo.txt
    
    # Mostramos el reporte de discrepancias final por la consola estándar.
    cat /tmp/discrepancias.txt
"

echo "[inventory] Inventario completado. Revisa /audit/inventory/$DT/reporte_comparativo.txt"