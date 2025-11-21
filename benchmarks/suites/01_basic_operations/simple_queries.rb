require_relative '../../lib/benchmark_runner'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

runner.run_suite('Basic Operations - Simple Queries') do |r|
  # Benchmark: SELECT 1
  r.compare_drivers('SELECT 1') do |driver|
    driver.query('SELECT 1')
  end

  # Benchmark: Simple SELECT with WHERE
  r.compare_drivers('SELECT with WHERE') do |driver|
    driver.query('SELECT * FROM benchmark_data WHERE id = 1')
  end

  # Benchmark: Simple INSERT
  r.compare_drivers('Simple INSERT') do |driver|
    driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('test', NOW())")
  end

  # Benchmark: Simple UPDATE
  r.compare_drivers('Simple UPDATE') do |driver|
    driver.query("UPDATE benchmark_data SET data = 'updated' WHERE id = 1")
  end

  # Benchmark: Simple DELETE
  r.compare_drivers('Simple DELETE') do |driver|
    driver.query("DELETE FROM benchmark_data WHERE id = 999999")
  end

  # Benchmark: Query with result iteration
  r.compare_drivers('SELECT with result iteration') do |driver|
    result = driver.query('SELECT * FROM benchmark_data LIMIT 100')
    result.each { |row| row } if result.respond_to?(:each)
  end

  # Memory benchmarks
  r.benchmark_memory('SELECT 1 memory') do |driver|
    100.times { driver.query('SELECT 1') }
  end

  r.benchmark_memory('SELECT with results memory') do |driver|
    100.times do
      result = driver.query('SELECT * FROM benchmark_data LIMIT 100')
      result.each { |row| row } if result.respond_to?(:each)
    end
  end

  # GC impact
  r.benchmark_gc_impact('SELECT queries') do |driver|
    driver.query('SELECT * FROM benchmark_data LIMIT 10')
  end
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('Simple Queries', runner.collector.summary)
