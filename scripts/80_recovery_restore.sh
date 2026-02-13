#!/usr/bin/env bash
# set -e: Detiene el script si falla un comando.
# set -u: Lanza error si se usa una variable no definida.
# set -o pipefail: Asegura que los fallos en tuberías sean detectados.
set -euo pipefail

# --- CONFIGURACIÓN DE COMPATIBILIDAD ---
# Crucial para Git Bash en Windows: evita que se traduzcan rutas de Linux a Windows
# al interactuar con los comandos de Docker.
export MSYS_NO_PATHCONV=1

# Nombre del contenedor del NameNode (por defecto 'namenode').
NN_CONTAINER=${NN_CONTAINER:-namenode}
# Fecha de trabajo para las auditorías (AAAA-MM-DD).
DT=${DT:-$(date +%F)}

echo "[recovery] Iniciando fase de recuperación para DT=$DT"

# --- 1. IDENTIFICACIÓN DEL NODO CAÍDO ---
# Buscamos contenedores que estén en estado 'exited' (apagados).
# Filtramos por los nombres comunes de los DataNodes en este laboratorio.
DN_TO_RECOVER=$(docker ps -a --filter "status=exited" --format "{{.Names}}" | grep -E "dnnm-1|datanode1" | head -n 1)

# Si el comando anterior no devuelve nada (porque el nodo ya se borró o cambió),
# asignamos un nombre por defecto para intentar levantarlo.
if [ -z "$DN_TO_RECOVER" ]; then
    DN_TO_RECOVER="clustera-dnnm-1"
fi

# --- 2. RECUPERACIÓN FÍSICA ---
echo "[recovery] Paso 1: Reiniciando el nodo: $DN_TO_RECOVER..."
# Levantamos el contenedor. Si ya estaba encendido, el '|| echo' evita que el script falle.
docker start "$DN_TO_RECOVER" || echo "El nodo ya estaba encendido o el nombre varió."

# 

# --- 3. RECONEXIÓN Y REPLICACIÓN ---
# Cuando un DataNode vuelve, debe reportarse al NameNode y sincronizar sus bloques.
# Le damos un margen de tiempo para que esta comunicación se estabilice.
echo "[recovery] Paso 2: Esperando 15 segundos para la sincronización de bloques..."
sleep 15

# --- 4. AUDITORÍA DE SALUD FINAL (FSCK) ---
echo "[recovery] Paso 3: Ejecutando auditoría de salud final..."
docker exec -i "$NN_CONTAINER" bash -lc "
    # Generamos un reporte detallado de los bloques tras la vuelta del nodo.
    echo '--- REPORTE POST-RECUPERACIÓN ---' > /tmp/recovery_report.txt
    hdfs fsck /data -files -blocks >> /tmp/recovery_report.txt
    
    # Creamos la carpeta de evidencias en HDFS y guardamos el reporte.
    hdfs dfs -mkdir -p /audit/recovery/$DT
    hdfs dfs -put -f /tmp/recovery_report.txt /audit/recovery/$DT/health_check.txt
    
    echo -e '\\n--- RESUMEN DE SALUD ---'
    # Filtramos el estado (Debe ser HEALTHY) y verificamos que ya no falten réplicas.
    grep 'Status:' /tmp/recovery_report.txt
    grep 'Under-replicated' /tmp/recovery_report.txt
"

# --- 5. VALIDACIÓN DE CONSISTENCIA DE DATOS ---
echo "[recovery] Paso 4: Validando consistencia con el Backup..."
# Verificamos que tras el "accidente", los archivos en la zona activa (/data) 
# siguen coincidiendo en número con nuestra copia de seguridad (/backup).
docker exec -i "$NN_CONTAINER" bash -lc "
    echo -e '\\nComparando archivos en /data vs /backup tras el incidente:'
    count_data=\$(hdfs dfs -ls -R /data | grep 'dt=$DT' | wc -l)
    count_backup=\$(hdfs dfs -ls -R /backup | grep 'dt=$DT' | wc -l)
    echo \"Archivos en Data: \$count_data | Archivos en Backup: \$count_backup\"
"

echo -e "\n[recovery] Sistema recuperado y verificado."