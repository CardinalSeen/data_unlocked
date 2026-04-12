-- 1. Create Schemas
-- to determine the layers of the ETL
-- raw = original source data
-- stg = cleaned / standardized data
-- mart = final reporting tables

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS mart;
CREATE SCHEMA IF NOT EXISTS reporting;