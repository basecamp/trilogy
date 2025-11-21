require_relative '../../lib/benchmark_runner'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

runner.run_suite('Basic Operations - Metadata') do |r|
  # Setup: Insert a row to get metadata from
  r.setup_drivers
  r.each_driver do |name, driver|
    driver.query('DELETE FROM benchmark_data WHERE id > 0')
    driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('test', NOW())")
  end

  # Benchmark: last_insert_id
  r.compare_drivers('last_insert_id') do |driver|
    driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('test', NOW())")
    driver.last_insert_id
  end

  # Benchmark: affected_rows after INSERT
  r.compare_drivers('affected_rows (INSERT)') do |driver|
    driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('test', NOW())")
    driver.affected_rows
  end

  # Benchmark: affected_rows after UPDATE
  r.compare_drivers('affected_rows (UPDATE)') do |driver|
    driver.query("UPDATE benchmark_data SET data = 'updated' WHERE id = 1")
    driver.affected_rows
  end

  # Benchmark: affected_rows after DELETE
  r.compare_drivers('affected_rows (DELETE)') do |driver|
    driver.query("DELETE FROM benchmark_data WHERE id = 999999")
    driver.affected_rows
  end

  # Benchmark: server_info
  r.compare_drivers('server_info') do |driver|
    driver.server_info
  end

  # Benchmark: driver_version
  r.compare_drivers('driver_version') do |driver|
    driver.driver_version
  end

  # Trilogy-specific: warning_count (if available)
  trilogy = r.driver('trilogy')
  if trilogy.respond_to?(:warning_count)
    puts "\nTrilogy-specific benchmarks:"
    r.collector.measure_performance('warning_count (trilogy)') do
      trilogy.query('SELECT 1')
      trilogy.warning_count
    end
  end

  r.teardown_drivers
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('Basic Operations - Metadata', runner.collector.summary)
