# Project_Radiant

Project_Radiant is a simple ETL scorecard pipeline built using PostgreSQL, with a cloud-based deployment version on AWS using Amazon S3 and Amazon RDS for PostgreSQL.

The project simulates how raw operational datasets can be transformed into clean, reporting-ready outputs for scorecard analysis, validation, and performance monitoring.

---

## Project Overview

This project follows a layered ETL approach:

- **raw** = original source data
- **stg** = cleaned and standardized data
- **mart** = final analytical tables
- **reporting** = dashboard-ready reporting views

The pipeline processes datasets related to:

- Employee master data
- Attendance
- Productivity
- Quality
- Adherence
- Compliance

The final output is a scorecard reporting view that can be used to assess employee performance and bonus eligibility.

---

## Objectives

- Build a structured ETL workflow in PostgreSQL
- Apply data cleaning and validation rules
- Create dimension and fact tables for reporting
- Generate a final reporting view for business use
- Demonstrate both a **local PostgreSQL implementation** and an **AWS RDS cloud implementation**

---

## Tech Stack

### Local Version
- PostgreSQL
- pgAdmin
- CSV files

### AWS Version
- Amazon S3
- Amazon RDS for PostgreSQL
- pgAdmin

---

## Architecture

### Local PostgreSQL Version
CSV Files → PostgreSQL Raw Tables → Staging Tables → Mart Tables → Reporting View

### AWS Version
CSV Files → Amazon S3 → Amazon RDS PostgreSQL → Staging Tables → Mart Tables → Reporting View

---

## ETL Layers

### 1. Raw Layer
The raw layer stores the original uploaded CSV data without applying business transformations.

Tables:
- `raw.employee_raw`
- `raw.attendance_raw`
- `raw.productivity_raw`
- `raw.quality_raw`
- `raw.adherence_raw`
- `raw.compliance_raw`

### 2. Staging Layer
The staging layer cleans and standardizes the raw data.

Examples:
- trims spaces
- replaces blank values
- standardizes text values
- converts date fields
- prepares data for downstream reporting

Tables:
- `stg.employee`
- `stg.attendance`
- `stg.productivity`
- `stg.quality`
- `stg.adherence`
- `stg.compliance`

### 3. Mart Layer
The mart layer contains reporting-friendly tables including dimensions and facts.

Tables:
- `mart.dim_employee`
- `mart.fact_attendance`
- `mart.fact_productivity`
- `mart.fact_quality`
- `mart.fact_adherence`
- `mart.fact_compliance`

### 4. Reporting Layer
The reporting layer contains the final dashboard-ready reporting view.

View:
- `reporting.v_dashboard_scorecard`

---

## Data Validation Rules

The project includes validation checks to improve data quality before reporting.

Examples:
- checking duplicate employee records
- checking orphan records
- validating attendance vs productivity
- identifying exceptions and warning records
- verifying final fact table populations

A key business rule implemented in the project:
- If an employee is absent due to approved leave, productivity should be zero
- If an employee is late, productivity may still exist
- If an employee is present, productivity is expected

---

## Final Output

The final reporting output includes:

- employee name
- masked employee ID
- team lead
- total transactions
- average quality score
- adherence count
- compliance violations
- counted absences
- weighted component scores
- final score
- bonus eligibility status
- ranking

---

## Project Versions

### Version 1: Local PostgreSQL
This version was executed manually using local PostgreSQL and pgAdmin.

### Version 2: AWS Cloud Version
This version was implemented using:
- **Amazon S3** as the raw file storage layer
- **Amazon RDS for PostgreSQL** as the cloud ETL and reporting database
- **pgAdmin** as the database administration and query tool

This demonstrates how the same ETL logic can be migrated from a local environment to a cloud-based PostgreSQL environment.

---

## Folder Structure

```text
Project_Radiant/
├── README.md
├── raw/
├── stg/
├── mart/
├── kpi/
├── schema/
├── reporting/
├── sample_output/
├── data_quality/
├── performance/
├── sql/
└── data/
└── docs/
  ├── local_postgresql_setup.md
  └── aws_rds_setup.md

```

## How to Run
1. Local PostgreSQL
2. Create the schemas
3. Create raw tables
4. Import CSV files into raw tables
5. Run staging scripts
6. Run validation scripts
7. Create mart tables
8. Create reporting views
9. Query the final reporting view

## AWS Version
1. Upload source files to Amazon S3
2. Create an Amazon RDS PostgreSQL instance
3. Connect to RDS using pgAdmin
4. Run the same SQL ETL scripts
5. Load source data into raw tables
6. Validate and generate the final reporting view

## Key Learnings
- Organizing data into layered schemas improves structure and maintainability
- Data validation is critical before producing business reports
- PostgreSQL can support a simple but effective ETL pipeline
- AWS RDS can be used to migrate a local ETL workflow into a cloud environment
- S3 adds a cloud-based raw data storage layer for a more complete data engineering architecture

## Notes
This project is designed as a portfolio demonstration of ETL fundamentals, data quality checks, and reporting design using PostgreSQL and AWS.
The datasets used in this project are sample/project datasets created for demonstration purposes only.

Presented by:
Marc Sandrino
