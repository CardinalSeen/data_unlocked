-- create table raw.productivity_raw
DROP TABLE IF EXISTS raw.productivity_raw;
CREATE TABLE raw.productivity_raw (
    emp_id INT,
    transaction_date DATE,
    transactions_completed INT,
    status TEXT
);