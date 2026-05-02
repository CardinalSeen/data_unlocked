-- 1. Create Schema for Data Engineer
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS mart;


-- 2. For reporting purposes
CREATE SCHEMA IF NOT EXISTS reporting; -- for Manila Temperature

-- 3. Create table for weather raw data -- for Manila Temperature
CREATE TABLE IF NOT EXISTS raw.weather_api_raw (
    id BIGSERIAL PRIMARY KEY,
    city VARCHAR(100),
    api_payload JSONB,
    extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Check raw data -- for Manila Temperature
SELECT *
FROM raw.weather_api_raw
ORDER BY id DESC;

-- 5. Create table for staging data -- for Manila Temperature
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

-- 6. Load raw JSON data into staging table -- for Manila Temperature
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


-- 7. Check staging data -- for Manila Temperature
SELECT *
FROM stg.weather_api_parsed
ORDER BY id DESC;

-- 8. Create table for mart data -- for Manila Temperature
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

-- Alter table for the unique_city_weather_date -- for Manila Temperature
ALTER TABLE mart.weather_daily_summary
ADD CONSTRAINT unique_city_weather_date
UNIQUE (city, weather_date);

-- 9. Load staging data into mart table -- for Manila Temperature
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

SELECT * - -- for Manila Temperature
FROM mart.weather_daily_summary
ORDER BY weather_date DESC;


-- 10. Create reporting  -- for Manila Temperature
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


SELECT * -- for Manila Temperature
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



-- =========================================================
-- Air Pollution API Tables
-- =========================================================

-- 1. Raw table for Air Pollution API JSON response
CREATE TABLE IF NOT EXISTS raw.air_pollution_api_raw (
    id BIGSERIAL PRIMARY KEY,
    city VARCHAR(100),
    latitude NUMERIC(10,6),
    longitude NUMERIC(10,6),
    api_payload JSONB,
    extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Staging table for parsed air pollution data
CREATE TABLE IF NOT EXISTS stg.air_pollution_api_parsed (
    id BIGSERIAL PRIMARY KEY,
    raw_id BIGINT UNIQUE,
    city VARCHAR(100),
    latitude NUMERIC(10,6),
    longitude NUMERIC(10,6),
    aqi INT,
    co NUMERIC(10,3),
    no NUMERIC(10,3),
    no2 NUMERIC(10,3),
    o3 NUMERIC(10,3),
    so2 NUMERIC(10,3),
    pm2_5 NUMERIC(10,3),
    pm10 NUMERIC(10,3),
    nh3 NUMERIC(10,3),
    observation_time TIMESTAMP,
    parsed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_air_pollution_raw
        FOREIGN KEY (raw_id)
        REFERENCES raw.air_pollution_api_raw(id)
);

-- 3. Mart table for dashboard-ready air quality data
CREATE TABLE IF NOT EXISTS mart.air_quality_summary (
    id BIGSERIAL PRIMARY KEY,
    city VARCHAR(100),
    latitude NUMERIC(10,6),
    longitude NUMERIC(10,6),
    aqi INT,
    aqi_category VARCHAR(50),
    pm2_5 NUMERIC(10,3),
    pm10 NUMERIC(10,3),
    co NUMERIC(10,3),
    no2 NUMERIC(10,3),
    o3 NUMERIC(10,3),
    so2 NUMERIC(10,3),
    observation_time TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


SELECT *
FROM raw.air_pollution_api_raw
ORDER BY id DESC;

SELECT *
FROM raw.weather_api_raw
ORDER BY id DESC
LIMIT 5;


-------
SELECT *
FROM stg.air_pollution_api_parsed
ORDER BY id DESC;

SELECT *
FROM mart.air_quality_summary
ORDER BY id DESC;

CREATE OR REPLACE VIEW reporting.weather_air_quality_dashboard AS
SELECT
    aq.city,
    aq.observation_time,
    aq.aqi,
    aq.aqi_category,
    aq.pm2_5,
    aq.pm10,
    aq.co,
    aq.no2,
    aq.o3,
    aq.so2
FROM mart.air_quality_summary aq
ORDER BY aq.observation_time DESC;

SELECT * 
FROM reporting.weather_air_quality_dashboard;


-- =========================================================
-- Combined Weather + Air Quality Dashboard View
-- Automated Batch Pipeline v2
-- =========================================================

CREATE OR REPLACE VIEW reporting.vw_weather_air_quality_dashboard AS
SELECT
    w.city,
    w.weather_date,

    -- Weather API metrics
    w.avg_temperature_c,
    w.min_temperature_c,
    w.max_temperature_c,
    w.avg_humidity,
    w.avg_wind_speed,

    -- Air Quality API metrics
    ROUND(AVG(a.aqi), 2) AS avg_aqi,
    ROUND(AVG(a.pm2_5), 2) AS avg_pm2_5,
    ROUND(AVG(a.pm10), 2) AS avg_pm10,

    -- Pollution level/category
    COALESCE(MAX(a.aqi_category), 'No Air Quality Data') AS pollution_level,

    -- Record counts
    w.records_count AS weather_records_count,
    COUNT(a.id) AS air_quality_records_count,

    -- Data availability status
    CASE
        WHEN COUNT(a.id) = 0 THEN 'Weather Data Only'
        ELSE 'Weather + Air Quality Data'
    END AS data_status,

    -- Latest update
    MAX(a.created_at) AS latest_air_quality_loaded_at

FROM mart.weather_daily_summary w
LEFT JOIN mart.air_quality_summary a
    ON w.city = a.city
    AND w.weather_date = a.observation_time::DATE

GROUP BY
    w.city,
    w.weather_date,
    w.avg_temperature_c,
    w.min_temperature_c,
    w.max_temperature_c,
    w.avg_humidity,
    w.avg_wind_speed,
    w.records_count

ORDER BY
    w.weather_date DESC,
    w.city;


SELECT *
FROM reporting.vw_weather_air_quality_dashboard
ORDER BY weather_date DESC, city;


-- =========================================================
-- KPI View for Latest Weather + Air Quality Dashboard
-- =========================================================

CREATE OR REPLACE VIEW reporting.vw_latest_weather_air_quality_kpi AS
SELECT
    city,
    weather_date,
    avg_temperature_c,
    avg_humidity,
    avg_wind_speed,
    avg_aqi,
    avg_pm2_5,
    avg_pm10,
    pollution_level,
    data_status
FROM reporting.vw_weather_air_quality_dashboard
ORDER BY weather_date DESC;

SELECT *
FROM reporting.vw_latest_weather_air_quality_kpi;

--Optional: dashboard chart queries
--1. Temperature trend

SELECT
    weather_date,
    avg_temperature_c
FROM reporting.vw_weather_air_quality_dashboard
ORDER BY weather_date;


--2. Humidity and wind speed trend
SELECT
    weather_date,
    avg_humidity,
    avg_wind_speed
FROM reporting.vw_weather_air_quality_dashboard
ORDER BY weather_date;

--3. AQI trend
SELECT
    weather_date,
    avg_aqi
FROM reporting.vw_weather_air_quality_dashboard
ORDER BY weather_date;

--4. PM2.5 vs PM10 trend
SELECT
    weather_date,
    avg_pm2_5,
    avg_pm10
FROM reporting.vw_weather_air_quality_dashboard
ORDER BY weather_date;




SELECT
    MAX(extracted_at) AS latest_raw_weather_loaded,
    MAX(extracted_at::date) AS latest_raw_weather_date
FROM raw.weather_api_raw;


SELECT
    MAX(extracted_at) AS latest_raw_air_loaded,
    MAX(extracted_at::date) AS latest_raw_air_date
FROM raw.air_pollution_api_raw;

SELECT
    MAX(observation_time) AS latest_weather_observation,
    MAX(observation_time::date) AS latest_weather_observation_date
FROM stg.weather_api_parsed;

SELECT
    MAX(observation_time) AS latest_air_observation,
    MAX(observation_time::date) AS latest_air_observation_date
FROM stg.air_pollution_api_parsed;


SELECT *
FROM mart.weather_daily_summary
ORDER BY weather_date DESC;


SELECT *
FROM mart.air_quality_summary
ORDER BY observation_time DESC
LIMIT 10;


SELECT pg_get_viewdef('reporting.vw_weather_air_quality_dashboard', true);


SELECT
    observation_time,
    observation_time::date AS weather_date,
    city
FROM stg.weather_api_parsed
ORDER BY observation_time DESC
LIMIT 5;

SELECT
    observation_time,
    observation_time::date AS air_quality_date,
    city,
    aqi,
    pm2_5,
    pm10
FROM stg.air_pollution_api_parsed
ORDER BY observation_time DESC
LIMIT 5;


SELECT *
FROM reporting.vw_weather_air_quality_dashboard
ORDER BY weather_date DESC, city;
