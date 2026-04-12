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