import os
import json
import urllib.request
import pg8000
from datetime import datetime, timezone

API_KEY = os.environ["OPENWEATHER_API_KEY"]
CITY = os.environ.get("CITY", "Manila")
DB_HOST = os.environ["DB_HOST"]
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ["DB_NAME"]
DB_USER = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]

def get_weather(city):
    url = f"https://api.openweathermap.org/data/2.5/weather?q={city}&appid={API_KEY}&units=metric"
    with urllib.request.urlopen(url) as response:
        return json.loads(response.read().decode())

def lambda_handler(event, context):
    conn = None
    cur = None

    try:
        data = get_weather(CITY)

        city = data.get("name", CITY)
        weather_main = data["weather"][0]["main"]
        weather_description = data["weather"][0]["description"]
        temperature_c = data["main"]["temp"]
        feels_like_c = data["main"]["feels_like"]
        humidity = data["main"]["humidity"]
        pressure = data["main"]["pressure"]
        wind_speed = data["wind"]["speed"]
        observation_time = datetime.fromtimestamp(data["dt"], tz=timezone.utc).replace(tzinfo=None)

        conn = pg8000.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )

        cur = conn.cursor()

        # 1. raw insert
        cur.execute(
            """
            INSERT INTO raw.weather_api_raw (city, api_payload)
            VALUES (%s, %s)
            RETURNING id
            """,
            (city, json.dumps(data))
        )
        raw_id = cur.fetchone()[0]

        # 2. stg insert
        cur.execute(
            """
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
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
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
        )

        # 3. mart insert
        cur.execute(
            """
            INSERT INTO mart.weather_daily (
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
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
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
        )

        conn.commit()

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": f"Weather data loaded successfully for {city}"
            })
        }

    except Exception as e:
        if conn:
            conn.rollback()
        return {
            "statusCode": 500,
            "body": json.dumps({
                "message": "Pipeline failed",
                "error": str(e)
            })
        }

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()