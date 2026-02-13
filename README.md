#  Proyecto: Data Integrity & Disaster Recovery en HDFS


------------------------------------------------------------------------

#  Scripts del Proyecto

## Fase 1: Preparación e Ingesta
- bash 00_bootstrap.sh: 
    Configura la estructura base de directorios en HDFS (/data, /backup, /audit).

- bash 10_generate_data.sh: 
    Genera localmente 3 millones de líneas de logs y datos IoT en formato JSONL.

- bash 20_ingest_hdfs.sh: 
    Sube los archivos generados al NameNode y los distribuye en HDFS.

## Fase 2: Auditoría y Seguridad
- bash 30_fsck_audit.sh: 
    Realiza un chequeo de salud del sistema de archivos (hdfs fsck) y exporta reportes al volumen de Jupyter.

-bash 40_backup_copy.sh: 
    Crea una copia de seguridad interna de los datos dentro de HDFS.

-bash 50_inventory_compare.sh: 
    Compara el inventario de la carpeta original frente al backup para validar la consistencia.

## Fase 3: Resiliencia y Recuperación
-bash 70_incident_simulation.sh: 
    Simula un fallo deteniendo un contenedor DataNode y genera evidencias del estado de sub-replicación.

-bash 80_recovery_restore.sh: 
    Reinicia la infraestructura caída y verifica que Hadoop recupere la integridad de los bloques.

------------------------------------------------------------------------

# 🛡 Características Técnicas

-   Uso de variables dinámicas (DT)
-   Idempotencia (-mkdir -p, -put -f)
-   Evidencias almacenadas en HDFS
-   Auditoría automatizada
-   Simulación realista de incidente
-   Validación post-recuperación

------------------------------------------------------------------------
