-- Benchmark database schema

DROP DATABASE IF EXISTS trilogy_benchmark;
CREATE DATABASE trilogy_benchmark;
USE trilogy_benchmark;

-- Main benchmark table
CREATE TABLE benchmark_data (
  id INT PRIMARY KEY AUTO_INCREMENT,
  data VARCHAR(255),
  created_at DATETIME,
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table for testing various data types
CREATE TABLE type_test (
  id INT PRIMARY KEY AUTO_INCREMENT,
  int_col INT,
  bigint_col BIGINT,
  float_col FLOAT,
  double_col DOUBLE,
  decimal_col DECIMAL(10,2),
  varchar_col VARCHAR(255),
  text_col TEXT,
  blob_col BLOB,
  date_col DATE,
  datetime_col DATETIME,
  timestamp_col TIMESTAMP,
  json_col JSON,
  bool_col BOOLEAN
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed some initial data for basic benchmarks
INSERT INTO benchmark_data (data, created_at)
SELECT
  CONCAT('seed_row_', n),
  NOW()
FROM (
  SELECT a.N + b.N * 10 + c.N * 100 + 1 n
  FROM
    (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a,
    (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b,
    (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) c
) numbers
WHERE n <= 1000;
