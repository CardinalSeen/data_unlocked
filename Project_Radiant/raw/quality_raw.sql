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

