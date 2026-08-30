import os
from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col, window, avg, to_timestamp
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, IntegerType
import pyspark


# LECTURA DE VARIABLES DE ENTORNO
KAFKA_SERVER = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
TOPIC_NAME = os.getenv('KAFKA_TOPIC', 'urban_sensors')


# Detecta automáticamente la versión de PySpark (ej. 3.5.1 -> 2.13)
spark_version = pyspark.__version__
scala_version = "2.13" if spark_version >= "3.5" else "2.12"

spark = SparkSession.builder \
    .appName("UrbanSensorStreaming") \
    .config("spark.jars.packages", f"org.apache.spark:spark-sql-kafka-0-10_{scala_version}:{spark_version}") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN") # Reduce el ruido visual en la consola

# 2. DEFINIR EL ESQUEMA (ESTRICTO)
# En Structured Streaming es obligatorio definir el esquema para evitar latencias de inferencia
sensor_schema = StructType([
    StructField("sensor_id", StringType(), True),
    StructField("temperature", DoubleType(), True),
    StructField("humidity", DoubleType(), True),
    StructField("air_quality_index", IntegerType(), True),
    StructField("timestamp", StringType(), True)
])

# 3. LECTURA DEL STREAM DESDE KAFKA
raw_stream = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", KAFKA_SERVER) \
    .option("subscribe", TOPIC_NAME) \
    .option("startingOffsets", "latest") \
    .load()

# 4. DESSERIALIZACIÓN Y TRANSFORMACIÓN
# Convierte el valor binario a STRING, parsea el JSON y castea el texto a tipo Timestamp
parsed_stream = raw_stream \
    .selectExpr("CAST(value AS STRING) as json_str") \
    .select(from_json(col("json_str"), sensor_schema).alias("data")) \
    .select("data.*") \
    .withColumn("event_time", to_timestamp(col("timestamp"), "yyyy-MM-dd HH:mm:ss"))

# 5. AGREGACIÓN CON VENTANA TEMPORAL (WINDOWING)
aggregated_metrics = parsed_stream \
    .groupBy(
        window(col("event_time"), "1 minute"), 
        col("sensor_id")                        
    ) \
    .agg(
        avg("temperature").alias("avg_temperature"),
        avg("air_quality_index").alias("avg_air_quality")
    )

# 6. ESCRITURA Y SALIDA DEL STREAMING
query = aggregated_metrics.writeStream \
    .outputMode("complete") \
    .format("console") \
    .option("truncate", "false") \
    .start()

query.awaitTermination() # Mantiene vivo el proceso de streaming