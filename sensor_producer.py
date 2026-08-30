import json
import time
import random
import os
from datetime import datetime
from kafka import KafkaProducer

# 1. LECTURA DE CONFIGURACIÓN
# Se obtienen los parámetros desde las variables del sistema (ConfigMap)
KAFKA_SERVER = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
TOPIC_NAME = os.getenv('KAFKA_TOPIC', 'urban_sensors')

# 2. INICIALIZACIÓN DEL PRODUCTOR
producer = KafkaProducer(
    bootstrap_servers=[KAFKA_SERVER],
    # Serialización: convierte un objeto diccionario de Python a JSON UTF-8 codificado en bytes
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

sensores = [f"sensor_zona_{i}" for i in range(1, 6)] # Genera 5 IDs de sensores fijos

try:
    while True:
        sensor_id = random.choice(sensores) # Selección aleatoria para simular concurrencia
        
        payload = {
            "sensor_id": sensor_id,
            "temperature": round(random.uniform(15.0, 38.0), 2),
            "humidity": round(random.uniform(30.0, 90.0), 2),
            "air_quality_index": "Error",
            "timestamp": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
        }
        
        # Publicación en Kafka:
        # La 'key' se envía codificada a bytes. Garantiza que todos los datos de un 'sensor_id' 
        # vayan siempre a la misma partición de Kafka.
        producer.send(
            TOPIC_NAME, 
            key=sensor_id.encode('utf-8'), 
            value=payload
        )
        
        print(f"📡 Evento emitido a Kafka: {payload}")
        time.sleep(0.5) # Emisión cada 500ms
        
except KeyboardInterrupt:
    print("Deteniendo productor...")
finally:
    # Fuerza el envío de cualquier mensaje residual en el búfer de memoria
    producer.flush()