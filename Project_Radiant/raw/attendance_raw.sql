-- create table raw.attendance_raw
DROP TABLE IF EXISTS raw.attendance_raw;
CREATE TABLE raw.attendance_raw (
    emp_id INT,
    attendance_id INT,
    attendance_date DATE,
    time_in TIME,
    time_out TIME,
    late_minutes INT,
    undertime_minutes INT,
    production_hours NUMERIC(10,2),
    status TEXT,
    absent_reason TEXT
);