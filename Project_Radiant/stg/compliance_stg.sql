--create stg.compliance
DROP TABLE IF EXISTS stg.compliance;
CREATE TABLE stg.compliance AS
SELECT
    emp_id,
    comp_id,
	CAST(compliance_date AS DATE) AS compliance_date,
    TRIM(status) AS status,
    COALESCE(NULLIF(TRIM(status_reason), ''), 'N/A') AS status_reason	
FROM raw.compliance_raw
WHERE emp_id IS NOT NULL;
