require_relative '../../lib/benchmark_runner'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

RESULT_SIZES = [10, 100, 1000, 10000]

runner.run_suite('Data Operations - Bulk Select') do |r|
  r.setup_drivers

  # Seed data
  puts "Seeding data..."
  r.each_driver do |name, driver|
    driver.query('TRUNCATE TABLE benchmark_data')
    # Insert 10000 rows for testing
    1000.times do |batch|
      values = 10.times.map { |i| "('row_#{batch * 10 + i}', NOW())" }.join(', ')
      driver.query("INSERT INTO benchmark_data (data, created_at) VALUES #{values}")
    end
  end

  RESULT_SIZES.each do |limit|
    # Benchmark: SELECT with LIMIT
    r.compare_drivers("SELECT #{limit} rows") do |driver|
      driver.query("SELECT * FROM benchmark_data LIMIT #{limit}")
    end

    # Benchmark: SELECT with result iteration
    r.compare_drivers("SELECT and iterate #{limit} rows") do |driver|
      result = driver.query("SELECT * FROM benchmark_data LIMIT #{limit}")
      count = 0
      result.each { |row| count += 1 } if result.respond_to?(:each)
    end

    # Memory benchmark
    if limit <= 1000
      r.benchmark_memory("SELECT memory (#{limit} rows)") do |driver|
        10.times do
          result = driver.query("SELECT * FROM benchmark_data LIMIT #{limit}")
          result.each { |row| row } if result.respond_to?(:each)
        end
      end
    end
  end

  # Benchmark: SELECT with WHERE clause (indexed)
  r.compare_drivers('SELECT with WHERE (indexed)') do |driver|
    driver.query("SELECT * FROM benchmark_data WHERE id < 100")
  end

  # Benchmark: SELECT with WHERE clause (non-indexed)
  r.compare_drivers('SELECT with WHERE (non-indexed)') do |driver|
    driver.query("SELECT * FROM benchmark_data WHERE data LIKE 'row_1%' LIMIT 100")
  end

  # Benchmark: SELECT COUNT
  r.compare_drivers('SELECT COUNT(*)') do |driver|
    driver.query('SELECT COUNT(*) FROM benchmark_data')
  end

  # Benchmark: SELECT with ORDER BY
  r.compare_drivers('SELECT with ORDER BY') do |driver|
    driver.query('SELECT * FROM benchmark_data ORDER BY id DESC LIMIT 100')
  end

  # GC impact
  r.benchmark_gc_impact('SELECT GC impact (100 rows)') do |driver|
    result = driver.query('SELECT * FROM benchmark_data LIMIT 100')
    result.each { |row| row } if result.respond_to?(:each)
  end

  r.teardown_drivers
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('Data Operations - Bulk Select', runner.collector.summary)
