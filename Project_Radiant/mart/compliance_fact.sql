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
