-- 9. Create fact_productivity
DROP TABLE IF EXISTS mart.fact_productivity;
CREATE TABLE mart.fact_productivity (
    transaction_sk BIGSERIAL PRIMARY KEY,
    emp_id INT NOT NULL REFERENCES mart.dim_employee(emp_id),
    transaction_date DATE NOT NULL,
    transactions_completed INT DEFAULT 0,
    status TEXT,
    reconciliation_flag TEXT,
    validation_message TEXT
);

INSERT INTO mart.fact_productivity (
    emp_id,
    transaction_date,
    transactions_completed,
    status,
    reconciliation_flag,
    validation_message
)
SELECT
    a.emp_id,
    a.attendance_date AS transaction_date,

    /* Match stg rule:
       If absent with approved leave, productivity should be forced to 0 */
    CASE
        WHEN UPPER(a.status) = 'ABSENT'
             AND UPPER(COALESCE(a.absent_reason, '')) IN
                 ('NCSC', 'VACATION', 'VACATION LEAVE', 'SICK', 'SICK LEAVE', 'EMERGENCY', 'EMERGENCY LEAVE')
            THEN 0
        ELSE COALESCE(p.transactions_completed, 0)
    END AS transactions_completed,

    /* Match stg validation_status */
    CASE
        WHEN UPPER(a.status) = 'ABSENT'
             AND UPPER(COALESCE(a.absent_reason, '')) IN
                 ('NCSC', 'VACATION', 'VACATION LEAVE', 'SICK', 'SICK LEAVE', 'EMERGENCY', 'EMERGENCY LEAVE')
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'ERROR'

        WHEN UPPER(a.status) = 'PRESENT'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'WARNING'

        WHEN UPPER(a.status) = 'LATE'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'WARNING'

        WHEN a.status IS NULL
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'ERROR'

        ELSE 'OK'
    END AS status,

    /* Match stg validation_status in a more business-friendly label */
    CASE
        WHEN UPPER(a.status) = 'ABSENT'
             AND UPPER(COALESCE(a.absent_reason, '')) IN
                 ('NCSC', 'VACATION', 'VACATION LEAVE', 'SICK', 'SICK LEAVE', 'EMERGENCY', 'EMERGENCY LEAVE')
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'Mismatch - should be zero'

        WHEN UPPER(a.status) = 'PRESENT'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'Review - present but zero productivity'

        WHEN UPPER(a.status) = 'LATE'
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'Review - late but zero productivity'

        WHEN a.status IS NULL
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'Mismatch - no attendance but has productivity'

        WHEN UPPER(a.status) = 'ABSENT'
             AND UPPER(COALESCE(a.absent_reason, '')) IN
                 ('NCSC', 'VACATION', 'VACATION LEAVE', 'SICK', 'SICK LEAVE', 'EMERGENCY', 'EMERGENCY LEAVE')
             AND COALESCE(p.transactions_completed, 0) = 0
            THEN 'Aligned - approved absence'

        WHEN UPPER(a.status) = 'PRESENT'
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'Aligned - present with productivity'

        WHEN UPPER(a.status) = 'LATE'
             AND COALESCE(p.transactions_completed, 0) > 0
            THEN 'Aligned - late with productivity'

        ELSE 'OK'
    END AS reconciliation_flag,

    /* Match stg validation_message */
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

FROM mart.fact_attendance a
LEFT JOIN stg.productivity p
  ON a.emp_id = p.emp_id
 AND a.attendance_date = p.transaction_date;