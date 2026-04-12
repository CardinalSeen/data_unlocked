--create raw.compliance_raw
DROP TABLE IF EXISTS raw.compliance_raw;
CREATE TABLE raw.compliance_raw (
    emp_id INT,
    comp_id INT,
	compliance_date DATE,
    status TEXT,
    status_reason TEXT
);
