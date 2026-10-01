import json
import time
import random
import boto3
from datetime import datetime

# 1. CONFIGURACIÓN DE AWS KINESIS
STREAM_NAME = 'sensor-stream-dev'
REGION = 'us-east-1'

# 2. INICIALIZACIÓN DEL CLIENTE DE KINESIS
# Utilizará automáticamente las credenciales de AWS configuradas en tu entorno local (las mismas de Terraform)
kinesis_client = boto3.client('kinesis', region_name=REGION)

sensores = [f"sensor_zona_{i}" for i in range(1, 6)]

print(f"Iniciando productor hacia Kinesis Stream: {STREAM_NAME}...")

try:
    while True:
        sensor_id = random.choice(sensores)
        
        payload = {
            "sensor_id": sensor_id,
            "temperature": round(random.uniform(15.0, 38.0), 2),
            "humidity": round(random.uniform(30.0, 90.0), 2),
            "air_quality_index": random.randint(0, 500),  
            "timestamp": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
        }
        
        # Publicación en Kinesis
        response = kinesis_client.put_record(
            StreamName=STREAM_NAME,
            Data=json.dumps(payload),
            PartitionKey=sensor_id
        )
        
        print(f"📡 Evento emitido a Kinesis | ShardId: {response['ShardId']} | Payload: {payload}")
        time.sleep(0.5)
        
except KeyboardInterrupt:
    print("Deteniendo productor de Kinesis...")
except Exception as e:
    print(f"Error: {e}")