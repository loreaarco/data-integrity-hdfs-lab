#!/usr/bin/env bash
# set -e: Detiene el script si falla un comando.
# set -u: Error si se usa una variable no definida.
# set -o pipefail: El script falla si falla cualquier comando en una tubería (|).
set -euo pipefail

# --- CONFIGURACIÓN DE RUTAS ---
# Define la ruta base de salida. Se usa el formato de Git Bash (/c/...) para compatibilidad en Windows.
# Si la variable OUT_DIR ya existe, la respeta; si no, usa la ruta por defecto.
OUT_DIR=${OUT_DIR:-"/c/Users/lorea/Desktop/clase/Big-Data-Aplicado/Proyecto_integridad_hdfs/data-integrity-hdfs-lab/notebooks"}
# Define la fecha de trabajo (YYYY-MM-DD). Por defecto es la fecha actual del sistema.
DT=${DT:-$(date +%F)}

# Crea el directorio físico en el disco duro. El parámetro -p evita errores si la carpeta ya existe.
mkdir -p "$OUT_DIR/$DT"

# --- DEFINICIÓN DE ARCHIVOS ---
# Genera nombres de archivo dinámicos. 
# ${DT//-/} elimina los guiones de la fecha (ej: 2026-02-12 se convierte en 20260212).
LOG_FILE="$OUT_DIR/$DT/logs_${DT//-/}.log"
IOT_FILE="$OUT_DIR/$DT/iot_${DT//-/}.jsonl"

# -- 1. GENERACIÓN DE LOGS DE SERVIDOR (3.000.000 líneas) --
echo "[generate] Creando logs (Modo Rápido)..."
# Usamos Perl por ser significativamente más rápido que un bucle 'for' en Bash para millones de líneas.
perl -e '
    my @actions = ("GET", "POST", "DELETE", "PUT");  # Métodos HTTP aleatorios
    my @status = ("200", "404", "500", "201");       # Códigos de estado aleatorios
    my $ts = time();                                 # Timestamp actual
    open(my $fh, ">", $ARGV[0]);                     # Abre el archivo de destino (pasado por argumento)
    for (1..3000000) {                               # Bucle de 3 millones
        printf $fh "%d user_%d %s %s\n", 
            $ts, int(rand(100)), $actions[int(rand(4))], $status[int(rand(4))];
    }
    close($fh);
' "$LOG_FILE"

# -- 2. GENERACIÓN DE DATOS IOT EN JSONL (6.000.000 líneas) --
echo "[generate] Creando datos IoT (Modo Rápido)..."
# Generamos el doble de datos para simular una carga pesada de sensores.
perl -e '
    my @metrics = ("temp", "hum", "press", "volt");  # Tipos de métricas de sensores
    my $ts = time();                                 # Timestamp actual
    open(my $fh, ">", $ARGV[0]);                     # Abre el archivo de destino
    for (1..6000000) {                               # Bucle de 6 millones
        # Genera una línea en formato JSON Lines (JSONL)
        printf $fh "{\"deviceId\": \"sensor_%d\", \"ts\": %d, \"metric\": \"%s\", \"value\": %d}\n", 
            int(rand(50)), $ts, $metrics[int(rand(4))], int(rand(100));
    }
    close($fh);
' "$IOT_FILE"

# --- FINALIZACIÓN ---
echo "[generate] ¡Hecho! Datos generados exitosamente."
echo "[generate] Tamaño total del dataset:"
# Muestra el peso total de los archivos generados en formato legible (ej: 450MB).
du -sh "$OUT_DIR/$DT"