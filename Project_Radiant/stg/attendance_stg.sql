--create stg.attendance
DROP TABLE IF EXISTS stg.attendance;
CREATE TABLE stg.attendance AS
SELECT
    emp_id,
    attendance_id,
    attendance_date,
    time_in,
    time_out,
    COALESCE(late_minutes, 0) AS late_minutes,
    COALESCE(undertime_minutes, 0) AS undertime_minutes,
    COALESCE(production_hours, 0) AS production_hours,
    INITCAP(TRIM(status)) AS status,
    COALESCE(NULLIF(TRIM(absent_reason), ''), 'N/A') AS absent_reason
FROM raw.attendance_raw
WHERE emp_id IS NOT NULL;