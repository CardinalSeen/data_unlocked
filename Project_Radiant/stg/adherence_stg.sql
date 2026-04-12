DROP TABLE IF EXISTS stg.adherence;
CREATE TABLE stg.adherence AS
SELECT
    emp_id,
    case_id,
    INITCAP(TRIM(status)) AS status,
    COALESCE(NULLIF(TRIM(status_reason), ''), 'N/A') AS status_reason,
	CAST(adherence_date AS DATE) AS adherence_date --to update the adherence_date from raw
FROM raw.adherence_raw
WHERE emp_id IS NOT NULL;