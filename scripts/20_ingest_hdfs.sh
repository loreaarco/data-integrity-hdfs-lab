#!/usr/bin/env bash
# set -e: El script se detiene si un comando falla.
# set -u: El script falla si se intenta usar una variable no definida.
# set -o pipefail: Captura errores en comandos encadenados por tuberías (|).
set -euo pipefail

# --- CONFIGURACIÓN DE COMPATIBILIDAD ---
# Crucial para usuarios de Windows con Git Bash. Evita que el shell intente
# convertir rutas como /data en rutas de Windows tipo C:\Git\data.
export MSYS_NO_PATHCONV=1

# --- VARIABLES DE ENTORNO ---
# Nombre del contenedor del NameNode (por defecto 'namenode').
NN_CONTAINER=${NN_CONTAINER:-namenode}
# Fecha de ejecución. Se usa para organizar los datos en carpetas (particionado).
DT=${DT:-$(date +%F)}

# Ruta absoluta en tu PC donde el script 10_generate_data.sh guardó los archivos.
LOCAL_DIR=${LOCAL_DIR:-"C:/Users/lorea/Desktop/clase/Big-Data-Aplicado/Proyecto_integridad_hdfs/data-integrity-hdfs-lab/notebooks/$DT"}

# Formateo de nombres de archivo: elimina los guiones de la fecha (ej: 20260212)
# para coincidir con el formato de salida del script de generación.
LOG_FILE="logs_${DT//-/}.log"
IOT_FILE="iot_${DT//-/}.jsonl"

echo "[ingest] DT=$DT"
echo "[ingest] Local dir=$LOCAL_DIR"

# --- 1) PREPARAR DIRECTORIOS EN HDFS ---
# Crea las carpetas de destino dentro del sistema de archivos de Hadoop.
# 'hdfs dfs -mkdir -p' crea toda la jerarquía de carpetas si no existe.
echo "[ingest] Preparando directorios en HDFS..."
docker exec -i "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p /data/logs/raw/dt=$DT /data/iot/raw/dt=$DT"

# 

# --- 2) SUBIR ARCHIVOS AL CLÚSTER ---
# Procedimiento en dos pasos:
# A. Copiar del PC al almacenamiento temporal del contenedor Docker (/tmp).
# B. Mover del contenedor al sistema HDFS distribuido.

echo "[ingest] Copiando Logs al contenedor..."
docker cp "$LOCAL_DIR/$LOG_FILE" "$NN_CONTAINER:/tmp/$LOG_FILE"
docker exec -i "$NN_CONTAINER" bash -lc "hdfs dfs -put -f /tmp/$LOG_FILE /data/logs/raw/dt=$DT/"

echo "[ingest] Copiando IoT al contenedor..."
docker cp "$LOCAL_DIR/$IOT_FILE" "$NN_CONTAINER:/tmp/$IOT_FILE"
docker exec -i "$NN_CONTAINER" bash -lc "hdfs dfs -put -f /tmp/$IOT_FILE /data/iot/raw/dt=$DT/"

# --- 3) LIMPIEZA DE ESPACIO ---
# Es una buena práctica borrar los archivos de /tmp dentro del contenedor una vez subidos
# a HDFS para no llenar el almacenamiento de la capa de Docker.
echo "[ingest] Limpiando archivos temporales en el contenedor (como root)..."
docker exec -i --user root "$NN_CONTAINER" bash -c "rm -f /tmp/logs_*.log /tmp/iot_*.jsonl"

# --- 4) VERIFICACIÓN ---
# Ejecuta un listado recursivo (-ls -R) y muestra el tamaño de los archivos (-du -h)
# para confirmar que los datos están ocupando espacio en el clúster.
echo "[ingest] Verificando archivos en HDFS..."
docker exec -i "$NN_CONTAINER" bash -lc "hdfs dfs -ls -R /data && hdfs dfs -du -h /data"

echo "[ingest] ¡Ingesta completada con éxito!"