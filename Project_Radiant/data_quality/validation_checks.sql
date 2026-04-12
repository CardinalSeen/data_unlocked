--5. Data Quality Checks
-- to determine the duplicate employees and orphan records

/* Check duplicate emp_id sa employee table */
SELECT emp_id, COUNT(*)
FROM stg.employee
GROUP BY emp_id
HAVING COUNT(*) > 1;

/* Check orphan attendance records */
SELECT a.emp_id
FROM stg.attendance a
LEFT JOIN stg.employee e ON a.emp_id = e.emp_id
WHERE e.emp_id IS NULL;

/* Check orphan productivity records */
SELECT p.emp_id
FROM stg.productivity p
LEFT JOIN stg.employee e ON p.emp_id = e.emp_id
WHERE e.emp_id IS NULL;

/* Check orphan quality records */
SELECT q.emp_id
FROM stg.quality q
LEFT JOIN stg.employee e ON q.emp_id = e.emp_id
WHERE e.emp_id IS NULL;

/* Check orphan adherence records */
SELECT ad.emp_id
FROM stg.adherence ad
LEFT JOIN stg.employee e ON ad.emp_id = e.emp_id
WHERE e.emp_id IS NULL;

/* Check orphan compliance records */
SELECT c.emp_id
FROM stg.compliance c
LEFT JOIN stg.employee e ON c.emp_id = e.emp_id
WHERE e.emp_id IS NULL;

-- 6. Validation of attendance vs productivity
-- to validate if there is mismatch between productivity and attendance
-- here are the business rules
-- 6.1 If the agent is absent due to Emergency, Vacation or Sick Leaves the 
-- productivity should zero
-- 6.2 If the agent is late, it should be a productivity
-- 6.3 If the agent is present, it should be a productivity 

SELECT
    a.emp_id,
    a.attendance_date,
    a.status AS attendance_status,
    a.absent_reason,
    COALESCE(p.transactions_completed, 0) AS transactions_completed,
    p.status AS productivity_status,
    CASE
        /* Rule 1: Absent with approved leave reasons should have zero productivity */
        WHEN UPPER(a.status) = 'ABSENT'
             AND UPPER(COALESCE(a.absent_reason, '')) IN
                 ('NCSC', 'VACATION', 'VACATION LEAVE', 'SICK', 'SICK LEAVE', 'EMERGENCY', 'EMERGENCY LEAVE')
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'ERROR'

        /* Rule 2: Present but zero productivity is possible, but needs review */
        WHEN UPPER(a.status) = 'PRESENT'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'WARNING'

        /* Rule 3: Late but zero productivity is possible, but needs review */
        WHEN UPPER(a.status) = 'LATE'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'WARNING'

        /* Rule 4: No attendance record but has productivity */
        WHEN a.status IS NULL
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'ERROR'

        ELSE 'OK'
    END AS validation_status,
    CASE
        WHEN UPPER(a.status) = 'ABSENT'
             AND UPPER(COALESCE(a.absent_reason, '')) IN
                 ('NCSC', 'VACATION', 'VACATION LEAVE', 'SICK', 'SICK LEAVE', 'EMERGENCY', 'EMERGENCY LEAVE')
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'Absent agent with approved leave should have zero productivity'

        WHEN UPPER(a.status) = 'PRESENT'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'Present but zero productivity - check if training, admin work, system issue, or idle time'

        WHEN UPPER(a.status) = 'LATE'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'Late but zero productivity - check if partial shift, system issue, or no completed transactions'

        WHEN a.status IS NULL
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'Productivity exists but no attendance record found'

        ELSE 'Record passed validation'
    END AS validation_message
FROM stg.attendance a
LEFT JOIN stg.productivity p
  ON a.emp_id = p.emp_id
 AND a.attendance_date = p.transaction_date
ORDER BY a.emp_id, a.attendance_date;
