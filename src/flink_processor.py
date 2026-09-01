import json
import os
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors.kinesis import FlinkKinesisConsumer
from pyflink.common.serialization import SimpleStringSchema
from pyflink.common.watermark_strategy import WatermarkStrategy
from pyflink.common.time import Duration
from pyflink.datastream.window import TumblingEventTimeWindows

def main():
    # 1. Configurar el entorno de ejecución
    env = StreamExecutionEnvironment.get_execution_environment()
    
    # 2. Configurar el consumidor de Kinesis
    stream_name = os.environ.get("STREAM_NAME", "clicks-ecommerce-dev")
    region = os.environ.get("AWS_REGION", "us-east-1")
    
    consumer_config = {
        'aws.region': region,
        'flink.stream.initpos': 'LATEST'
    }
    
    kinesis_consumer = FlinkKinesisConsumer(
        stream_name,
        SimpleStringSchema(),
        consumer_config
    )
    
    # 3. Ingesta y Deserialización
    raw_stream = env.add_source(kinesis_consumer)
    
    def parse_event(event_str):
        data = json.loads(event_str)
        # Retorna (usuario, 1, timestamp)
        return (data["user"], 1, data["timestamp"])
        
    parsed_stream = raw_stream.map(parse_event)
    
    # 4. Lógica Temporal (Watermarks y Event Time)
    # Tolerancia de 5 segundos para eventos tardíos (Skews de tiempo)
    watermark_strategy = WatermarkStrategy.for_bounded_out_of_orderness(Duration.of_seconds(5)) \
        .with_timestamp_assigner(lambda event, _: int(event[2][:10])) # Simplificación de Timestamp
        
    watermarked_stream = parsed_stream.assign_timestamps_and_watermarks(watermark_strategy)
    
    # 5. Procesamiento Stateful (Tumbling Window)
    # Agrupamos por usuario y sumamos los clics en ventanas de 1 minuto
    windowed_stream = watermarked_stream \
        .key_by(lambda x: x[0]) \
        .window(TumblingEventTimeWindows.of(Duration.of_minutes(1))) \
        .reduce(lambda a, b: (a[0], a[1] + b[1], a[2]))
        
    # 6. Salida (En un entorno real iría a otro stream o S3. Aquí lo imprimimos en logs de CloudWatch)
    windowed_stream.print()
    
    env.execute("Flink Stateful Kinesis Processor")

if __name__ == '__main__':
    main()