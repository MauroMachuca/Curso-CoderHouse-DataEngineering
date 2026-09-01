# Proyecto Integrador: Data Engineering (AWS & Kubernetes)

Este repositorio contiene la evolución de la infraestructura y el procesamiento de datos del curso, combinando despliegues en la nube de AWS mediante Terraform (Kinesis, Flink, S3) y procesamiento distribuido local con Kubernetes (Kafka, Spark).

## Estructura del Repositorio Completo

```text
/
├── environments/dev/             # Entorno de desarrollo Terraform (AWS)
├── modules/                      # Módulos de Infraestructura como Código (HCL)
│   ├── identity/                 # IAM Roles y Políticas
│   ├── network/                  # VPC y S3 Gateway Endpoints
│   └── flink/                    # Infraestructura de Apache Flink (Pre-entrega 4)
├── k8s/                          # Manifiestos de Kubernetes (Pre-entrega 3)
│   ├── 00-namespace.yaml
│   ├── 01-configmap.yaml
│   ├── 02-zookeeper.yaml
│   └── 03-kafka.yaml
├── src/                          
│   └── flink_processor.py        # Script de Apache Flink (AWS)
├── sensor_producer.py            # Productor Kafka (Python)
├── spark_sensor_processor.py     # Job de Spark Structured Streaming
└── README.md