require_relative '../../lib/benchmark_runner'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

runner.run_suite('Advanced - Transactions') do |r|
  r.setup_drivers

  # Clear test data
  r.each_driver { |_, d| d.query('TRUNCATE TABLE benchmark_data') }

  # Benchmark: Simple transaction
  r.compare_drivers('Simple transaction (1 INSERT)') do |driver|
    driver.transaction do
      driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('txn_test', NOW())")
    end
  end

  # Benchmark: Transaction with multiple operations
  r.compare_drivers('Transaction (10 INSERTs)') do |driver|
    driver.transaction do
      10.times do |i|
        driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('txn_#{i}', NOW())")
      end
    end
  end

  # Benchmark: Transaction with rollback
  r.compare_drivers('Transaction with ROLLBACK') do |driver|
    begin
      driver.transaction do
        driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('rollback_test', NOW())")
        raise "intentional rollback"
      end
    rescue => e
      # Expected
    end
  end

  # Benchmark: Nested transaction simulation (savepoints)
  r.compare_drivers('Nested transaction (savepoints)') do |driver|
    driver.query('BEGIN')
    driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('outer', NOW())")
    driver.query('SAVEPOINT sp1')
    driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('inner', NOW())")
    driver.query('ROLLBACK TO sp1')
    driver.query('COMMIT')
  end

  # Memory benchmark
  r.benchmark_memory('Transaction memory (100 ops)') do |driver|
    10.times do
      driver.transaction do
        10.times do |i|
          driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('mem_test_#{i}', NOW())")
        end
      end
    end
  end

  # Cleanup
  r.each_driver { |_, d| d.query('TRUNCATE TABLE benchmark_data') }

  r.teardown_drivers
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('Advanced - Transactions', runner.collector.summary)
