#!/usr/bin/env bash
# set -e: Detiene el script si un comando falla.
# set -u: Lanza error si se intenta usar una variable no definida.
# set -o pipefail: Asegura que los errores en tuberías (|) se capturen.
set -euo pipefail

# --- CONFIGURACIÓN DE COMPATIBILIDAD ---
# Crucial para Git Bash en Windows: evita que se intenten traducir rutas de Linux
# a rutas locales de Windows al interactuar con Docker.
export MSYS_NO_PATHCONV=1

# Nombre del contenedor del NameNode (por defecto 'namenode').
NN_CONTAINER=${NN_CONTAINER:-namenode}

echo "[incident] Iniciando simulación de incidente..."

# --- 1. DETECCIÓN DEL TARGET ---
# Buscamos dinámicamente el nombre del contenedor del primer DataNode.
# Filtramos por los nombres estándar 'dnnm-1' o 'datanode1'.
DN_TO_KILL=$(docker ps --format "{{.Names}}" | grep -E "dnnm-1|datanode1" | head -n 1)

# Si no encontramos ningún contenedor activo que coincida, abortamos el script.
if [ -z "$DN_TO_KILL" ]; then
    echo "[incident] ERROR: No se encontró el contenedor del DataNode activo."
    exit 1
fi

# --- 2. VERIFICACIÓN DEL ESTADO SANO ---
echo "[incident] Paso 1: Verificando estado inicial (SANO)"
# Comprobamos cuántos DataNodes están "vivos" antes de provocar el fallo.
docker exec -i "$NN_CONTAINER" hdfs dfsadmin -report | grep "Live datanodes"

# 

# --- 3. SIMULACIÓN DE FALLO DE HARDWARE ---
echo "[incident] Paso 2: Provocando caída del nodo: $DN_TO_KILL..."
# 'docker stop' simula un apagado repentino o una pérdida de conexión de red del nodo.
docker stop "$DN_TO_KILL"

# --- 4. TIEMPO DE REACCIÓN DEL CLÚSTER ---
# Hadoop tarda un tiempo en notar que un nodo no envía su "heartbeat" (latido).
echo "[incident] Esperando 10 segundos para que el NameNode registre la ausencia..."
sleep 10

# --- 5. GENERACIÓN DE EVIDENCIA DE IMPACTO ---
echo "[incident] Paso 3: Generando reporte de auditoría del incidente..."
# Ejecutamos un análisis de salud (FSCK) para ver el impacto en la replicación.
docker exec -i "$NN_CONTAINER" bash -lc "
    # Creamos la carpeta de incidentes en HDFS si no existe.
    hdfs dfs -mkdir -p /audit/incident/
    
    # Ejecutamos FSCK. Aquí veremos bloques 'Under-replicated' porque ha desaparecido una copia.
    hdfs fsck /data -files -blocks -locations > /tmp/incidente_report.txt
    
    # Guardamos el reporte como evidencia técnica en HDFS.
    hdfs dfs -put -f /tmp/incidente_report.txt /audit/incident/reporte_fallo.txt
    
    echo -e '\n--- RESULTADO DURANTE EL INCIDENTE ---'
    # Mostramos el estado (Debería seguir HEALTHY si hay réplicas, pero con avisos).
    grep 'Status:' /tmp/incidente_report.txt
    # Mostramos cuántos bloques han perdido su nivel de replicación deseado.
    grep 'Under-replicated' /tmp/incidente_report.txt
    
    echo -n 'Nodos activos actualmente: '
    hdfs dfsadmin -report | grep 'Live datanodes'
"

echo -e "\n[incident] Simulación completada."
# Instrucción importante para que el usuario sepa cómo volver a la normalidad.
echo "[incident] IMPORTANTE: Para recuperar el sistema ejecuta: docker start $DN_TO_KILL"