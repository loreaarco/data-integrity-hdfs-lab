#!/usr/bin/env bash
# 'set -e' detiene el script si un comando falla.
# 'set -u' da error si se intenta usar una variable no definida.
# 'set -o pipefail' asegura que si un comando en un pipe (|) falla, todo el pipe falle.
set -euo pipefail

# --- CONFIGURACIÓN DE VARIABLES ---
# Si la variable NN_CONTAINER no está definida, toma 'namenode' por defecto.
NN_CONTAINER=${NN_CONTAINER:-namenode}

# Si la variable DT no está definida, genera la fecha actual en formato AAAA-MM-DD..
DT=${DT:-$(date +%F)}

echo "[bootstrap] DT=$DT"
echo "[bootstrap] Configurando estructura HDFS base..."

# --- FASE 1: CREACIÓN DE DIRECTORIOS EN HDFS ---

# Se utiliza 'docker exec' para entrar en el contenedor del NameNode.
# 'bash -lc' carga el perfil del shell (importante para que reconozca el comando 'hdfs').
# Se usa un "Here Document" (cat <<EOF) para enviar múltiples líneas de comandos al contenedor.

docker exec -i $NN_CONTAINER bash -lc "$(cat <<EOF 
echo '[HDFS] Creando estructura base...'


# -mkdir -p crea la ruta completa y no da error si ya existe (idempotencia).
# Estructura de ingesta de datos brutos (raw) particionados por fecha.
hdfs dfs -mkdir -p /data/logs/raw/dt=$DT
hdfs dfs -mkdir -p /data/iot/raw/dt=$DT

# Estructura para copias de seguridad (Backup).
hdfs dfs -mkdir -p /backup/logs/raw/dt=$DT
hdfs dfs -mkdir -p /backup/iot/raw/dt=$DT

# Estructura para reportes de auditoría de salud (FSCK) e inventario.
hdfs dfs -mkdir -p /audit/fsck/$DT
hdfs dfs -mkdir -p /audit/inventory/$DT

echo '[HDFS] Estructura creada.'
EOF
)"

# --- FASE 2: VERIFICACIÓN ---

# Comprobamos que las carpetas realmente se han creado listando el contenido de HDFS.
docker exec -i $NN_CONTAINER bash -lc "$(cat <<EOF
echo '[HDFS] Verificando estructura:'

# Listado de las rutas principales para confirmar la existencia de las nuevas carpetas.
hdfs dfs -ls /data/logs/raw/
hdfs dfs -ls /data/iot/raw/

hdfs dfs -ls /backup
hdfs dfs -ls /audit
EOF
)"


echo "[bootstrap] TODO completarlo."
