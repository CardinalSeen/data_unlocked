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