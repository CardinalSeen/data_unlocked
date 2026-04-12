-- 1. Create Schemas
-- to determine the layers of the ETL
-- raw = original source data
-- stg = cleaned / standardized data
-- mart = final reporting tables

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS mart;
CREATE SCHEMA IF NOT EXISTS reporting;

-- create table raw.employee_raw
DROP TABLE IF EXISTS raw.employee_raw;
CREATE TABLE raw.employee_raw (
    emp_id INT,
    last_name TEXT,
    first_name TEXT,
    team TEXT,
    team_lead TEXT
);

-- create table raw.attendance_raw
DROP TABLE IF EXISTS raw.attendance_raw;
CREATE TABLE raw.attendance_raw (
    emp_id INT,
    attendance_id INT,
    attendance_date DATE,
    time_in TIME,
    time_out TIME,
    late_minutes INT,
    undertime_minutes INT,
    production_hours NUMERIC(10,2),
    status TEXT,
    absent_reason TEXT
);

-- create table raw.productivity_raw
DROP TABLE IF EXISTS raw.productivity_raw;
CREATE TABLE raw.productivity_raw (
    emp_id INT,
    transaction_date DATE,
    transactions_completed INT,
    status TEXT
);

--create table raw.quality_raw
DROP TABLE IF EXISTS raw.quality_raw;
CREATE TABLE raw.quality_raw (
    emp_id INT,
    employee_name TEXT,
    quality_id INT,
    score NUMERIC(10,2),
    status TEXT,
	audit_date DATE
);

--create raw.adherence_raw
DROP TABLE IF EXISTS raw.adherence_raw;
CREATE TABLE raw.adherence_raw (
    emp_id INT,
    case_id INT,
    status TEXT,
    status_reason TEXT,
	adherence_date DATE
);

--create raw.compliance_raw
DROP TABLE IF EXISTS raw.compliance_raw;
CREATE TABLE raw.compliance_raw (
    emp_id INT,
    comp_id INT,
	compliance_date DATE,
    status TEXT,
    status_reason TEXT
);


--3. All the CSV are upload in each table 

--4. Create staging tables
-- this is the process to clean the data
-- trim spaces
-- replace nulls
-- standardized text values
-- prepare for mart loading

-- create stg.employee
DROP TABLE IF EXISTS stg.employee;
CREATE TABLE stg.employee AS
SELECT DISTINCT
    emp_id,
    TRIM(last_name) AS last_name,
    TRIM(first_name) AS first_name,
    TRIM(first_name) || ' ' || TRIM(last_name) AS employee_name,
    TRIM(team) AS team,
    TRIM(team_lead) AS team_lead
FROM raw.employee_raw
WHERE emp_id IS NOT NULL;

--create stg.attendance
DROP TABLE IF EXISTS stg.attendance;
CREATE TABLE stg.attendance AS
SELECT
    emp_id,
    attendance_id,
    attendance_date,
    time_in,
    time_out,
    COALESCE(late_minutes, 0) AS late_minutes,
    COALESCE(undertime_minutes, 0) AS undertime_minutes,
    COALESCE(production_hours, 0) AS production_hours,
    INITCAP(TRIM(status)) AS status,
    COALESCE(NULLIF(TRIM(absent_reason), ''), 'N/A') AS absent_reason
FROM raw.attendance_raw
WHERE emp_id IS NOT NULL;

--create stg.productivity
DROP TABLE IF EXISTS stg.productivity;
CREATE TABLE stg.productivity AS
SELECT
    emp_id,
    transaction_date,
    COALESCE(transactions_completed, 0) AS transactions_completed,
    INITCAP(TRIM(status)) AS status
FROM raw.productivity_raw
WHERE emp_id IS NOT NULL;

--create stg.quality
DROP TABLE IF EXISTS stg.quality;
CREATE TABLE stg.quality AS
SELECT
    emp_id,
    TRIM(employee_name) AS employee_name,
    quality_id,
    COALESCE(score, 0) AS score,
    INITCAP(TRIM(status)) AS status,
	CAST(audit_date AS DATE) AS audit_date -- to update the audit_date from raw
FROM raw.quality_raw
WHERE emp_id IS NOT NULL;


--create stg.adherence
DROP TABLE IF EXISTS stg.adherence;
CREATE TABLE stg.adherence AS
SELECT
    emp_id,
    case_id,
    INITCAP(TRIM(status)) AS status,
    COALESCE(NULLIF(TRIM(status_reason), ''), 'N/A') AS status_reason,
	CAST(adherence_date AS DATE) AS adherence_date --to update the adherence_date from raw
FROM raw.adherence_raw
WHERE emp_id IS NOT NULL;

--create stg.compliance
DROP TABLE IF EXISTS stg.compliance;
CREATE TABLE stg.compliance AS
SELECT
    emp_id,
    comp_id,
	CAST(compliance_date AS DATE) AS compliance_date,
    TRIM(status) AS status,
    COALESCE(NULLIF(TRIM(status_reason), ''), 'N/A') AS status_reason	
FROM raw.compliance_raw
WHERE emp_id IS NOT NULL;


--5. Data Quality Checks
-- to determine the duplicate employees and orphan records

/* Check duplicate emp_id sa employee table */
SELECT emp_id, COUNT(*)
FROM stg.employee
GROUP BY emp_id
HAVING COUNT(*) > 1;

/* Check orphan attendance records */
SELECT a.emp_id
FROM stg.attendance a
LEFT JOIN stg.employee e ON a.emp_id = e.emp_id
WHERE e.emp_id IS NULL;

/* Check orphan productivity records */
SELECT p.emp_id
FROM stg.productivity p
LEFT JOIN stg.employee e ON p.emp_id = e.emp_id
WHERE e.emp_id IS NULL;

/* Check orphan quality records */
SELECT q.emp_id
FROM stg.quality q
LEFT JOIN stg.employee e ON q.emp_id = e.emp_id
WHERE e.emp_id IS NULL;

/* Check orphan adherence records */
SELECT ad.emp_id
FROM stg.adherence ad
LEFT JOIN stg.employee e ON ad.emp_id = e.emp_id
WHERE e.emp_id IS NULL;

/* Check orphan compliance records */
SELECT c.emp_id
FROM stg.compliance c
LEFT JOIN stg.employee e ON c.emp_id = e.emp_id
WHERE e.emp_id IS NULL;

-- 6. Validation of attendance vs productivity
-- to validate if there is mismatch between productivity and attendance
-- here are the business rules
-- 6.1 If the agent is absent due to Emergency, Vacation or Sick Leaves the 
-- productivity should zero
-- 6.2 If the agent is late, it should be a productivity
-- 6.3 If the agent is present, it should be a productivity 

SELECT
    a.emp_id,
    a.attendance_date,
    a.status AS attendance_status,
    a.absent_reason,
    COALESCE(p.transactions_completed, 0) AS transactions_completed,
    p.status AS productivity_status,
    CASE
        /* Rule 1: Absent with approved leave reasons should have zero productivity */
        WHEN UPPER(a.status) = 'ABSENT'
             AND UPPER(COALESCE(a.absent_reason, '')) IN
                 ('NCSC', 'VACATION', 'VACATION LEAVE', 'SICK', 'SICK LEAVE', 'EMERGENCY', 'EMERGENCY LEAVE')
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'ERROR'

        /* Rule 2: Present but zero productivity is possible, but needs review */
        WHEN UPPER(a.status) = 'PRESENT'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'WARNING'

        /* Rule 3: Late but zero productivity is possible, but needs review */
        WHEN UPPER(a.status) = 'LATE'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'WARNING'

        /* Rule 4: No attendance record but has productivity */
        WHEN a.status IS NULL
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'ERROR'

        ELSE 'OK'
    END AS validation_status,
    CASE
        WHEN UPPER(a.status) = 'ABSENT'
             AND UPPER(COALESCE(a.absent_reason, '')) IN
                 ('NCSC', 'VACATION', 'VACATION LEAVE', 'SICK', 'SICK LEAVE', 'EMERGENCY', 'EMERGENCY LEAVE')
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'Absent agent with approved leave should have zero productivity'

        WHEN UPPER(a.status) = 'PRESENT'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'Present but zero productivity - check if training, admin work, system issue, or idle time'

        WHEN UPPER(a.status) = 'LATE'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'Late but zero productivity - check if partial shift, system issue, or no completed transactions'

        WHEN a.status IS NULL
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'Productivity exists but no attendance record found'

        ELSE 'Record passed validation'
    END AS validation_message
FROM stg.attendance a
LEFT JOIN stg.productivity p
  ON a.emp_id = p.emp_id
 AND a.attendance_date = p.transaction_date
ORDER BY a.emp_id, a.attendance_date;


-- 7. Create dimension table for employee
DROP TABLE IF EXISTS mart.dim_employee;
CREATE TABLE mart.dim_employee (
    emp_id INT PRIMARY KEY,
    last_name TEXT NOT NULL,
    first_name TEXT NOT NULL,
    employee_name TEXT NOT NULL,
    team TEXT,
    team_lead TEXT
);

INSERT INTO mart.dim_employee (
    emp_id, last_name, first_name, employee_name, team, team_lead
)
SELECT
    emp_id,
    last_name,
    first_name,
    employee_name,
    team,
    team_lead
FROM stg.employee;

--8. Create fact_attendance
DROP TABLE IF EXISTS mart.fact_attendance;
CREATE TABLE mart.fact_attendance (
    attendance_id INT PRIMARY KEY,
    emp_id INT NOT NULL REFERENCES mart.dim_employee(emp_id),
    attendance_date DATE NOT NULL,
    time_in TIME,
    time_out TIME,
    late_minutes INT DEFAULT 0,
    undertime_minutes INT DEFAULT 0,
    production_hours NUMERIC(10,2) DEFAULT 0,
    status TEXT,
    absent_reason TEXT
);

INSERT INTO mart.fact_attendance (
    attendance_id, emp_id, attendance_date, time_in, time_out,
    late_minutes, undertime_minutes, production_hours, status, absent_reason
)
SELECT
    attendance_id,
    emp_id,
    attendance_date,
    time_in,
    time_out,
    late_minutes,
    undertime_minutes,
    production_hours,
    status,
    absent_reason
FROM stg.attendance;

-- 9. Create fact_productivity
DROP TABLE IF EXISTS mart.fact_productivity;
CREATE TABLE mart.fact_productivity (
    transaction_sk BIGSERIAL PRIMARY KEY,
    emp_id INT NOT NULL REFERENCES mart.dim_employee(emp_id),
    transaction_date DATE NOT NULL,
    transactions_completed INT DEFAULT 0,
    status TEXT,
    reconciliation_flag TEXT,
    validation_message TEXT
);

INSERT INTO mart.fact_productivity (
    emp_id,
    transaction_date,
    transactions_completed,
    status,
    reconciliation_flag,
    validation_message
)
SELECT
    a.emp_id,
    a.attendance_date AS transaction_date,

    /* Match stg rule:
       If absent with approved leave, productivity should be forced to 0 */
    CASE
        WHEN UPPER(a.status) = 'ABSENT'
             AND UPPER(COALESCE(a.absent_reason, '')) IN
                 ('NCSC', 'VACATION', 'VACATION LEAVE', 'SICK', 'SICK LEAVE', 'EMERGENCY', 'EMERGENCY LEAVE')
            THEN 0
        ELSE COALESCE(p.transactions_completed, 0)
    END AS transactions_completed,

    /* Match stg validation_status */
    CASE
        WHEN UPPER(a.status) = 'ABSENT'
             AND UPPER(COALESCE(a.absent_reason, '')) IN
                 ('NCSC', 'VACATION', 'VACATION LEAVE', 'SICK', 'SICK LEAVE', 'EMERGENCY', 'EMERGENCY LEAVE')
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'ERROR'

        WHEN UPPER(a.status) = 'PRESENT'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'WARNING'

        WHEN UPPER(a.status) = 'LATE'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'WARNING'

        WHEN a.status IS NULL
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'ERROR'

        ELSE 'OK'
    END AS status,

    /* Match stg validation_status in a more business-friendly label */
    CASE
        WHEN UPPER(a.status) = 'ABSENT'
             AND UPPER(COALESCE(a.absent_reason, '')) IN
                 ('NCSC', 'VACATION', 'VACATION LEAVE', 'SICK', 'SICK LEAVE', 'EMERGENCY', 'EMERGENCY LEAVE')
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'Mismatch - should be zero'

        WHEN UPPER(a.status) = 'PRESENT'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'Review - present but zero productivity'

        WHEN UPPER(a.status) = 'LATE'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'Review - late but zero productivity'

        WHEN a.status IS NULL
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'Mismatch - no attendance but has productivity'

        WHEN UPPER(a.status) = 'ABSENT'
             AND UPPER(COALESCE(a.absent_reason, '')) IN
                 ('NCSC', 'VACATION', 'VACATION LEAVE', 'SICK', 'SICK LEAVE', 'EMERGENCY', 'EMERGENCY LEAVE')
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'Aligned - approved absence'

        WHEN UPPER(a.status) = 'PRESENT'
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'Aligned - present with productivity'

        WHEN UPPER(a.status) = 'LATE'
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'Aligned - late with productivity'

        ELSE 'OK'
    END AS reconciliation_flag,

    /* Match stg validation_message */
    CASE
        WHEN UPPER(a.status) = 'ABSENT'
             AND UPPER(COALESCE(a.absent_reason, '')) IN
                 ('NCSC', 'VACATION', 'VACATION LEAVE', 'SICK', 'SICK LEAVE', 'EMERGENCY', 'EMERGENCY LEAVE')
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'Absent agent with approved leave should have zero productivity'

        WHEN UPPER(a.status) = 'PRESENT'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'Present but zero productivity - check if training, admin work, system issue, or idle time'

        WHEN UPPER(a.status) = 'LATE'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'Late but zero productivity - check if partial shift, system issue, or no completed transactions'

        WHEN a.status IS NULL
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'Productivity exists but no attendance record found'

        ELSE 'Record passed validation'
    END AS validation_message

FROM mart.fact_attendance a
LEFT JOIN stg.productivity p
  ON a.emp_id = p.emp_id
 AND a.attendance_date = p.transaction_date;

-- 10. Create FACT Quality
DROP TABLE IF EXISTS mart.fact_quality;
CREATE TABLE mart.fact_quality (
    quality_id INT PRIMARY KEY,
    emp_id INT NOT NULL REFERENCES mart.dim_employee(emp_id),
    employee_name TEXT,
    score NUMERIC(10,2),
    status TEXT,
	audit_date DATE
);

INSERT INTO mart.fact_quality (
    quality_id, emp_id, employee_name, score, status, audit_date
)
SELECT
    quality_id,
    emp_id,
    employee_name,
    score,
    status,
	audit_date DATE
FROM stg.quality;


-- 11. Create Fact Adherence
DROP TABLE IF EXISTS mart.fact_adherence;
CREATE TABLE mart.fact_adherence (
    case_id INT PRIMARY KEY,
    emp_id INT NOT NULL REFERENCES mart.dim_employee(emp_id),
    status TEXT,
    status_reason TEXT,
	adherence_date DATE
);

INSERT INTO mart.fact_adherence (
    case_id, emp_id, status, status_reason, adherence_date
)
SELECT
    case_id,
    emp_id,
    status,
    status_reason,
	adherence_date
FROM stg.adherence;

--12. Create FACT Compliance
DROP TABLE IF EXISTS mart.fact_compliance;
CREATE TABLE mart.fact_compliance (
    comp_id INT PRIMARY KEY,
    emp_id INT NOT NULL REFERENCES mart.dim_employee(emp_id),
	compliance_date DATE,
    status TEXT,
    status_reason TEXT
);

INSERT INTO mart.fact_compliance (
    comp_id, emp_id, compliance_date, status, status_reason
)
SELECT
    comp_id,
    emp_id,
	compliance_date,
    status,
    status_reason
FROM stg.compliance;

-- 13. Create Index
-- Explanation: An index is a database optimization technique that 
-- improves query performance by allowing faster data retrieval, 
-- especially for joins, filtering, and aggregations on large datasets.
CREATE INDEX idx_fact_attendance_emp_date
ON mart.fact_attendance(emp_id, attendance_date);

CREATE INDEX idx_fact_productivity_emp_date
ON mart.fact_productivity(emp_id, transaction_date);

CREATE INDEX idx_fact_quality_emp
ON mart.fact_quality(emp_id);

CREATE INDEX idx_fact_adherence_emp
ON mart.fact_adherence(emp_id);

CREATE INDEX idx_fact_compliance_emp
ON mart.fact_compliance(emp_id);

-- 14. Final Validation
-- this to clarify for the attendance vs productivity

--FINAL VALIDATION
SELECT
    a.emp_id,
    a.attendance_date,
    a.status AS attendance_status,
    a.absent_reason,
    COALESCE(p.transactions_completed, 0) AS transactions_completed,
    p.status AS validation_status,
    p.reconciliation_flag,
    p.validation_message
FROM mart.fact_attendance a
LEFT JOIN mart.fact_productivity p
  ON a.emp_id = p.emp_id
 AND a.attendance_date = p.transaction_date
ORDER BY a.emp_id, a.attendance_date;


-- 15. EXCEPTIONS
-- Data Engineer needs to coordinate to the MIS / Data Analyst or
-- Real Time Analyst to confirm if these validation message is valid such as low 
-- productivity for those agents in able to make the final scorecard.

SELECT
    a.emp_id,
    a.attendance_date,
    a.status AS attendance_status,
    a.absent_reason,
    COALESCE(p.transactions_completed, 0) AS transactions_completed,
    p.status AS validation_status,
    p.reconciliation_flag,
    p.validation_message
FROM mart.fact_attendance a
LEFT JOIN mart.fact_productivity p
  ON a.emp_id = p.emp_id
 AND a.attendance_date = p.transaction_date
WHERE p.status IN ('ERROR', 'WARNING')
ORDER BY a.emp_id, a.attendance_date;

-- 16. Quality Summary
SELECT
    emp_id,
    DATE_TRUNC('month', audit_date)::date AS audit_month,

    COUNT(*) AS total_quality_checks,
    ROUND(AVG(score), 2) AS avg_quality_score,

    SUM(CASE WHEN status = 'Pass' THEN 1 ELSE 0 END) AS passed_checks,
    SUM(CASE WHEN status = 'Fail' THEN 1 ELSE 0 END) AS failed_checks,

    CASE
        WHEN COUNT(*) = 5 THEN 'Complete'
        WHEN COUNT(*) < 5 THEN 'Incomplete'
        ELSE 'Over Audit'
    END AS audit_status

FROM mart.fact_quality
WHERE audit_date >= DATE '2026-03-01'
  AND audit_date <  DATE '2026-04-01'

GROUP BY emp_id, DATE_TRUNC('month', audit_date)
ORDER BY emp_id;

-- 17. Adherence Summary

SELECT
    emp_id,
    DATE_TRUNC('month', adherence_date)::date AS adherence_month,

    COUNT(*) AS total_cases,
    COUNT(*) FILTER (WHERE TRIM(UPPER(status)) = 'AGENT ERROR') AS agent_error,
    COUNT(*) FILTER (WHERE TRIM(UPPER(status)) = 'CANCELLED') AS cancelled,
    COUNT(*) FILTER (WHERE TRIM(UPPER(status)) IN ('ON-HOLD', 'ON HOLD')) AS on_hold,
    COUNT(*) FILTER (WHERE TRIM(UPPER(status)) = 'MISSED SLA') AS missed_sla,

    COUNT(*) FILTER (
        WHERE
            (TRIM(UPPER(status)) = 'MISSED SLA' AND TRIM(UPPER(status_reason)) = 'AGENT DELAY')
            OR
            (TRIM(UPPER(status)) = 'AGENT ERROR' AND TRIM(UPPER(status_reason)) IN (
                'INCORRECT BENEFIT CODE INPUT',
                'INCORRECT ADDRESS INPUT'
            ))
    ) AS counted_adherence_issues

FROM mart.fact_adherence
WHERE adherence_date >= DATE '2026-03-01'
  AND adherence_date <  DATE '2026-04-01'

GROUP BY emp_id, DATE_TRUNC('month', adherence_date)
ORDER BY emp_id;


--18. Compliance Summary
SELECT
    DATE_TRUNC('month', compliance_date)::date AS compliance_month,
    status,
    COUNT(*) AS total_records,

    SUM(
        CASE
            WHEN TRIM(UPPER(status)) = 'NO VIOLATION' THEN 0
            ELSE 1
        END
    ) AS total_violations

FROM mart.fact_compliance
WHERE compliance_date >= DATE '2026-03-01'
  AND compliance_date <  DATE '2026-04-01'

GROUP BY DATE_TRUNC('month', compliance_date), status
ORDER BY total_records DESC;

--19. KPI for computation
CREATE OR REPLACE VIEW mart.v_scorecard_march_2026_final_report AS

WITH productivity_monthly AS (
    SELECT
        emp_id,
        SUM(COALESCE(transactions_completed, 0)) AS total_transactions
    FROM mart.fact_productivity
    WHERE transaction_date >= DATE '2026-03-01'
      AND transaction_date <  DATE '2026-04-01'
    GROUP BY emp_id
),

quality_monthly AS (
    SELECT
        emp_id,
        COUNT(*) AS quality_audit_count,
        ROUND(AVG(COALESCE(score, 0)), 2) AS avg_quality_score
    FROM mart.fact_quality
    WHERE audit_date >= DATE '2026-03-01'
      AND audit_date <  DATE '2026-04-01'
    GROUP BY emp_id
),

adherence_monthly AS (
    SELECT
        emp_id,
        COUNT(*) FILTER (
            WHERE
                (UPPER(status) = 'MISSED SLA' AND UPPER(status_reason) = 'AGENT DELAY')
                OR
                (UPPER(status) = 'AGENT ERROR' AND UPPER(status_reason) IN (
                    'INCORRECT BENEFIT CODE INPUT',
                    'INCORRECT ADDRESS INPUT'
                ))
        ) AS adherence_count
    FROM mart.fact_adherence
    WHERE adherence_date >= DATE '2026-03-01'
      AND adherence_date <  DATE '2026-04-01'
    GROUP BY emp_id
),

compliance_monthly AS (
    SELECT
        emp_id,
        COUNT(*) FILTER (
            WHERE UPPER(status) <> 'NO VIOLATION'
        ) AS compliance_violations
    FROM mart.fact_compliance
    WHERE compliance_date >= DATE '2026-03-01'
      AND compliance_date <  DATE '2026-04-01'
    GROUP BY emp_id
),

attendance_monthly AS (
    SELECT
        emp_id,
        SUM(
            CASE
                WHEN UPPER(status) = 'ABSENT'
                     AND UPPER(COALESCE(absent_reason,'')) IN (
                         'EMERGENCY','SICK','SICK LEAVE','NCNS','NO CALL, NO SHOW'
                     )
                THEN 1
                WHEN UPPER(status) = 'LATE' AND COALESCE(late_minutes,0) > 450
                THEN 1
                ELSE 0
            END
        ) AS counted_absences
    FROM mart.fact_attendance
    WHERE attendance_date >= DATE '2026-03-01'
      AND attendance_date <  DATE '2026-04-01'
    GROUP BY emp_id
),

final_scores AS (
    SELECT
        d.emp_id,
        d.employee_name,
        d.team_lead,

        COALESCE(p.total_transactions, 0) AS total_transactions,
        COALESCE(q.avg_quality_score, 0) AS avg_quality_score,
        COALESCE(q.quality_audit_count, 0) AS quality_audit_count,
        COALESCE(a.adherence_count, 0) AS adherence_count,
        COALESCE(c.compliance_violations, 0) AS compliance_violations,
        COALESCE(att.counted_absences, 0) AS counted_absences,

        -- Productivity
        CASE
            WHEN p.total_transactions >= 1401 THEN 100
            WHEN p.total_transactions BETWEEN 1351 AND 1400 THEN 95
            WHEN p.total_transactions BETWEEN 1301 AND 1350 THEN 90
            WHEN p.total_transactions BETWEEN 1251 AND 1300 THEN 85
            WHEN p.total_transactions BETWEEN 1201 AND 1250 THEN 80
            WHEN p.total_transactions BETWEEN 1151 AND 1200 THEN 75
            WHEN p.total_transactions BETWEEN 1101 AND 1150 THEN 70
            WHEN p.total_transactions BETWEEN 1001 AND 1050 THEN 65
            ELSE 0
        END AS productivity_score,

        -- Weighted
        ROUND(
            CASE
                WHEN p.total_transactions >= 1401 THEN 100
                WHEN p.total_transactions BETWEEN 1351 AND 1400 THEN 95
                WHEN p.total_transactions BETWEEN 1301 AND 1350 THEN 90
                WHEN p.total_transactions BETWEEN 1251 AND 1300 THEN 85
                WHEN p.total_transactions BETWEEN 1201 AND 1250 THEN 80
                WHEN p.total_transactions BETWEEN 1151 AND 1200 THEN 75
                WHEN p.total_transactions BETWEEN 1101 AND 1150 THEN 70
                WHEN p.total_transactions BETWEEN 1001 AND 1050 THEN 65
                ELSE 0
            END * 0.30, 2
        ) AS productivity_weighted,

        -- Quality
        CASE WHEN q.avg_quality_score < 70 THEN 0 ELSE q.avg_quality_score END AS quality_score,
        ROUND(
            CASE WHEN q.avg_quality_score < 70 THEN 0 ELSE q.avg_quality_score * 0.20 END, 2
        ) AS quality_weighted,

        -- Adherence
        CASE
            WHEN a.adherence_count = 0 THEN 100
            WHEN a.adherence_count = 1 THEN 95
            WHEN a.adherence_count = 2 THEN 90
            WHEN a.adherence_count = 3 THEN 85
            WHEN a.adherence_count = 4 THEN 80
            WHEN a.adherence_count = 5 THEN 75
            WHEN a.adherence_count = 6 THEN 70
            ELSE 0
        END AS adherence_score,

        ROUND(
            CASE
                WHEN a.adherence_count = 0 THEN 100
                WHEN a.adherence_count = 1 THEN 95
                WHEN a.adherence_count = 2 THEN 90
                WHEN a.adherence_count = 3 THEN 85
                WHEN a.adherence_count = 4 THEN 80
                WHEN a.adherence_count = 5 THEN 75
                WHEN a.adherence_count = 6 THEN 70
                ELSE 0
            END * 0.20, 2
        ) AS adherence_weighted,

        -- Compliance
        CASE WHEN c.compliance_violations >= 1 THEN 0 ELSE 100 END AS compliance_score,
        CASE WHEN c.compliance_violations >= 1 THEN 0 ELSE 20 END AS compliance_weighted,

        -- Attendance
        CASE
            WHEN att.counted_absences = 0 THEN 100
            WHEN att.counted_absences = 1 THEN 95
            WHEN att.counted_absences = 2 THEN 90
            WHEN att.counted_absences = 3 THEN 85
            WHEN att.counted_absences = 4 THEN 80
            WHEN att.counted_absences = 5 THEN 75
            ELSE 0
        END AS attendance_score,

        ROUND(
            CASE
                WHEN att.counted_absences = 0 THEN 100
                WHEN att.counted_absences = 1 THEN 95
                WHEN att.counted_absences = 2 THEN 90
                WHEN att.counted_absences = 3 THEN 85
                WHEN att.counted_absences = 4 THEN 80
                WHEN att.counted_absences = 5 THEN 75
                ELSE 0
            END * 0.10, 2
        ) AS attendance_weighted

    FROM mart.dim_employee d
    LEFT JOIN productivity_monthly p ON d.emp_id = p.emp_id
    LEFT JOIN quality_monthly q ON d.emp_id = q.emp_id
    LEFT JOIN adherence_monthly a ON d.emp_id = a.emp_id
    LEFT JOIN compliance_monthly c ON d.emp_id = c.emp_id
    LEFT JOIN attendance_monthly att ON d.emp_id = att.emp_id
)

SELECT
    employee_name,
    team_lead,

    LEFT(emp_id::text, LENGTH(emp_id::text) - 5) || '*****' AS masked_emp_id,

    total_transactions,
    avg_quality_score,
    quality_audit_count,
    adherence_count,
    compliance_violations,
    counted_absences,

    productivity_weighted,
    quality_weighted,
    adherence_weighted,
    compliance_weighted,
    attendance_weighted,

    ROUND(
        productivity_weighted +
        quality_weighted +
        adherence_weighted +
        compliance_weighted +
        attendance_weighted
    , 2) AS final_score,

    DENSE_RANK() OVER (ORDER BY
        productivity_weighted +
        quality_weighted +
        adherence_weighted +
        compliance_weighted +
        attendance_weighted DESC
    ) AS overall_rank,

    CASE
        WHEN compliance_violations >= 1 THEN 'Not Eligible'
        WHEN (
            productivity_weighted +
            quality_weighted +
            adherence_weighted +
            compliance_weighted +
            attendance_weighted
        ) >= 85 THEN 'Eligible'
        ELSE 'Not Eligible'
    END AS bonus_status

FROM final_scores;

-- 20. Purpose: Final dashboard-ready view for March 2026 scorecard
CREATE OR REPLACE VIEW reporting.v_dashboard_scorecard AS
SELECT *
FROM mart.v_scorecard_march_2026_final_report;


-- 21. Reporting Query
SELECT *
FROM reporting.v_dashboard_scorecard;

-- Sample of Agents for Performance Bonus Eligibility
SELECT *
FROM reporting.v_dashboard_scorecard
WHERE bonus_status = 'Eligible';

-- List of Agents that not eligible and enroll to PIP
SELECT *
FROM reporting.v_dashboard_scorecard
WHERE bonus_status = 'Not Eligible';

