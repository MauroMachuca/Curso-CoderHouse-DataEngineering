-- Consulta final exigida en la rúbrica: JOIN entre el stream en vivo (caliente) y el histórico (frío)
SELECT
    live.user_id,
    live.action_type AS accion_actual,
    hist.action AS accion_historica,
    live.event_time
FROM analytics_consumption.sensor_events_parsed live
JOIN lakehouse_iceberg.clicks_iceberg hist
  ON live.user_id = hist.user
ORDER BY live.event_time DESC
LIMIT 20;