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
ORDER BY id DESC
LIMIT 5;

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
    id AS raw_id,
    city,
    api_payload -> 'weather' -> 0 ->> 'main' AS weather_main,
    api_payload -> 'weather' -> 0 ->> 'description' AS weather_description,
    (api_payload -> 'main' ->> 'temp')::NUMERIC(5,2) AS temperature_c,
    (api_payload -> 'main' ->> 'feels_like')::NUMERIC(5,2) AS feels_like_c,
    (api_payload -> 'main' ->> 'humidity')::INT AS humidity,
    (api_payload -> 'main' ->> 'pressure')::INT AS pressure,
    (api_payload -> 'wind' ->> 'speed')::NUMERIC(6,2) AS wind_speed,
    TO_TIMESTAMP((api_payload ->> 'dt')::BIGINT) AS observation_time
FROM raw.weather_api_raw
ON CONFLICT (raw_id) DO NOTHING;

-- 7. Check staging data
SELECT *
FROM stg.weather_api_parsed
ORDER BY id DESC
LIMIT 5;

-- 8. Create table for mart data
CREATE TABLE IF NOT EXISTS mart.weather_daily (
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
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 9. Load staging data into mart table
INSERT INTO mart.weather_daily (
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
FROM stg.weather_api_parsed
ON CONFLICT (raw_id) DO NOTHING;

-- 10. Check mart table
SELECT *
FROM mart.weather_daily
ORDER BY id DESC
LIMIT 5;


raw_id BIGINT UNIQUE

ON CONFLICT (raw_id) DO NOTHING;