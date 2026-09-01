import os
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import StreamTableEnvironment

def main():
    # 1. Configurar el entorno con Checkpointing habilitado (Vital para commits de Iceberg)
    env = StreamExecutionEnvironment.get_execution_environment()
    env.enable_checkpointing(60000) # Checkpoint cada 1 minuto
    
    t_env = StreamTableEnvironment.create(env)
    
    stream_name = os.environ.get("STREAM_NAME", "clicks-ecommerce-dev")
    region = os.environ.get("AWS_REGION", "us-east-1")
    bucket_name = os.environ.get("S3_BUCKET", "curso-data-engineering-datalake-raw-prueba")
    
    # 2. Configurar el Catálogo de Glue para Iceberg
    t_env.execute_sql(f"""
        CREATE CATALOG glue_catalog WITH (
          'type'='iceberg',
          'warehouse'='s3a://{bucket_name}/iceberg-warehouse',
          'catalog-impl'='org.apache.iceberg.aws.glue.GlueCatalog',
          'io-impl'='org.apache.iceberg.aws.s3.S3FileIO'
        )
    """)
    
    # 3. Definir la tabla origen (Kinesis)
    t_env.execute_sql(f"""
        CREATE TABLE kinesis_source (
            `user` STRING,
            `action` STRING,
            `timestamp` TIMESTAMP(3),
            WATERMARK FOR `timestamp` AS `timestamp` - INTERVAL '5' SECOND
        ) WITH (
            'connector' = 'kinesis',
            'stream' = '{stream_name}',
            'aws.region' = '{region}',
            'scan.stream.initpos' = 'LATEST',
            'format' = 'json'
        )
    """)
    
    # 4. Crear la tabla destino Iceberg en Glue (Si no existe)
    # Particionada por hora para optimizar consultas (Partition Pruning)
    t_env.execute_sql("""
        CREATE TABLE IF NOT EXISTS glue_catalog.lakehouse_db.clicks_iceberg (
            `user` STRING,
            `action` STRING,
            `event_time` TIMESTAMP(3)
        ) PARTITIONED BY (YEAR(event_time), MONTH(event_time), DAY(event_time), HOUR(event_time))
    """)
    
    # 5. Insertar datos en streaming hacia Iceberg (IcebergSink SQL)
    t_env.execute_sql("""
        INSERT INTO glue_catalog.lakehouse_db.clicks_iceberg
        SELECT 
            `user`, 
            `action`, 
            `timestamp`
        FROM kinesis_source
    """)

if __name__ == '__main__':
    main()