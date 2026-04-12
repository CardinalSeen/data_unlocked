-- 14. Final Validation
-- this to clarify for the attendance vs productivity

--FINAL VALIDATION
SELECT
    a.emp_id,
    a.attendance_date,
    a.status AS attendance_status,
    a.absent_reason,
    COALESCE(p.transactions_completed, 0) AS transactions_completed,
    p.status AS validation_status,
    p.reconciliation_flag,
    p.validation_message
FROM mart.fact_attendance a
LEFT JOIN mart.fact_productivity p
  ON a.emp_id = p.emp_id
 AND a.attendance_date = p.transaction_date
ORDER BY a.emp_id, a.attendance_date;


-- 15. EXCEPTIONS
-- Data Engineer needs to coordinate to the MIS / Data Analyst or
-- Real Time Analyst to confirm if these validation message is valid such as low 
-- productivity for those agents in able to make the final scorecard.

SELECT
    a.emp_id,
    a.attendance_date,
    a.status AS attendance_status,
    a.absent_reason,
    COALESCE(p.transactions_completed, 0) AS transactions_completed,
    p.status AS validation_status,
    p.reconciliation_flag,
    p.validation_message
FROM mart.fact_attendance a
LEFT JOIN mart.fact_productivity p
  ON a.emp_id = p.emp_id
 AND a.attendance_date = p.transaction_date
WHERE p.status IN ('ERROR', 'WARNING')
ORDER BY a.emp_id, a.attendance_date;

-- 16. Quality Summary
SELECT
    emp_id,
    DATE_TRUNC('month', audit_date)::date AS audit_month,

    COUNT(*) AS total_quality_checks,
    ROUND(AVG(score), 2) AS avg_quality_score,

    SUM(CASE WHEN status = 'Pass' THEN 1 ELSE 0 END) AS passed_checks,
    SUM(CASE WHEN status = 'Fail' THEN 1 ELSE 0 END) AS failed_checks,

    CASE
        WHEN COUNT(*) = 5 THEN 'Complete'
        WHEN COUNT(*) < 5 THEN 'Incomplete'
        ELSE 'Over Audit'
    END AS audit_status

FROM mart.fact_quality
WHERE audit_date >= DATE '2026-03-01'
  AND audit_date <  DATE '2026-04-01'

GROUP BY emp_id, DATE_TRUNC('month', audit_date)
ORDER BY emp_id;

-- 17. Adherence Summary

SELECT
    emp_id,
    DATE_TRUNC('month', adherence_date)::date AS adherence_month,

    COUNT(*) AS total_cases,
    COUNT(*) FILTER (WHERE TRIM(UPPER(status)) = 'AGENT ERROR') AS agent_error,
    COUNT(*) FILTER (WHERE TRIM(UPPER(status)) = 'CANCELLED') AS cancelled,
    COUNT(*) FILTER (WHERE TRIM(UPPER(status)) IN ('ON-HOLD', 'ON HOLD')) AS on_hold,
    COUNT(*) FILTER (WHERE TRIM(UPPER(status)) = 'MISSED SLA') AS missed_sla,

    COUNT(*) FILTER (
        WHERE
            (TRIM(UPPER(status)) = 'MISSED SLA' AND TRIM(UPPER(status_reason)) = 'AGENT DELAY')
            OR
            (TRIM(UPPER(status)) = 'AGENT ERROR' AND TRIM(UPPER(status_reason)) IN (
                'INCORRECT BENEFIT CODE INPUT',
                'INCORRECT ADDRESS INPUT'
            ))
    ) AS counted_adherence_issues

FROM mart.fact_adherence
WHERE adherence_date >= DATE '2026-03-01'
  AND adherence_date <  DATE '2026-04-01'

GROUP BY emp_id, DATE_TRUNC('month', adherence_date)
ORDER BY emp_id;


--18. Compliance Summary
SELECT
    DATE_TRUNC('month', compliance_date)::date AS compliance_month,
    status,
    COUNT(*) AS total_records,

    SUM(
        CASE
            WHEN TRIM(UPPER(status)) = 'NO VIOLATION' THEN 0
            ELSE 1
        END
    ) AS total_violations

FROM mart.fact_compliance
WHERE compliance_date >= DATE '2026-03-01'
  AND compliance_date <  DATE '2026-04-01'

GROUP BY DATE_TRUNC('month', compliance_date), status
ORDER BY total_records DESC;