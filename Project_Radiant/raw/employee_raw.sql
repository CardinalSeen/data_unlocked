-- create table raw.employee_raw
DROP TABLE IF EXISTS raw.employee_raw;
CREATE TABLE raw.employee_raw (
    emp_id INT,
    last_name TEXT,
    first_name TEXT,
    team TEXT,
    team_lead TEXT
);

