package com.coderhouse.capstone;

import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.iceberg.catalog.Namespace;
import org.apache.iceberg.flink.CatalogLoader;
import org.apache.iceberg.flink.FlinkCatalog;
import org.apache.hadoop.conf.Configuration;

import java.util.HashMap;
import java.util.Map;

public class LakehouseStreamingJob {
    public static void main(String[] args) throws Exception {
        System.out.println("Starting LakehouseStreamingJob initialization...");
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.enableCheckpointing(60000);

        StreamTableEnvironment tEnv = StreamTableEnvironment.create(env);

        String streamName = System.getenv("STREAM_NAME") != null ? System.getenv("STREAM_NAME") : "sensor-stream-dev";
        String region = System.getenv("AWS_REGION") != null ? System.getenv("AWS_REGION") : "us-east-1";
        String bucketName = System.getenv("S3_BUCKET") != null ? System.getenv("S3_BUCKET") : "datalake-raw-dev-652086271803";

        // 1. Instanciar directamente el FlinkCatalog con GlueCatalog sin llamar a HadoopUtils
        System.out.println("Registering GlueCatalog directly for bucket: " + bucketName);
        Map<String, String> properties = new HashMap<>();
        properties.put("type", "iceberg");
        properties.put("warehouse", "s3://" + bucketName + "/iceberg-warehouse");
        properties.put("catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog");
        properties.put("io-impl", "org.apache.iceberg.aws.s3.S3FileIO");

        Configuration hadoopConf = new Configuration();
        CatalogLoader catalogLoader = CatalogLoader.custom(
            "glue_catalog",
            properties,
            hadoopConf,
            "org.apache.iceberg.aws.glue.GlueCatalog"
        );

        FlinkCatalog flinkCatalog = new FlinkCatalog(
            "glue_catalog",
            "default",
            Namespace.empty(),
            catalogLoader,
            true,
            -1L
        );

        tEnv.registerCatalog("glue_catalog", flinkCatalog);
        System.out.println("GlueCatalog registered successfully!");

        // 2. Kinesis Source
        System.out.println("Creating Kinesis source table for stream: " + streamName);
        tEnv.executeSql(
            "CREATE TABLE kinesis_source (" +
            "  `sensor_id` STRING," +
            "  `temperature` DOUBLE," +
            "  `humidity` DOUBLE," +
            "  `air_quality_index` INT," +
            "  `timestamp` STRING," +
            "  `event_time` AS TO_TIMESTAMP(`timestamp`, 'yyyy-MM-dd HH:mm:ss')," +
            "  WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND" +
            ") WITH (" +
            "  'connector' = 'kinesis'," +
            "  'stream' = '" + streamName + "'," +
            "  'aws.region' = '" + region + "'," +
            "  'scan.stream.initpos' = 'LATEST'," +
            "  'format' = 'json'" +
            ")"
        );

        // 3. Iceberg Sink Table in Glue
        System.out.println("Creating Iceberg sink table in Glue Catalog");
        tEnv.executeSql(
            "CREATE TABLE IF NOT EXISTS glue_catalog.lakehouse_db.sensor_events (" +
            "  `sensor_id` STRING," +
            "  `temperature` DOUBLE," +
            "  `humidity` DOUBLE," +
            "  `air_quality_index` INT," +
            "  `event_time` TIMESTAMP(3)" +
            ")"
        );

        // 4. Streaming Insert into Iceberg
        System.out.println("Submitting streaming INSERT query into Iceberg");
        tEnv.executeSql(
            "INSERT INTO glue_catalog.lakehouse_db.sensor_events " +
            "SELECT `sensor_id`, `temperature`, `humidity`, `air_quality_index`, `event_time` " +
            "FROM kinesis_source"
        );

        System.out.println("LakehouseStreamingJob pipeline successfully submitted and running!");
    }
}
