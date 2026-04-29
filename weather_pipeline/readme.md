# The Automated Batch Pipeline: A Local-First Data Engineering Project

## Project Overview

The Automated Batch Pipeline is a local data engineering project that extracts weather data from the OpenWeatherMap API, transforms the JSON response using Python, and loads the structured data into PostgreSQL.

This project follows a raw, staging, and mart layer design to show how data moves from its original format into a cleaner and reporting-ready structure. It is built locally first to practice the fundamentals of data engineering while avoiding unnecessary cloud costs during development.

---

## Project Goals

### Technical Goal
To build a local automated batch pipeline that extracts weather data from an API, transforms it using Python, and loads it into PostgreSQL for structured reporting.

### Personal Goal
To strengthen my data engineering skills by practicing API ingestion, ETL development, database modeling, and scheduling before moving to cloud deployment.

---

## Project Objectives

1. To extract weather data from the OpenWeatherMap API using Python and store the collected information in a local PostgreSQL database.

2. To transform raw JSON data into structured tables using raw, staging, and mart layers for cleaner data processing and reporting.

3. To automate the pipeline locally using a scheduler to simulate real-world batch processing without relying on cloud services.

---

## Data Architecture

```text
OpenWeatherMap API
        ↓
Local Scheduler / Cron → Python ETL Script
                            ↓
                    PostgreSQL RAW Layer
                            ↓
                    PostgreSQL STAGING Layer
                            ↓
                    PostgreSQL MART Layer
                            ↓
                    Reporting / Analysis

```

## Pipeline Components

| Component                | Description                  |
| ------------------------ | ---------------------------- |
| OpenWeatherMap API       | Provides weather data        |
| Local Scheduler / Cron   | Triggers scheduled runs      |
| Python ETL Script        | Extracts and transforms data |
| PostgreSQL RAW Layer     | Stores original data         |
| PostgreSQL STAGING Layer | Cleans structured data       |
| PostgreSQL MART Layer    | Prepares reporting data      |
| Reporting / Analysis     | Generates final insights     |


## Tools and Technologies
- Python
- PostgreSQL
- pgAdmin
- OpenWeatherMap API
- Cron / Local Scheduler
- VS Code
- GitHub

## Database Layers
- RAW Layer - The raw layer stores the original weather API JSON response in PostgreSQL for backup, auditing, and future reprocessing.
- STAGING Layer - The staging layer converts the raw JSON weather data into clean, structured columns for easier validation, analysis, and reporting.
- MART Layer - The mart layer aggregates cleaned weather records into daily summaries, making the data ready for reporting, analysis, and dashboarding.
- Reporting Layer -The reporting view presents daily weather summaries in a clean format for easier querying, analysis, and dashboard use.

## Data Quality Checks
This project includes quality checks to confirm that the pipeline is processing data correctly.

## Check for Unprocessed Raw Records

```
SELECT
    r.id,
    r.city,
    r.extracted_at
FROM raw.weather_api_raw r
LEFT JOIN stg.weather_api_parsed s
    ON r.id = s.raw_id
WHERE s.raw_id IS NULL
ORDER BY r.id;
```
This data quality check confirms whether all raw weather records have been successfully processed into the staging layer.

## Check for Duplicate Records
This data quality check identifies duplicate raw_id records in the staging layer to prevent repeated processing of the same raw weather data.

## Check for Missing Critical Fields
This data quality check identifies staging records with missing critical fields such as city, temperature, humidity, or observation time.

## Local Scheduling
The pipeline can be scheduled locally using cron.

Example cron schedule:
```
0 * * * * /usr/bin/python3 /Users/yourname/weather_pipeline/scripts/weather_etl.py >> /Users/yourname/weather_pipeline/logs/weather_etl.log 2>&1
```
This cron job runs the weather ETL pipeline every hour and saves the execution logs to a local log file.

## Skills Practiced
- API data ingestion
- Python ETL scripting
- JSON parsing and transformation
- Loading data into PostgreSQL
- Raw, staging, and mart data modeling
- Environment variable setup
- Local scheduling using cron
- Pipeline logging and validation
- Data quality checking
- Local-first pipeline development
- Cleaner GitHub project organization

## What This Local Project Taught Me
Data engineering is not only about building pipelines.

It also means:
- developing locally before moving to cloud
- writing cleaner and reusable Python code
- organizing folders, scripts, SQL files, and logs properly
- using environment variables to protect credentials
- checking pipeline logs and scheduled runs
- validating data quality across raw, staging, and mart layers
- building projects that are easy to understand, test, and explain

## Why This Matters for Local Data Engineering
Even a simple local project can show real engineering habits: automation, configuration management, logging, data validation, and building a pipeline that can be tested properly before moving to cloud.

## Pros and Cons per Component

| Component                | Role                                              | Pros                                                                          | Cons                                                                                           |
| ------------------------ | ------------------------------------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| OpenWeatherMap API       | Provides weather data in JSON format              | Easy to use, provides real API data, and is good for practicing API ingestion | Depends on external availability, may have rate limits, and API changes can break the pipeline |
| Local Scheduler / Cron   | Automatically triggers the ETL script on schedule | Free, simple to configure, and simulates real-world batch automation          | Only runs when the local machine is on and has limited monitoring or alerting                  |
| Python ETL Script        | Extracts, transforms, and loads weather data      | Flexible, beginner-friendly, and easy to debug locally                        | Can become hard to maintain as the pipeline grows and needs added retry/error handling         |
| PostgreSQL RAW Layer     | Stores original or minimally processed API data   | Useful for backup, auditing, troubleshooting, and reprocessing                | Can contain messy or duplicated data and may grow quickly over time                            |
| PostgreSQL STAGING Layer | Cleans and structures raw JSON data               | Makes data easier to validate, analyze, and prepare for reporting             | Requires clear transformation rules and updates when source logic changes                      |
| PostgreSQL MART Layer    | Creates reporting-ready summaries and metrics     | Easier for reporting, dashboarding, and business-friendly queries             | Depends on upstream data quality and may produce wrong summaries if logic is incorrect         |
| Reporting / Analysis     | Final layer for querying insights                 | Provides clean and readable outputs for analysis and dashboards               | Results are only reliable if the pipeline and data quality checks are correct                  |


## Next Steps
To improve this project further:
- Use a local .env file securely for sensitive values
- Add retries and stronger error handling in the Python script
- Store more historical records and create richer data models
- Use Docker Compose for easier local setup and deployment
- Build dashboards on top of the mart layer using Tableau, Power BI, or Metabase
- Add better logging and data quality checks for every pipeline run
- Package the project with a clean requirements.txt, README, and setup guide

## Project Status
This project is currently built as a local-first batch pipeline and can be improved further before being deployed to cloud services such as AWS Lambda, Amazon RDS, Amazon S3, or Apache Airflow.

## Author
Created by Marc Sandrino as part of the data_unlocked data engineering portfolio.
