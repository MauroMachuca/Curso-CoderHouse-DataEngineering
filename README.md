# Proyecto Integrador: Plataforma de Muestreo Urbano en Tiempo Real

Plataforma de procesamiento de datos distribuidos utilizando Kubernetes, Apache Kafka y Apache Spark Structured Streaming para el análisis de métricas de calidad del aire y temperatura en entornos urbanos.

## Arquitectura

```mermaid
flowchart LR
    A[Script Productor Python] -->|Eventos JSON| B(Kafka Topic: urban_sensors)
    B --> C[Apache Spark Streaming]
    C -->|Agregación 1 min| D[Consola / Salida]
    
    subgraph Kubernetes Namespace: smart-city
    B
    Z[Zookeeper] -.-> B
    end