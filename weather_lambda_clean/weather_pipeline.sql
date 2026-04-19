-- Create Schema for Data Engineer
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS mart;

-- for reporting purposes
CREATE SCHEMA IF NOT EXISTS reporting;

--Create table for raw.weather_api_raw -> this is from OpenWeather API
CREATE TABLE IF NOT EXISTS raw.weather_api_raw (
    id BIGSERIAL PRIMARY KEY,
    city VARCHAR(100),
    api_payload JSONB,
    extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create table for stg.weather_api_parsed kasi aayusin niya ang buong structure for better
-- table foermatr since galing siya JSON format

CREATE TABLE IF NOT EXISTS stg.weather_api_parsed (
    id BIGSERIAL PRIMARY KEY,
    raw_id BIGINT,
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

-- Create table for mart.weather_daily -> Eto na yung required fields for reporting purposes
CREATE TABLE IF NOT EXISTS mart.weather_daily (
    id BIGSERIAL PRIMARY KEY,
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


-- Query testing
SELECT * FROM raw.weather_api_raw ORDER BY id DESC LIMIT 5;
SELECT * FROM stg.weather_api_parsed ORDER BY raw_id DESC LIMIT 5;
SELECT * FROM mart.weather_daily ORDER BY observation_time DESC LIMIT 5;

-- View Reporting (optional)
CREATE OR REPLACE VIEW reporting.v_weather_daily_summary AS
SELECT
    city,
    DATE(observation_time) AS weather_date,
    ROUND(AVG(temperature_c), 2) AS avg_temperature_c,
    ROUND(AVG(feels_like_c), 2) AS avg_feels_like_c,
    ROUND(AVG(humidity), 2) AS avg_humidity,
    ROUND(AVG(pressure), 2) AS avg_pressure,
    ROUND(AVG(wind_speed), 2) AS avg_wind_speed,
    COUNT(*) AS record_count
FROM mart.weather_daily
GROUP BY city, DATE(observation_time)
ORDER BY weather_date DESC, city;


-- test(optional)
SELECT * 
FROM reporting.v_weather_daily_summary;
