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