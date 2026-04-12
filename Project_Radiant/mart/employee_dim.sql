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