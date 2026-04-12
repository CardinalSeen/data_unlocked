--create stg.quality
DROP TABLE IF EXISTS stg.quality;
CREATE TABLE stg.quality AS
SELECT
    emp_id,
    TRIM(employee_name) AS employee_name,
    quality_id,
    COALESCE(score, 0) AS score,
    INITCAP(TRIM(status)) AS status,
	CAST(audit_date AS DATE) AS audit_date -- to update the audit_date from raw
FROM raw.quality_raw
WHERE emp_id IS NOT NULL;