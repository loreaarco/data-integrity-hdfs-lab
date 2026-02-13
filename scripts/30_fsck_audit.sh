#!/usr/bin/env bash
# set -e: Detiene la ejecución si un comando falla.
# set -u: Lanza error si se usa una variable no definida.
# set -o pipefail: El script falla si cualquier comando en una tubería falla.
set -euo pipefail

# --- CONFIGURACIÓN DE VARIABLES ---

# Nombre del contenedor del NameNode. Si no se indica, usa 'namenode'.
NN_CONTAINER=${NN_CONTAINER:-namenode}

# Fecha de trabajo. Si no se indica, usa la fecha actual (AAAA-MM-DD).
DT=${DT:-$(date +%F)}

# Ruta dentro del contenedor que está mapeada con tu carpeta de Notebooks.
JUPYTER_PATH="/media/notebooks"

# Crucial para Git Bash en Windows: evita que se traduzcan rutas de Linux a Windows
# (evita que /audit se convierta en C:\Program Files\Git\audit).
export MSYS_NO_PATHCONV=1

echo "[fsck] Iniciando auditoría para la fecha: $DT"

# --- 1. PREPARACIÓN DE DIRECTORIOS ---

echo "[fsck] Creando carpetas de destino..."
# Creamos la carpeta en el sistema de archivos distribuido (HDFS).
docker exec -i "$NN_CONTAINER" hdfs dfs -mkdir -p "/audit/fsck/$DT"

# Creamos la carpeta en el sistema de archivos local del contenedor (volumen de Jupyter).
docker exec -i "$NN_CONTAINER" bash -c "mkdir -p ${JUPYTER_PATH}/${DT}"

# --- 2. EJECUCIÓN DEL CHEQUEO DE INTEGRIDAD (FSCK) ---

echo "[fsck] Analizando integridad de bloques..."
# hdfs fsck: Verifica la salud de los bloques, su ubicación y si faltan réplicas.
# Analizamos la carpeta principal /data y guardamos el reporte en /tmp.
docker exec -i "$NN_CONTAINER" bash -c "hdfs fsck /data -files -blocks -locations > /tmp/fsck_report.txt"

# Intentamos analizar también la carpeta /backup. Si no existe, añadimos una nota al reporte.
docker exec -i "$NN_CONTAINER" bash -c "hdfs fsck /backup -files -blocks -locations >> /tmp/fsck_report.txt 2>/dev/null || echo -e '\n--- INFO ---\nNo hay backup aun en /backup' >> /tmp/fsck_report.txt"

# 

# --- 3. EXPORTACIÓN DE REPORTES DETALLADOS ---

echo "[fsck] Exportando reportes detallados..."
# Subimos el reporte completo a HDFS para que quede registro histórico en el clúster.
docker exec -i "$NN_CONTAINER" hdfs dfs -put -f /tmp/fsck_report.txt "/audit/fsck/$DT/fsck_report.txt"

# Copiamos el mismo reporte al volumen compartido para que sea accesible desde el Notebook.
docker exec -i "$NN_CONTAINER" bash -c "cp /tmp/fsck_report.txt ${JUPYTER_PATH}/${DT}/fsck_data.txt"

# --- 4. GENERACIÓN DE RESUMEN EJECUTIVO ---

echo "[fsck] Generando resumen para el Dashboard..."
# Creamos un archivo más pequeño (resumen.txt) con las métricas clave usando 'grep'.
docker exec -i "$NN_CONTAINER" bash -c "
    echo '--- RESUMEN DE INTEGRIDAD $DT ---' > /tmp/resumen.txt
    echo \"Fecha de escaneo: \$(date)\" >> /tmp/resumen.txt
    echo '--------------------------------' >> /tmp/resumen.txt
    
    # Extraemos el Estado (HEALTHY/CORRUPT), bloques totales y alertas de replicación.
    grep 'Status:' /tmp/fsck_report.txt >> /tmp/resumen.txt || echo 'Status: N/A' >> /tmp/resumen.txt
    grep 'Total blocks' /tmp/fsck_report.txt >> /tmp/resumen.txt || echo 'Blocks: 0' >> /tmp/resumen.txt
    grep -i 'CORRUPT' /tmp/fsck_report.txt >> /tmp/resumen.txt || true
    grep -i 'MISSING' /tmp/fsck_report.txt >> /tmp/resumen.txt || true
    grep -i 'Under-replicated' /tmp/fsck_report.txt >> /tmp/resumen.txt || true
    
    # Guardamos este resumen tanto en HDFS como en la carpeta de Jupyter.
    hdfs dfs -put -f /tmp/resumen.txt /audit/fsck/$DT/resumen_auditoria.txt
    cp /tmp/resumen.txt ${JUPYTER_PATH}/${DT}/resumen.txt
"

echo -e "\n[fsck] Auditoría finalizada con éxito."
echo "[fsck] Los datos deberían ser visibles en Jupyter en: $JUPYTER_PATH/$DT"