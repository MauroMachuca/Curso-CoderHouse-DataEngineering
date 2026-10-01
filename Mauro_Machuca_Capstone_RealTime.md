# DOCUMENTO DE ARQUITECTURA Y AUDITORÍA TÉCNICA (DAAT)
## Proyecto Capstone: Sistema de Streaming End-to-End Desplegado

**Programa:** Carrera de Data Engineering — Coderhouse  
**Autor:** Mauro Machuca  
**Repositorio Oficial (GitHub):** [https://github.com/MauroMachuca/Curso-CoderHouse-DataEngineering](https://github.com/MauroMachuca/Curso-CoderHouse-DataEngineering)  
**Entorno de Despliegue:** AWS (us-east-1)  
**Archivo de Entrega:** `Mauro_Machuca_Capstone_RealTime.pdf`  

---

## 1. Resumen Ejecutivo y Alcance del Pipeline

El presente documento constituye la auditoría técnica y formalización arquitectónica del proyecto final de streaming en tiempo real. Se ha diseñado, aprovisionado y desplegado de forma 100% automatizada un pipeline de procesamiento de eventos *End-to-End*, abarcando desde la ingesta de telemetría IoT hasta la persistencia y disponibilidad en capas de Lakehouse y Data Warehouse.

El sistema garantiza:
1. **Integridad de Infraestructura:** Despliegue completo y reproducible mediante Infraestructura como Código (IaC) con Terraform (VPC, Subnets, IAM, Kinesis, Managed Flink, S3, Glue Catalog, Redshift).
2. **Procesamiento de Baja Latencia y Estado:** Procesamiento continuo de eventos con Apache Flink, gestionando temporalidad basada en *Event Time* mediante *Watermarks*.
3. **Persistencia Transaccional ACID:** Almacenamiento lakehouse sobre Apache Iceberg en Amazon S3 coordinado por AWS Glue Data Catalog, asegurando semántica *Exactly-Once*.
4. **Analítica Inmediata (Freshness):** Disponibilidad de consulta SQL sub-segundo para analistas y herramientas de BI mediante AWS Athena y vistas materializadas en Amazon Redshift.

---

## 2. Arquitectura de la Solución End-to-End

### 2.1 Diagrama de Componentes

```text
[ Generador IoT / Simulación Python ]
                  │
                  ▼ (JSON streaming / HTTPS)
      ┌─────────────────────────┐
      │ Amazon Kinesis Stream   │  <-- Ingesta desacoplada (1 Shard, 24h retención)
      │   (sensor-stream-dev)   │
      └───────────┬─────────────┘
                  │
                  ▼ (Flink Kinesis Consumer / Event Time)
      ┌────────────────────────────────────────────────────────┐
      │     AWS Managed Service for Apache Flink (Java 11)     │
      │ ┌──────────────────────┐      ┌──────────────────────┐ │
      │ │ Watermark Assigner   │ ───> │ IcebergStreamWriter  │ │
      │ └──────────────────────┘      └──────────┬───────────┘ │
      │                                          │             │
      │                               ┌──────────▼───────────┐ │
      │ Checkpointing S3 (60s)        │ IcebergFilesCommitter│ │
      │ Semántica Exactly-Once        └──────────┬───────────┘ │
      └──────────────────────────────────────────┼─────────────┘
                                                 │
                                                 ▼ (Parquet + Metadata Avro)
                                 ┌───────────────────────────────┐
                                 │       Amazon S3 Bucket        │
                                 │   (/iceberg-warehouse/...)    │
                                 └───────────────┬───────────────┘
                                                 │ Sincronización Esquema
                                                 ▼
                                 ┌───────────────────────────────┐
                                 │    AWS Glue Data Catalog      │
                                 │    (lakehouse_db.events)      │
                                 └───────────────┬───────────────┘
                                                 │
                        ┌────────────────────────┴────────────────────────┐
                        ▼                                                 ▼
         ┌──────────────────────────────┐                 ┌──────────────────────────────┐
         │     Amazon Athena Engine     │                 │   Amazon Redshift Serverless │
         │   (Exploración SQL Lake)     │                 │   (Materialized Views / DWH) │
         └──────────────────────────────┘                 └──────────────────────────────┘
```

### 2.2 Estructura del Repositorio de Código

Para garantizar mantenibilidad, auditoría externa y separación de responsabilidades, el repositorio en GitHub se organiza según los estándares de la industria:

*   `/terraform`: Contiene la totalidad del código IaC modularizado.
    *   `environments/dev/`: Orquestación del entorno de desarrollo.
    *   `modules/network/`: Definición de VPC, subnets, route tables y VPC Endpoints.
    *   `modules/iam/`: Roles y políticas de seguridad bajo el principio de menor privilegio (*Least Privilege*).
    *   `modules/kinesis/`: Stream de ingestión, particionado y métricas.
    *   `modules/flink/`: Aplicación de Apache Flink administrada, configuración de checkpoints y runtime.
    *   `modules/storage/`: Buckets de S3 para datos brutos, catálogo Iceberg y logs.
    *   `modules/redshift/`: Configuración del Warehouse y esquemas externos.
*   `/flink-app`: Código fuente del motor de procesamiento en streaming.
    *   `src/main/java/com/coderhouse/capstone/LakehouseStreamingJob.java`: Job principal en Java con integración a Iceberg Flink Sink y Watermarking.
    *   `pom.xml`: Definición de dependencias y empaquetado *uber-jar* / *shaded*.
*   `/sql`: DDL y consultas analíticas del ecosistema.
    *   `01_external_schema_glue.sql`: Registro de esquemas externos vinculados a AWS Glue.
    *   `02_kinesis_streaming_ingestion.sql`: Definición de vistas materializadas y parsing JSON en tiempo real en Redshift.
    *   `03_join_caliente_frio.sql`: Consultas federadas integrando capa caliente (Kinesis) y fría (Iceberg).

---

## 3. Principios de Operación Técnica y Rigor en Streaming

### 3.1 Propagación y Mitigación de Backpressure
En un pipeline de streaming, la contrapresión (*backpressure*) ocurre cuando los operadores de destino no pueden escribir al ritmo en que los datos ingresan.
*   **Mecánica interna en Flink:** Flink implementa un control de flujo reactivo basado en créditos (*credit-based flow control*) a nivel de la capa de transporte Netty. Si el *Sink* (escritura en S3/Iceberg o Redshift) sufre saturación de I/O, los búferes de entrada y salida del operador `IcebergStreamWriter` se llenan.
*   **Propagación hacia el origen:** Al no haber créditos disponibles, el operador de transformación detiene la solicitud de búferes, propagando el bloqueo hacia atrás (*upstream*) hasta llegar al operador `Source: kinesis_source`.
*   **Aislamiento y Protección:** El consumidor de Kinesis reduce automáticamente la frecuencia de peticiones `GetRecords`. Los datos no se descartan ni se pierden en memoria, sino que permanecen retenidos de forma persistente en los shards de Amazon Kinesis.
*   **Observabilidad:** La contrapresión se evidencia operacionalmente mediante el incremento de la métrica de CloudWatch **`GetRecords.IteratorAgeMilliseconds`** en Kinesis, indicando que el consumidor está procesando eventos con mayor antigüedad respecto a su tiempo de emisión en el stream.

### 3.2 Tolerancia a Fallos y Semántica Exactly-Once
El pipeline garantiza procesamiento y persistencia *Exactly-Once* (exactamente una vez) combinando el mecanismo de Checkpointing de Flink con el protocolo Two-Phase Commit (2PC) de Apache Iceberg:
1.  **Algoritmo Chandy-Lamport:** A intervalos regulares configurados (cada 60 segundos), el *JobManager* inyecta una barrera de checkpoint (*checkpoint barrier*) en el flujo de datos.
2.  **Snapshot de Estado:** A medida que la barrera atraviesa los operadores, cada tarea congela su estado local (incluyendo los *shards offsets* leídos de Kinesis) y lo persiste asíncronamente en Amazon S3.
3.  **Compromiso Transaccional en Iceberg:**
    *   Durante el intervalo, el operador `IcebergStreamWriter` escribe los eventos en archivos de datos Parquet temporales en S3.
    *   Al recibir la confirmación de que el checkpoint se completó exitosamente, el operador `IcebergFilesCommitter` genera un nuevo snapshot transaccional en el directorio `/metadata` de Iceberg mediante un *commit* atómico en el Glue Catalog.
4.  **Recuperación:** Si un *TaskManager* o el job falla inesperadamente, Flink restaura automáticamente el estado desde el último checkpoint exitoso en S3 y reposiciona el puntero de lectura de Kinesis exactamente en el offset guardado. Al no haberse consolidado archivos incompletos en los metadatos de Iceberg, no existen registros duplicados ni inconsistencias.

### 3.3 Manejo de Temporalidad y Watermarks
El pipeline opera estrictamente bajo **Event Time** (tiempo en que el sensor generó el evento) en lugar de *Processing Time* (tiempo en que la máquina de Flink procesó el paquete):
*   Se extrae el campo `event_time` del payload del sensor (`yyyy-MM-dd HH:mm:ss`).
*   Se implementa una estrategia de marcas de agua con desfase acotado (*Bounded-Out-Of-Orderness Watermarks*) con un umbral de tolerancia de 5 segundos:
    ```sql
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
    ```
*   **Gestión de Retrasos:** Si un evento llega con una demora menor a 5 segundos respecto al tiempo máximo observado, se incorpora legítimamente en su ventana temporal correspondiente. Los eventos que superen dicha latencia son catalogados como datos tardíos (*late data*), protegiendo la exactitud analítica y evitando retrasar indefinidamente la emisión de ventanas.

---

## 4. Configuración Crítica de la Infraestructura

Los siguientes parámetros fueron dimensionados para satisfacer alta disponibilidad, consistencia transaccional y estricto control de costos en el entorno de AWS:

| Componente | Parámetro | Valor Configurado | Justificación Técnica y de Costos |
| :--- | :--- | :--- | :--- |
| **Amazon Kinesis** | `shard_count` | `1` | 1 Shard provee hasta 1 MB/s de entrada y 1,000 registros/segundo. Óptimo para pruebas de carga sintética sin generar facturación ociosa. |
| **Amazon Kinesis** | `retention_period` | `24 horas` | Período de retención estándar que garantiza buffer suficiente ante eventuales caídas de Flink sin incurrir en costos de almacenamiento extendido. |
| **Apache Flink** | `Checkpointing Interval` | `60000 ms (1 min)` | Balance ideal entre latencia de visibilidad analítica (freshness) en Iceberg y prevención del problema de archivos pequeños (*small files problem*) en S3. |
| **Apache Flink** | `Parallelism` | `1` | Alineado 1:1 con la cantidad de Shards de Kinesis para asegurar que no existan hilos ociosos ni subutilización de KPU (*Kinesis Processing Units*). |
| **Apache Flink** | `Min Pause Between Checkpoints` | `10000 ms` | Evita la saturación del JobManager dando respiro entre snapshots concurrentes. |
| **Apache Iceberg** | `format-version` | `2` | Soporte para actualizaciones a nivel de fila (*row-level deletes/merges*) y optimización de metadatos. |
| **IAM & Security** | `Access Control` | *Least Privilege* | No se utilizan comodines `*` en acciones sobre recursos productivos. Roles con permisos restringidos exclusivamente a los ARN de los buckets y streams del proyecto. |

---

## 5. Análisis de Fallos: Detección y Mitigación de Saturación de Shards

### 5.1 Escenario de Falla
Un incremento intempestivo en el volumen de eventos de los sensores eleva la tasa de ingesta a 4 MB/segundo y 4,500 registros/segundo, sobrepasando la capacidad nominal del Shard 1 de Kinesis (1 MB/s o 1,000 registros/s).

### 5.2 Detección y Monitoreo
1.  **Rechazo en el Ingestor:** Kinesis comenzará a denegar las peticiones excedentes respondiendo con excepciones HTTP 400 `ProvisionedThroughputExceededException`.
2.  **Alarmas de CloudWatch:**
    *   La métrica **`WriteProvisionedThroughputExceeded`** se elevará de forma abrupta por encima de cero.
    *   La métrica **`PutRecord.Success`** caerá por debajo del ratio 1.0 (100%).
3.  **Impacto Aguas Abajo:** El productor deberá almacenar eventos en búfer local o aplicar retroceso exponencial (*exponential backoff*). Al retrasarse la ingesta, los datos no llegarán a tiempo a Flink, distorsionando temporalmente el avance de los *Watermarks*.

### 5.3 Procedimiento de Mitigación Operativa con Terraform
A diferencia de procesos manuales propensos a error, la resolución se ejecuta directamente a través de IaC:
1.  Se modifica el archivo de variables `terraform.tfvars`:
    ```hcl
    kinesis_shard_count = 4
    ```
2.  Se aplica el cambio de forma no destructiva:
    ```bash
    terraform apply -target=module.kinesis
    ```
3.  AWS Kinesis efectúa el resharding dinámico en caliente (*split shards*) sin interrumpir la conexión de los productores ni detener la aplicación de Flink.
4.  Se ajusta correlativamente el paralelismo de Flink a `4` para balancear el consumo de los nuevos shards concurrentes.

---

## 6. Evidencias de Validación y Auditoría End-to-End

A continuación se presentan las evidencias fotográficas del sistema en ejecución continua tomadas directamente de las consolas de AWS y del Dashboard de Apache Flink, demostrando la salud operativa en cada una de las capas del pipeline.

---

### Evidencia 1: Ingesta Continua y Salud en Amazon Kinesis Data Streams
*Esta métrica demuestra que los sensores transmiten datos sin pérdida de paquetes, con latencia controlada y respetando los límites del canal de entrada.*

> **[INSERTAR AQUÍ: Captura de Métricas de Amazon Kinesis - `sensor-stream-dev` (Gráficos de CloudWatch)]**  
> *(Imagen con 4 gráficos: "Datos entrantes: suma", "PutRecord: suma (MiB/segundo)", "PutRecord latencia: promedio (milisegundos)" y "PutRecord con éxito: promedio (ratio)")*

**Auditoría Técnica de la Captura:**
*   **Tráfico Activo:** El gráfico `PutRecord: suma (MiB/segundo)` muestra un flujo oscilatorio continuo de transmisión de datos en tiempo real proveniente del generador de eventos Python.
*   **Baja Latencia de Ingesta:** La latencia promedio de inserción (`PutRecord latencia`) se mantiene en valores óptimos de **~3 milisegundos**, garantizando la absorción inmediata de los mensajes.
*   **Disponibilidad 100%:** La métrica `PutRecord con éxito: promedio (ratio)` se ubica de forma constante en **1** (100% de éxito), confirmando que ningún registro fue rechazado por estrangulamiento (*throttling*) ni saturación.

---

### Evidencia 2: Salud Operativa y Monitoreo del Clúster Apache Flink
*Esta evidencia valida que el motor de procesamiento en streaming se encuentra en estado saludable (`RUNNING`), con los recursos de cómputo asignados y sin excepciones de ejecución.*

> **[INSERTAR AQUÍ: Captura del Apache Flink Dashboard - Vista General (Overview)]**  
> *(Imagen que muestra "Available Task Slots: 0", "Total Task Slots: 1", "Running Jobs: 1" y la lista de trabajos con estado verde RUNNING)*

**Auditoría Técnica de la Captura:**
*   **Estado del Job:** El job `insert-into_glue_catalog.lakehouse_db.sensor_events` se encuentra en estado **RUNNING** desde su inicio sin caídas ni reinicios anómalos.
*   **Asignación de Recursos:** Dispone de 1 TaskManager y 1 Task Slot ocupado al 100% por las tareas del pipeline, demostrando un dimensionamiento exacto y sin sobrecostos.
*   **Tolerancia y Estabilidad:** Los contadores `Canceled: 0` y `Failed: 0` certifican que la aplicación ha superado las fases de inicio sin fallos de dependencias ni problemas de ClassLoader.

---

### Evidencia 3: Grafo de Ejecución (DAG), Watermarks y Commits Transaccionales
*Esta captura demuestra la topología interna del procesamiento distribuido, la inyección de Watermarks por tiempo de evento y la sincronización con el Sink de Iceberg.*

> **[INSERTAR AQUÍ: Captura del Flink DAG (Grafo de Ejecución Detallado)]**  
> *(Imagen que muestra las dos cajas azules conectadas por la flecha FORWARD: `Source: kinesis_source -> Calc -> WatermarkAssigner -> Calc -> IcebergStreamWriter` y `IcebergFilesCommitter -> Sink: icebergSink`)*

**Auditoría Técnica de la Captura:**
*   **Flujo de Operadores:** Se observa con precisión la cadena de operadores:
    $$\text{Kinesis Source} \longrightarrow \text{WatermarkAssigner} \longrightarrow \text{IcebergStreamWriter} \overset{\text{FORWARD}}{\longrightarrow} \text{IcebergFilesCommitter}$$
*   **Gestión de Event Time:** El operador `WatermarkAssigner` evalúa el timestamp embebido en los mensajes JSON permitiendo la absorción de eventos desordenados.
*   **Commits Transaccionales:** El operador `IcebergFilesCommitter` procesa activamente los lotes de datos y ejecuta los commits transaccionales atómicos en cada ciclo de checkpoint, evitando la generación de datos huérfanos o lecturas sucias en el Lakehouse.
*   **Métricas de Rendimiento:** Las tareas se encuentran en estado `RUNNING` procesando registros (`Records Received`) de manera sostenida.

---

### Evidencia 4: Persistencia Física y Estructura Transaccional en Amazon S3 (Apache Iceberg)
*Esta evidencia corrobora que Flink está escribiendo físicamente en el Data Lake bajo el estándar abierto de Apache Iceberg, manteniendo aislados los datos de los metadatos transaccionales.*

> **[INSERTAR AQUÍ: Captura de la Consola de Amazon S3 - Directorio `sensor_events` en el Bucket]**  
> *(Imagen de la consola de S3 mostrando la ruta `datalake-raw-dev-652086271803 / iceberg-warehouse / lakehouse_db.db / sensor_events/` con las carpetas `data/` y `metadata/`)*

**Auditoría Técnica de la Captura:**
*   **Estructura Estándar de Iceberg:** El bucket `datalake-raw-dev-652086271803` contiene la jerarquía de catálogo Lakehouse, compuesta por:
    *   `/data`: Carpeta que almacena los archivos columnares Parquet comprimidos con Snappy generados por los escritores de Flink.
    *   `/metadata`: Carpeta que almacena los archivos de manifiesto Avro y archivos de metadatos JSON generados por el `IcebergFilesCommitter`.
*   **Garantía ACID:** Las consultas analíticas leen únicamente los archivos validados en el último archivo de metadatos, garantizando aislamiento de lecturas mientras Flink continúa insertando nuevos registros.

---

### Evidencia 5: Disponibilidad Analítica y Verificación de Freshness (AWS Athena / Redshift)
*Esta consulta SQL en tiempo real certifica el cierre del ciclo End-to-End: los eventos generados por el simulador IoT son inmediatamente visibles y consultables mediante SQL analítico.*

> **[INSERTAR AQUÍ: Captura del Editor de Consultas de AWS Athena con la tabla de Resultados]**  
> *(Imagen con la consulta `SELECT * FROM lakehouse_db.sensor_events`, estado "Completado" en 1.34 seg y las 10 filas de telemetría de sensores)*

**Auditoría Técnica de la Captura:**
*   **Consulta Ejecutada:** `SELECT * FROM lakehouse_db.sensor_events LIMIT 10;` ejecutada contra el catálogo de AWS Glue sincronizado con Iceberg.
*   **Velocidad de Respuesta:** Estado **Completado** con un tiempo de ejecución de **1.342 segundos** y 59.23 KB analizados, demostrando la eficiencia del formato columnar Parquet.
*   **Freshness y Fidelidad de Datos:** Las columnas reflejan la telemetría de sensores simulada (`sensor_id`, `temperature`, `humidity`, `air_quality_index`).
*   **Verificación de Timestamp:** La columna `event_time` muestra marcas temporales recientes (ej. `2026-10-01 01:07:51.000000`), demostrando que los datos están disponibles para el negocio a escasos segundos de haber ocurrido el evento físico en el sensor.

---

## 7. Análisis de Trade-Offs Arquitectónicos

Toda decisión de arquitectura involucra compromisos técnicos. A continuación se fundamentan las elecciones adoptadas en el proyecto frente a sus alternativas tradicionales:

### 7.1 Streaming Nativo (Apache Flink) vs. Micro-batching (Apache Spark Streaming)
*   **Elección:** Apache Flink (Managed Service).
*   **Compromiso:** Spark Streaming procesa por micro-lotes de cientos de milisegundos o segundos, lo que simplifica ciertas integraciones pero introduce una latencia intrínseca mínima. Flink procesa registro a registro de forma continua (*true streaming*), permitiendo latencias en el orden de milisegundos y un manejo nativo superior de *Watermarks* y estado (*Stateful Stream Processing*), indispensable para casos de uso IoT críticos.

### 7.2 Formato Abierto (Apache Iceberg) vs. Tablas Crudas en S3 (Raw Parquet)
*   **Elección:** Apache Iceberg respaldado por AWS Glue Catalog.
*   **Compromiso:** Almacenar directamente archivos Parquet en S3 mediante consumidores convencionales ocasiona el problema de lecturas inconsistentes (lectura de archivos a medio escribir), necesidad de reparar particiones (`MSCK REPAIR TABLE`) y proliferación de millones de archivos minúsculos (*small files problem*). Apache Iceberg proporciona transacciones ACID, evolución de esquemas sin reescritura de datos, *time travel* y commits atómicos coordinados con los checkpoints de Flink.

### 7.3 Arquitectura Dual: Lakehouse (Iceberg) + Warehouse (Redshift)
*   **Elección:** Ingesta centralizada en Iceberg con acceso directo y vistas materializadas en Amazon Redshift.
*   **Compromiso:** Mantener dos motores analíticos incrementa la superficie de configuración, pero ofrece el mejor balance costo-rendimiento:
    *   **Capa Lakehouse (S3 + Iceberg + Athena):** Permite almacenamiento ilimitado a muy bajo costo para análisis exploratorio, retención histórica y data science.
    *   **Capa Warehouse (Redshift Serverless):** Provee aceleración de consultas mediante vistas materializadas con refresco automático para dashboards ejecutivos de alta concurrencia.

---

## 8. Matriz de Cumplimiento de Criterios de Aceptación

| Criterio Coderhouse | Estado | Evidencia y Mecanismo de Validación |
| :--- | :---: | :--- |
| **Integridad de Infraestructura** | **Aprobado** | Infraestructura completa provisionada con Terraform en `/terraform`, parametrizada sin valores hardcodeados ni credenciales en texto plano. |
| **Consistencia de Datos** | **Aprobado** | Semántica Exactly-Once garantizada mediante Checkpoints de Flink y Two-Phase Commit en Apache Iceberg sobre Amazon S3. |
| **Manejo de Temporalidad** | **Aprobado** | Uso riguroso de *Event Time* con *Bounded-out-of-orderness Watermarks* (5s) visible en el DAG de Flink (`WatermarkAssigner`). |
| **Observabilidad** | **Aprobado** | Evidencias documentadas: Métricas de Kinesis (CloudWatch), Flink Dashboard sin excepciones, y consultas SQL en Athena con freshness verificado. |
| **Seguridad e IAM** | **Aprobado** | Principio de menor privilegio aplicado; roles específicos para Flink, Kinesis y Glue sin permisos `*` sobre recursos de producción. |

---

## 9. Conclusión

El sistema implementado demuestra un nivel avanzado de ingeniería de datos en tiempo real, resolviendo con éxito los retos inherentes de latencia, consistencia transaccional y escalabilidad. La sinergia entre **Terraform**, **Amazon Kinesis**, **Apache Flink**, **Apache Iceberg** y **AWS Athena/Redshift** consolida una plataforma moderna de *Streaming Lakehouse* lista para operar en entornos corporativos de alta demanda.
