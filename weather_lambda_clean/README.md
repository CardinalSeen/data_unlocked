# weather_lambda_clean

A simple AWS-based weather data pipeline project that extracts weather data from the OpenWeather API, transforms the response, and loads it into PostgreSQL.

## Project Overview

This project demonstrates a basic cloud data engineering workflow using AWS Lambda, Amazon EventBridge Scheduler, PostgreSQL, and the OpenWeather API.

The pipeline performs the following steps:
1. Calls the OpenWeather API for a selected city
2. Parses and transforms the JSON response
3. Loads the cleaned weather data into PostgreSQL
4. Supports scheduled execution through EventBridge Scheduler

## Architecture

- **Source:** OpenWeather API
- **Processing:** AWS Lambda (Python)
- **Storage:** PostgreSQL / Amazon RDS
- **Orchestration:** Amazon EventBridge Scheduler

## Project Structure

weather_lambda_clean/
- `README.md` — project documentation
- `lambda_function.py` — main Lambda Python script
- `requirements.txt` — Python package dependencies
- `sql/weather_pipeline.sql` — SQL setup for schemas and tables
- `deployment_package/weather_lambda_clean.zip` — deployment-ready Lambda package
- `sample_output/sample_lambda_response.json` — sample output for testing and documentation
- `.gitignore` — ignored local/system files

## Technologies Used

- Python
- AWS Lambda
- Amazon EventBridge Scheduler
- PostgreSQL / Amazon RDS
- OpenWeather API

## Sample Use Case

This project is designed as a beginner-friendly cloud ETL pipeline for portfolio and practice purposes. It demonstrates API ingestion, transformation, loading, and basic cloud automation in AWS.

## Notes

This project is part of my `data_unlocked` repository, where I document my journey in building data engineering projects using cloud, SQL, and automation tools.
