import os
import requests
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("OPENWEATHER_API_KEY")
CITY = os.getenv("CITY", "Manila")

DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")


def validate_env_variables():
    required_vars = {
        "OPENWEATHER_API_KEY": API_KEY,
        "DB_HOST": DB_HOST,
        "DB_PORT": DB_PORT,
        "DB_NAME": DB_NAME,
        "DB_USER": DB_USER,
        "DB_PASSWORD": DB_PASSWORD,
    }

    missing_vars = [key for key, value in required_vars.items() if not value]

    if missing_vars:
        raise ValueError(f"Missing environment variables: {', '.join(missing_vars)}")


def extract_weather_data(city):
    url = (
        "https://api.openweathermap.org/data/2.5/weather"
        f"?q={city}&appid={API_KEY}&units=metric"
    )

    response = requests.get(url, timeout=15)
    response.raise_for_status()

    return response.json()


def run_weather_pipeline(raw_data):
    conn = None
    cur = None

    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
        )

        cur = conn.cursor()

        # 1. API → RAW
        raw_insert_sql = """
            INSERT INTO raw.weather_api_raw (
                city,
                api_payload
            )
            VALUES (%s, %s)
            RETURNING id;
        """

        cur.execute(
            raw_insert_sql,
            (
                raw_data.get("name"),
                psycopg2.extras.Json(raw_data),
            ),
        )

        raw_id = cur.fetchone()[0]

        print(f"RAW loaded successfully. raw_id = {raw_id}")

        # 2. RAW → STAGING
        staging_sql = """
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
            WHERE s.raw_id IS NULL
              AND r.id = %s;
        """

        cur.execute(staging_sql, (raw_id,))

        print(f"STAGING parsed successfully. Rows inserted = {cur.rowcount}")

        # 3. STAGING → MART
        mart_sql = """
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
        """

        cur.execute(mart_sql)

        print(f"MART daily summary updated successfully. Rows affected = {cur.rowcount}")

        conn.commit()

    except Exception as e:
        if conn:
            conn.rollback()

        print(f"Pipeline failed: {e}")
        raise

    finally:
        if cur:
            cur.close()

        if conn:
            conn.close()
    

def main():
    print("Starting weather batch pipeline...")

    validate_env_variables()

    raw_data = extract_weather_data(CITY)

    print(f"Weather data extracted from OpenWeather API for: {raw_data.get('name')}")

    run_weather_pipeline(raw_data)

    print("Weather batch pipeline completed successfully.")


if __name__ == "__main__":
    main()