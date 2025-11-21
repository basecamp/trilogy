require_relative '../../lib/benchmark_runner'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

runner.run_suite('Data Operations - Data Types') do |r|
  r.setup_drivers

  # Create a table with various data types
  r.each_driver do |name, driver|
    driver.query('DROP TABLE IF EXISTS type_test')
    driver.query(<<~SQL)
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
      )
    SQL
  end

  # Benchmark: Insert various data types
  r.compare_drivers('INSERT mixed data types') do |driver|
    driver.query(<<~SQL)
      INSERT INTO type_test (
        int_col, bigint_col, float_col, double_col, decimal_col,
        varchar_col, text_col, date_col, datetime_col, timestamp_col,
        json_col, bool_col
      ) VALUES (
        42, 9223372036854775807, 3.14, 2.718281828, 99.99,
        'test string', 'long text content here', '2025-01-01', '2025-01-01 12:00:00', NOW(),
        '{"key": "value"}', TRUE
      )
    SQL
  end

  # Benchmark: SELECT various data types
  r.compare_drivers('SELECT mixed data types') do |driver|
    driver.query('SELECT * FROM type_test')
  end

  # Benchmark: Large TEXT
  large_text = 'x' * 10000
  r.compare_drivers('INSERT large TEXT') do |driver|
    escaped_text = driver.escape(large_text)
    driver.query("INSERT INTO type_test (text_col) VALUES ('#{escaped_text}')")
  end

  # Benchmark: Large BLOB
  r.compare_drivers('INSERT large BLOB') do |driver|
    large_blob = 'x' * 10000
    escaped_blob = driver.escape(large_blob)
    driver.query("INSERT INTO type_test (blob_col) VALUES ('#{escaped_blob}')")
  end

  # Benchmark: Complex JSON
  r.compare_drivers('INSERT complex JSON') do |driver|
    json_data = driver.escape('{"users": [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}], "meta": {"count": 2}}')
    driver.query("INSERT INTO type_test (json_col) VALUES ('#{json_data}')")
  end

  # Memory benchmark with different data types
  r.benchmark_memory('mixed data types memory') do |driver|
    100.times do
      driver.query(<<~SQL)
        INSERT INTO type_test (
          int_col, varchar_col, text_col, datetime_col, json_col
        ) VALUES (
          42, 'test', 'some text', NOW(), '{"key": "value"}'
        )
      SQL
    end
  end

  # Cleanup
  r.each_driver do |name, driver|
    driver.query('DROP TABLE type_test')
  end

  r.teardown_drivers
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('Data Operations - Data Types', runner.collector.summary)
