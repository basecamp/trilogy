require_relative '../../lib/benchmark_runner'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

BATCH_SIZES = [10, 100, 1000, 10000]

runner.run_suite('Data Operations - Bulk Insert') do |r|
  r.setup_drivers

  # Clear table before benchmarks
  r.each_driver do |name, driver|
    driver.query('TRUNCATE TABLE benchmark_data')
  end

  BATCH_SIZES.each do |batch_size|
    # Benchmark: Individual INSERTs
    r.compare_drivers("individual INSERTs (#{batch_size} rows)") do |driver|
      batch_size.times do |i|
        driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('row_#{i}', NOW())")
      end
    end

    # Clear table between benchmarks
    r.each_driver { |_, d| d.query('TRUNCATE TABLE benchmark_data') }

    # Benchmark: Batch INSERT with multiple VALUE clauses
    r.compare_drivers("batch INSERT (#{batch_size} rows)") do |driver|
      values = batch_size.times.map { |i| "('row_#{i}', NOW())" }.join(', ')
      driver.query("INSERT INTO benchmark_data (data, created_at) VALUES #{values}")
    end

    # Clear table
    r.each_driver { |_, d| d.query('TRUNCATE TABLE benchmark_data') }

    # Memory benchmark for bulk inserts
    if batch_size <= 1000  # Only test smaller sizes for memory
      r.benchmark_memory("bulk insert memory (#{batch_size} rows)") do |driver|
        values = batch_size.times.map { |i| "('row_#{i}', NOW())" }.join(', ')
        driver.query("INSERT INTO benchmark_data (data, created_at) VALUES #{values}")
      end

      r.each_driver { |_, d| d.query('TRUNCATE TABLE benchmark_data') }
    end
  end

  # GC impact of bulk inserts
  r.benchmark_gc_impact('bulk insert GC (100 rows)') do |driver|
    values = 100.times.map { |i| "('row_#{i}', NOW())" }.join(', ')
    driver.query("INSERT INTO benchmark_data (data, created_at) VALUES #{values}")
    driver.query('TRUNCATE TABLE benchmark_data')
  end

  r.teardown_drivers
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('Data Operations - Bulk Insert', runner.collector.summary)
