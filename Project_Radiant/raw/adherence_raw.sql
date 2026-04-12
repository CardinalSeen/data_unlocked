--create raw.adherence_raw
DROP TABLE IF EXISTS raw.adherence_raw;
CREATE TABLE raw.adherence_raw (
    emp_id INT,
    case_id INT,
    status TEXT,
    status_reason TEXT,
	adherence_date DATE
);