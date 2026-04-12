--8. Create fact_attendance
DROP TABLE IF EXISTS mart.fact_attendance;
CREATE TABLE mart.fact_attendance (
    attendance_id INT PRIMARY KEY,
    emp_id INT NOT NULL REFERENCES mart.dim_employee(emp_id),
    attendance_date DATE NOT NULL,
    time_in TIME,
    time_out TIME,
    late_minutes INT DEFAULT 0,
    undertime_minutes INT DEFAULT 0,
    production_hours NUMERIC(10,2) DEFAULT 0,
    status TEXT,
    absent_reason TEXT
);

INSERT INTO mart.fact_attendance (
    attendance_id, emp_id, attendance_date, time_in, time_out,
    late_minutes, undertime_minutes, production_hours, status, absent_reason
)
SELECT
    attendance_id,
    emp_id,
    attendance_date,
    time_in,
    time_out,
    late_minutes,
    undertime_minutes,
    production_hours,
    status,
    absent_reason
FROM stg.attendance;
