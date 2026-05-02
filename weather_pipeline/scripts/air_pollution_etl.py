import os
import requests
import psycopg2
import psycopg2.extras
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("OPENWEATHER_API_KEY")

LAT = os.getenv("AIR_POLLUTION_LAT", "14.5995")
LON = os.getenv("AIR_POLLUTION_LON", "120.9842")
CITY = "Manila"

DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")


def get_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )


def extract_air_pollution_data():
    url = (
        "https://api.openweathermap.org/data/2.5/air_pollution"
        f"?lat={LAT}&lon={LON}&appid={API_KEY}"
    )

    response = requests.get(url, timeout=15)
    response.raise_for_status()

    return response.json()


def load_raw_data(conn, data):
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO raw.air_pollution_api_raw
                (city, latitude, longitude, api_payload)
            VALUES
                (%s, %s, %s, %s)
            RETURNING id;
            """,
            (
                CITY,
                LAT,
                LON,
                psycopg2.extras.Json(data)
            )
        )

        raw_id = cur.fetchone()[0]
        conn.commit()
        return raw_id


def transform_to_staging(conn, raw_id, data):
    air_data = data["list"][0]
    main_data = air_data["main"]
    components = air_data["components"]

    aqi = main_data.get("aqi")

    observation_time = datetime.fromtimestamp(air_data.get("dt"))

    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO stg.air_pollution_api_parsed
                (
                    raw_id,
                    city,
                    latitude,
                    longitude,
                    aqi,
                    co,
                    no,
                    no2,
                    o3,
                    so2,
                    pm2_5,
                    pm10,
                    nh3,
                    observation_time
                )
            VALUES
                (
                    %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s,
                    %s, %s, %s, %s
                )
            ON CONFLICT (raw_id) DO NOTHING;
            """,
            (
                raw_id,
                CITY,
                LAT,
                LON,
                aqi,
                components.get("co"),
                components.get("no"),
                components.get("no2"),
                components.get("o3"),
                components.get("so2"),
                components.get("pm2_5"),
                components.get("pm10"),
                components.get("nh3"),
                observation_time
            )
        )

        conn.commit()


def get_aqi_category(aqi):
    if aqi == 1:
        return "Good"
    elif aqi == 2:
        return "Fair"
    elif aqi == 3:
        return "Moderate"
    elif aqi == 4:
        return "Poor"
    elif aqi == 5:
        return "Very Poor"
    else:
        return "Unknown"


def load_mart_data(conn, raw_id):
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT
                city,
                latitude,
                longitude,
                aqi,
                pm2_5,
                pm10,
                co,
                no2,
                o3,
                so2,
                observation_time
            FROM stg.air_pollution_api_parsed
            WHERE raw_id = %s;
            """,
            (raw_id,)
        )

        row = cur.fetchone()

        if row is None:
            print("No staging record found.")
            return

        (
            city,
            latitude,
            longitude,
            aqi,
            pm2_5,
            pm10,
            co,
            no2,
            o3,
            so2,
            observation_time
        ) = row

        aqi_category = get_aqi_category(aqi)

        cur.execute(
            """
            INSERT INTO mart.air_quality_summary
                (
                    city,
                    latitude,
                    longitude,
                    aqi,
                    aqi_category,
                    pm2_5,
                    pm10,
                    co,
                    no2,
                    o3,
                    so2,
                    observation_time
                )
            VALUES
                (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s);
            """,
            (
                city,
                latitude,
                longitude,
                aqi,
                aqi_category,
                pm2_5,
                pm10,
                co,
                no2,
                o3,
                so2,
                observation_time
            )
        )

        conn.commit()


def run_air_pollution_pipeline():
    conn = None

    try:
        print("Starting Air Pollution ETL pipeline...")

        data = extract_air_pollution_data()

        conn = get_connection()

        raw_id = load_raw_data(conn, data)
        print(f"Raw air pollution data loaded. raw_id={raw_id}")

        transform_to_staging(conn, raw_id, data)
        print("Air pollution data transformed into staging.")

        load_mart_data(conn, raw_id)
        print("Air pollution mart data loaded successfully.")

        print("Air Pollution ETL pipeline completed.")

    except Exception as e:
        print(f"Pipeline failed: {e}")

    finally:
        if conn:
            conn.close()


if __name__ == "__main__":
    run_air_pollution_pipeline()
