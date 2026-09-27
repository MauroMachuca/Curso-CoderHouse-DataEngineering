-- Conectar Redshift con las tablas Iceberg en el catálogo de Glue
CREATE EXTERNAL SCHEMA lakehouse_iceberg
FROM DATA CATALOG
DATABASE 'lakehouse_db'
IAM_ROLE default
CREATE EXTERNAL DATABASE IF NOT EXISTS;