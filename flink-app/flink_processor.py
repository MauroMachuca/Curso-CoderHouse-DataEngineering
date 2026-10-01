import os
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import StreamTableEnvironment

import traceback
import sys

def main():
    try:
        # 1. Configurar el entorno con Checkpointing habilitado (Vital para commits de Iceberg)
        env = StreamExecutionEnvironment.get_execution_environment()
        env.enable_checkpointing(60000) # Checkpoint cada 1 minuto
        
        t_env = StreamTableEnvironment.create(env)
        
        stream_name = os.environ.get("STREAM_NAME", "sensor-stream-dev")
        region = os.environ.get("AWS_REGION", "us-east-1")
        bucket_name = os.environ.get("S3_BUCKET", "datalake-raw-dev-652086271803")
        
        # 2. Configurar el Catálogo de Glue para Iceberg
        print(f"Creating catalog for bucket {bucket_name}", file=sys.stderr)
        t_env.execute_sql(f"""
            CREATE CATALOG glue_catalog WITH (
              'type'='iceberg',
              'warehouse'='s3://{bucket_name}/iceberg-warehouse',
              'catalog-impl'='org.apache.iceberg.aws.glue.GlueCatalog',
              'io-impl'='org.apache.iceberg.aws.s3.S3FileIO'
            )
        """)
        
        # 3. Definir la tabla origen (Kinesis)
        print(f"Creating Kinesis source for stream {stream_name}", file=sys.stderr)
        t_env.execute_sql(f"""
            CREATE TABLE kinesis_source (
                `sensor_id` STRING,
                `temperature` DOUBLE,
                `humidity` DOUBLE,
                `air_quality_index` INT,
                `timestamp` STRING,
                `event_time` AS TO_TIMESTAMP(`timestamp`, 'yyyy-MM-dd HH:mm:ss'),
                WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND
            ) WITH (
                'connector' = 'kinesis',
                'stream' = '{stream_name}',
                'aws.region' = '{region}',
                'scan.stream.initpos' = 'LATEST',
                'format' = 'json'
            )
        """)
        
        # 4. Crear la tabla destino Iceberg en Glue (Si no existe)
        print(f"Creating Iceberg sink table", file=sys.stderr)
        t_env.execute_sql("""
            CREATE TABLE IF NOT EXISTS glue_catalog.lakehouse_db.sensor_events (
                `sensor_id` STRING,
                `temperature` DOUBLE,
                `humidity` DOUBLE,
                `air_quality_index` INT,
                `event_time` TIMESTAMP(3)
            ) PARTITIONED BY (YEAR(event_time), MONTH(event_time), DAY(event_time), HOUR(event_time))
        """)
        
        # 5. Insertar datos en streaming hacia Iceberg (IcebergSink SQL)
        print(f"Executing INSERT statement", file=sys.stderr)
        table_result = t_env.execute_sql("""
            INSERT INTO glue_catalog.lakehouse_db.sensor_events
            SELECT 
                `sensor_id`, 
                `temperature`, 
                `humidity`,
                `air_quality_index`,
                `event_time`
            FROM kinesis_source
        """)
        print("Waiting for streaming job to run...", file=sys.stderr)
        table_result.wait()
        print("Script finished successfully", file=sys.stderr)
    except Exception as e:
        print(f"PYTHON SCRIPT FAILED: {str(e)}", file=sys.stderr)
        traceback.print_exc(file=sys.stderr)
        # Raise to make sure Flink knows it failed
        raise e

if __name__ == '__main__':
    main()