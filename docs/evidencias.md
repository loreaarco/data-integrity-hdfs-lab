# Evidencias (plantilla)

Incluye aquí (capturas o logs) con fecha:

## 1\) NameNode UI (9870)

* Captura con DataNodes vivos y capacidad
![Los nodos que estan vivos y su capacidad (9870) (2026-02-13)](image.png)
![00_bootstrap.sh (comprobación de la creación) (2026-02-13)](image-1.png)
![10_generate_data.sh (comprobación de la creación) (2026-02-13)](image-2.png)
## 2\) Auditoría fsck

* Enlace/captura de salida (bloques/locations)
* Resumen (CORRUPT/MISSING/UNDER\_REPLICATED)

![20_ingest_hdfs.sh (comprobación de la creación)  (2026-02-13)](image-3.png)
![iot  (2026-02-13) ](image-4.png) 
![log (2026-02-13)](image-5.png)

* /data/iot/raw/dt=2026-02-13 en (8070)
* /data/logs/raw/dt=2026-02-13 en (8070)

![30_fsck_audit.sh  (comprobación de la creación) (2026-02-13)](image-6.png)
![En jupyter (8889) (2026-02-13)](image-7.png)

![Comprobación si exite el archivo (2026-02-13)](image-8.png)
![Comprobación de palabras claves  (2026-02-13)](image-9.png)
![Creación archivo csv  (2026-02-13)](image-10.png)

## 3\) Backup + validación

* Inventario origen vs destino
* Evidencias de consistencia (tamaños/rutas)

![40_backup_copy.sh (comprobación de la creación) (2026-02-13)](image-12.png)

![Backup de iot /backup/iot/raw/dt=2026-02-13  (2026-02-13)](image-13.png)
![Backup de logs /backup/logs/raw/dt=2026-02-13  (2026-02-13)](image-14.png)

![Producción de iot  /data/iot/raw/dt=2026-02-13  (2026-02-13)](image-15.png)
![Producción de logs /data/logs/raw/dt=2026-02-13  (2026-02-13)](image-16.png)

![50_inventory_compare.sh (comprobación de la creación) (2026-02-13)](image-17.png)
![Evidencia que esta en la ruta que dice el Bash /audit/inventory/2026-02-13  (2026-02-13)](image-18.png)

## 4\) Incidente + recuperación

* Qué hiciste, cuándo y qué efecto tuvo
* Evidencia de detección y de recuperación

* Para simular el incidente, detuve forzosamente un contenedor DataNode con docker stop, lo que provocó que el NameNode detectara la pérdida de réplicas y marcara los bloques de datos como "Under-replicated". Posteriormente, recuperé la salud del sistema reiniciando el nodo con docker start, permitiendo que HDFS sincronizara automáticamente las copias faltantes y restaurara el estado "HEALTHY".

![70_incident_simulation.sh (comprobación de la ejecucion) (2026-02-13)](image-19.png)
![Evidencia de la detencion del nodo (2026-02-13)](image-20.png)

![80_recovery_restore.sh (comprobación de la ejecucion) (2026-02-13)](image-21.png)
![Evidencia de la recuperacion del nodo (2026-02-13)](image-22.png)

## 5\) Métricas

* Capturas de docker stats durante replicación/copia
* Tabla de tiempos

![docker stats durante la copia/replicación (2026-02-13)](image-11.png)

## Tabla de tiempos

| Orden | Script | Fase | Descripción Clave | Tiempo Est. |
| :--- | :--- | :--- | :--- | :--- |
| **1** | `00_bootstrap.sh` | **Infraestructura** | Preparación de rutas base en HDFS (`/data`, `/backup`, `/audit`). | < 5 seg |
| **2** | `10_generate_data.sh` | **Generación** | Creación masiva de 9M de registros (Logs e IoT) usando Perl. | 15 - 30 seg |
| **3** | `20_ingest_hdfs.sh` | **Ingesta** | Transferencia de archivos local -> Contenedor -> HDFS. | 30 - 60 seg |
| **4** | `30_fsck_audit.sh` | **Auditoría** | Análisis de salud de bloques y exportación de reportes a Jupyter. | 10 seg |
| **5** | `40_backup_copy.sh` | **Respaldo** | Duplicación de datos de producción a la zona de seguridad. | 20 - 40 seg |
| **6** | `50_inventory_compare.sh`| **Validación** | Cruce de inventarios origen vs destino para verificar consistencia. | 10 seg |
| **7** | `70_incident_simulation.sh` | **Incidente** | Caída forzada de un DataNode y captura de métricas degradadas. | 15 seg |
| **8** | `80_recovery_restore.sh` | **Recuperación** | Reinicio de infraestructura y verificación de auto-sanación. | 20 seg |