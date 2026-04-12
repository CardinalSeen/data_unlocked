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