-- 20. Purpose: Final dashboard-ready view for March 2026 scorecard
CREATE OR REPLACE VIEW reporting.v_dashboard_scorecard AS
SELECT *
FROM mart.v_scorecard_march_2026_final_report;


-- 21. Reporting Query
SELECT *
FROM reporting.v_dashboard_scorecard;

-- Sample of Agents for Performance Bonus Eligibility
SELECT *
FROM reporting.v_dashboard_scorecard
WHERE bonus_status = 'Eligible';

-- List of Agents that not eligible and enroll to PIP
SELECT *
FROM reporting.v_dashboard_scorecard
WHERE bonus_status = 'Not Eligible';

SELECT employee_name, team_lead, productivity_weighted, quality_weighted, attendance_weighted,
	compliance_weighted, final_score
FROM reporting.v_dashboard_scorecard;
