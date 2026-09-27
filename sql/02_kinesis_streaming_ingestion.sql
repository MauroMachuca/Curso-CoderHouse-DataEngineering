-- 1. Mapear el stream de Kinesis a Redshift
CREATE EXTERNAL SCHEMA kinesis_stream
FROM KINESIS
STREAM 'clicks-ecommerce-dev'
IAM_ROLE default;

-- 2. Crear la vista materializada para parsear el JSON en tiempo real
CREATE MATERIALIZED VIEW analytics_consumption.sensor_events_parsed AUTO REFRESH YES AS
SELECT
    approximate_arrival_timestamp AS event_time,
    JSON_PARSE(kinesis_data)->>'user' AS user_id,
    JSON_PARSE(kinesis_data)->>'action' AS action_type,
    JSON_PARSE(kinesis_data)->>'timestamp' AS original_timestamp
FROM kinesis_stream."clicks-ecommerce-dev";