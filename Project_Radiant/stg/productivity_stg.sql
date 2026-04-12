--create stg.productivity
DROP TABLE IF EXISTS stg.productivity;
CREATE TABLE stg.productivity AS
SELECT
    emp_id,
    transaction_date,
    COALESCE(transactions_completed, 0) AS transactions_completed,
    INITCAP(TRIM(status)) AS status
FROM raw.productivity_raw
WHERE emp_id IS NOT NULL;