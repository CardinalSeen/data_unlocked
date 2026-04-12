--19. KPI for computation
CREATE OR REPLACE VIEW mart.v_scorecard_march_2026_final_report AS

WITH productivity_monthly AS (
    SELECT
        emp_id,
        SUM(COALESCE(transactions_completed, 0)) AS total_transactions
    FROM mart.fact_productivity
    WHERE transaction_date >= DATE '2026-03-01'
      AND transaction_date <  DATE '2026-04-01'
    GROUP BY emp_id
),

quality_monthly AS (
    SELECT
        emp_id,
        COUNT(*) AS quality_audit_count,
        ROUND(AVG(COALESCE(score, 0)), 2) AS avg_quality_score
    FROM mart.fact_quality
    WHERE audit_date >= DATE '2026-03-01'
      AND audit_date <  DATE '2026-04-01'
    GROUP BY emp_id
),

adherence_monthly AS (
    SELECT
        emp_id,
        COUNT(*) FILTER (
            WHERE
                (UPPER(status) = 'MISSED SLA' AND UPPER(status_reason) = 'AGENT DELAY')
                OR
                (UPPER(status) = 'AGENT ERROR' AND UPPER(status_reason) IN (
                    'INCORRECT BENEFIT CODE INPUT',
                    'INCORRECT ADDRESS INPUT'
                ))
        ) AS adherence_count
    FROM mart.fact_adherence
    WHERE adherence_date >= DATE '2026-03-01'
      AND adherence_date <  DATE '2026-04-01'
    GROUP BY emp_id
),

compliance_monthly AS (
    SELECT
        emp_id,
        COUNT(*) FILTER (
            WHERE UPPER(status) <> 'NO VIOLATION'
        ) AS compliance_violations
    FROM mart.fact_compliance
    WHERE compliance_date >= DATE '2026-03-01'
      AND compliance_date <  DATE '2026-04-01'
    GROUP BY emp_id
),

attendance_monthly AS (
    SELECT
        emp_id,
        SUM(
            CASE
                WHEN UPPER(status) = 'ABSENT'
                     AND UPPER(COALESCE(absent_reason,'')) IN (
                         'EMERGENCY','SICK','SICK LEAVE','NCNS','NO CALL, NO SHOW'
                     )
                THEN 1
                WHEN UPPER(status) = 'LATE' AND COALESCE(late_minutes,0) > 450
                THEN 1
                ELSE 0
            END
        ) AS counted_absences
    FROM mart.fact_attendance
    WHERE attendance_date >= DATE '2026-03-01'
      AND attendance_date <  DATE '2026-04-01'
    GROUP BY emp_id
),

final_scores AS (
    SELECT
        d.emp_id,
        d.employee_name,
        d.team_lead,

        COALESCE(p.total_transactions, 0) AS total_transactions,
        COALESCE(q.avg_quality_score, 0) AS avg_quality_score,
        COALESCE(q.quality_audit_count, 0) AS quality_audit_count,
        COALESCE(a.adherence_count, 0) AS adherence_count,
        COALESCE(c.compliance_violations, 0) AS compliance_violations,
        COALESCE(att.counted_absences, 0) AS counted_absences,

        -- Productivity
        CASE
            WHEN p.total_transactions >= 1401 THEN 100
            WHEN p.total_transactions BETWEEN 1351 AND 1400 THEN 95
            WHEN p.total_transactions BETWEEN 1301 AND 1350 THEN 90
            WHEN p.total_transactions BETWEEN 1251 AND 1300 THEN 85
            WHEN p.total_transactions BETWEEN 1201 AND 1250 THEN 80
            WHEN p.total_transactions BETWEEN 1151 AND 1200 THEN 75
            WHEN p.total_transactions BETWEEN 1101 AND 1150 THEN 70
            WHEN p.total_transactions BETWEEN 1001 AND 1050 THEN 65
            ELSE 0
        END AS productivity_score,

        -- Weighted
        ROUND(
            CASE
                WHEN p.total_transactions >= 1401 THEN 100
                WHEN p.total_transactions BETWEEN 1351 AND 1400 THEN 95
                WHEN p.total_transactions BETWEEN 1301 AND 1350 THEN 90
                WHEN p.total_transactions BETWEEN 1251 AND 1300 THEN 85
                WHEN p.total_transactions BETWEEN 1201 AND 1250 THEN 80
                WHEN p.total_transactions BETWEEN 1151 AND 1200 THEN 75
                WHEN p.total_transactions BETWEEN 1101 AND 1150 THEN 70
                WHEN p.total_transactions BETWEEN 1001 AND 1050 THEN 65
                ELSE 0
            END * 0.30, 2
        ) AS productivity_weighted,

        -- Quality
        CASE WHEN q.avg_quality_score < 70 THEN 0 ELSE q.avg_quality_score END AS quality_score,
        ROUND(
            CASE WHEN q.avg_quality_score < 70 THEN 0 ELSE q.avg_quality_score * 0.20 END, 2
        ) AS quality_weighted,

        -- Adherence
        CASE
            WHEN a.adherence_count = 0 THEN 100
            WHEN a.adherence_count = 1 THEN 95
            WHEN a.adherence_count = 2 THEN 90
            WHEN a.adherence_count = 3 THEN 85
            WHEN a.adherence_count = 4 THEN 80
            WHEN a.adherence_count = 5 THEN 75
            WHEN a.adherence_count = 6 THEN 70
            ELSE 0
        END AS adherence_score,

        ROUND(
            CASE
                WHEN a.adherence_count = 0 THEN 100
                WHEN a.adherence_count = 1 THEN 95
                WHEN a.adherence_count = 2 THEN 90
                WHEN a.adherence_count = 3 THEN 85
                WHEN a.adherence_count = 4 THEN 80
                WHEN a.adherence_count = 5 THEN 75
                WHEN a.adherence_count = 6 THEN 70
                ELSE 0
            END * 0.20, 2
        ) AS adherence_weighted,

        -- Compliance
        CASE WHEN c.compliance_violations >= 1 THEN 0 ELSE 100 END AS compliance_score,
        CASE WHEN c.compliance_violations >= 1 THEN 0 ELSE 20 END AS compliance_weighted,

        -- Attendance
        CASE
            WHEN att.counted_absences = 0 THEN 100
            WHEN att.counted_absences = 1 THEN 95
            WHEN att.counted_absences = 2 THEN 90
            WHEN att.counted_absences = 3 THEN 85
            WHEN att.counted_absences = 4 THEN 80
            WHEN att.counted_absences = 5 THEN 75
            ELSE 0
        END AS attendance_score,

        ROUND(
            CASE
                WHEN att.counted_absences = 0 THEN 100
                WHEN att.counted_absences = 1 THEN 95
                WHEN att.counted_absences = 2 THEN 90
                WHEN att.counted_absences = 3 THEN 85
                WHEN att.counted_absences = 4 THEN 80
                WHEN att.counted_absences = 5 THEN 75
                ELSE 0
            END * 0.10, 2
        ) AS attendance_weighted

    FROM mart.dim_employee d
    LEFT JOIN productivity_monthly p ON d.emp_id = p.emp_id
    LEFT JOIN quality_monthly q ON d.emp_id = q.emp_id
    LEFT JOIN adherence_monthly a ON d.emp_id = a.emp_id
    LEFT JOIN compliance_monthly c ON d.emp_id = c.emp_id
    LEFT JOIN attendance_monthly att ON d.emp_id = att.emp_id
)

SELECT
    employee_name,
    team_lead,

    LEFT(emp_id::text, LENGTH(emp_id::text) - 5) || '*****' AS masked_emp_id,

    total_transactions,
    avg_quality_score,
    quality_audit_count,
    adherence_count,
    compliance_violations,
    counted_absences,

    productivity_weighted,
    quality_weighted,
    adherence_weighted,
    compliance_weighted,
    attendance_weighted,

    ROUND(
        productivity_weighted +
        quality_weighted +
        adherence_weighted +
        compliance_weighted +
        attendance_weighted
    , 2) AS final_score,

    DENSE_RANK() OVER (ORDER BY
        productivity_weighted +
        quality_weighted +
        adherence_weighted +
        compliance_weighted +
        attendance_weighted DESC
    ) AS overall_rank,

    CASE
        WHEN compliance_violations >= 1 THEN 'Not Eligible'
        WHEN (
            productivity_weighted +
            quality_weighted +
            adherence_weighted +
            compliance_weighted +
            attendance_weighted
        ) >= 85 THEN 'Eligible'
        ELSE 'Not Eligible'
    END AS bonus_status

FROM final_scores;