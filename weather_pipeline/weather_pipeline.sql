-- 1. Create Schema for Data Engineer
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS mart;

-- 2. For reporting purposes
CREATE SCHEMA IF NOT EXISTS reporting;

-- 3. Create table for weather raw data
CREATE TABLE IF NOT EXISTS raw.weather_api_raw (
    id BIGSERIAL PRIMARY KEY,
    city VARCHAR(100),
    api_payload JSONB,
    extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Check raw data
SELECT *
FROM raw.weather_api_raw
ORDER BY id DESC;

-- 5. Create table for staging data
CREATE TABLE IF NOT EXISTS stg.weather_api_parsed (
    id BIGSERIAL PRIMARY KEY,
    raw_id BIGINT UNIQUE,
    city VARCHAR(100),
    weather_main VARCHAR(100),
    weather_description VARCHAR(255),
    temperature_c NUMERIC(5,2),
    feels_like_c NUMERIC(5,2),
    humidity INT,
    pressure INT,
    wind_speed NUMERIC(6,2),
    observation_time TIMESTAMP,
    parsed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_weather_raw
        FOREIGN KEY (raw_id) REFERENCES raw.weather_api_raw(id)
);

-- 6. Load raw JSON data into staging table
INSERT INTO stg.weather_api_parsed (
    raw_id,
    city,
    weather_main,
    weather_description,
    temperature_c,
    feels_like_c,
    humidity,
    pressure,
    wind_speed,
    observation_time
)
SELECT
    r.id AS raw_id,
    r.city,
    r.api_payload -> 'weather' -> 0 ->> 'main' AS weather_main,
    r.api_payload -> 'weather' -> 0 ->> 'description' AS weather_description,
    (r.api_payload -> 'main' ->> 'temp')::NUMERIC(5,2) AS temperature_c,
    (r.api_payload -> 'main' ->> 'feels_like')::NUMERIC(5,2) AS feels_like_c,
    (r.api_payload -> 'main' ->> 'humidity')::INT AS humidity,
    (r.api_payload -> 'main' ->> 'pressure')::INT AS pressure,
    (r.api_payload -> 'wind' ->> 'speed')::NUMERIC(6,2) AS wind_speed,
    TO_TIMESTAMP((r.api_payload ->> 'dt')::BIGINT) AS observation_time
FROM raw.weather_api_raw r
LEFT JOIN stg.weather_api_parsed s
    ON r.id = s.raw_id
WHERE s.raw_id IS NULL;


-- 7. Check staging data
SELECT *
FROM stg.weather_api_parsed
ORDER BY id DESC;

-- 8. Create table for mart data
CREATE TABLE IF NOT EXISTS mart.weather_daily_summary (
    id BIGSERIAL PRIMARY KEY,
    city VARCHAR(100),
    weather_date DATE,
    avg_temperature_c NUMERIC(5,2),
    min_temperature_c NUMERIC(5,2),
    max_temperature_c NUMERIC(5,2),
    avg_humidity NUMERIC(5,2),
    avg_wind_speed NUMERIC(6,2),
    records_count INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (city, weather_date)
);

-- Alter table for the unique_city_weather_date
ALTER TABLE mart.weather_daily_summary
ADD CONSTRAINT unique_city_weather_date
UNIQUE (city, weather_date);

-- 9. Load staging data into mart table
INSERT INTO mart.weather_daily_summary (
    city,
    weather_date,
    avg_temperature_c,
    min_temperature_c,
    max_temperature_c,
    avg_humidity,
    avg_wind_speed,
    records_count
)
SELECT
    city,
    observation_time::DATE AS weather_date,
    ROUND(AVG(temperature_c), 2) AS avg_temperature_c,
    MIN(temperature_c) AS min_temperature_c,
    MAX(temperature_c) AS max_temperature_c,
    ROUND(AVG(humidity), 2) AS avg_humidity,
    ROUND(AVG(wind_speed), 2) AS avg_wind_speed,
    COUNT(*) AS records_count
FROM stg.weather_api_parsed
GROUP BY
    city,
    observation_time::DATE
ON CONFLICT (city, weather_date)
DO UPDATE SET
    avg_temperature_c = EXCLUDED.avg_temperature_c,
    min_temperature_c = EXCLUDED.min_temperature_c,
    max_temperature_c = EXCLUDED.max_temperature_c,
    avg_humidity = EXCLUDED.avg_humidity,
    avg_wind_speed = EXCLUDED.avg_wind_speed,
    records_count = EXCLUDED.records_count;

SELECT *
FROM mart.weather_daily_summary
ORDER BY weather_date DESC;


-- 10. Create reporting 
CREATE OR REPLACE VIEW reporting.vw_weather_daily_summary AS
SELECT
    city,
    weather_date,
    avg_temperature_c,
    min_temperature_c,
    max_temperature_c,
    avg_humidity,
    avg_wind_speed,
    records_count
FROM mart.weather_daily_summary;


SELECT *
FROM reporting.vw_weather_daily_summary
ORDER BY weather_date DESC, city;

--checking of mart table
SELECT
    city,
    weather_date,
    records_count,
	created_at,
	updated_at
FROM mart.weather_daily_summary
ORDER BY weather_date DESC, city;

--checking of mart table 2
SELECT SUM(records_count) AS total_records_in_mart
FROM mart.weather_daily_summary;

--checking 2
SELECT
    city,
    observation_time::DATE AS weather_date,
    COUNT(*) AS staging_records
FROM stg.weather_api_parsed
GROUP BY
    city,
    observation_time::DATE
ORDER BY
    weather_date DESC,
    city;

-- checking 3

SELECT
    (SELECT MAX(id) FROM raw.weather_api_raw) AS latest_raw_id,
    (SELECT MAX(raw_id) FROM stg.weather_api_parsed) AS latest_staging_raw_id;


-- checking the number of records of raw, staging and mart. 
SELECT COUNT(*) AS raw_count
FROM raw.weather_api_raw;

SELECT COUNT(*) AS staging_count
FROM stg.weather_api_parsed;

SELECT SUM(records_count) AS total_mart_records
FROM mart.weather_daily_summary;


-- Data Quality and Validation
-- 1. This quality check identifies raw weather records that have not yet been processed into the staging layer.
SELECT
    r.id,
    r.city,
    r.extracted_at
FROM raw.weather_api_raw r
LEFT JOIN stg.weather_api_parsed s
    ON r.id = s.raw_id
WHERE s.raw_id IS NULL
ORDER BY r.id;

-- Check duplicate raw_id in staging
SELECT
    raw_id,
    COUNT(*) AS duplicate_count
FROM stg.weather_api_parsed
GROUP BY raw_id
HAVING COUNT(*) > 1;


-- Check null important fields
SELECT *
FROM stg.weather_api_parsed
WHERE city IS NULL
   OR temperature_c IS NULL
   OR humidity IS NULL
   OR observation_time IS NULL;

-- Check if staging and mart total match
SELECT
    (SELECT COUNT(*) FROM stg.weather_api_parsed) AS staging_count,
    (SELECT SUM(records_count) FROM mart.weather_daily_summary) AS mart_total_records;

