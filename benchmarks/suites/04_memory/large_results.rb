require_relative '../../lib/benchmark_runner'
require 'benchmark/memory'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

runner.run_suite('Memory - Large Results') do |r|
  r.setup_drivers

  # Seed large dataset
  puts "Seeding large dataset..."
  r.each_driver do |name, driver|
    driver.query('TRUNCATE TABLE benchmark_data')

    # Insert 50,000 rows in batches
    500.times do |batch|
      values = 100.times.map { |i| "('row_#{batch * 100 + i}_with_more_data_to_increase_size', NOW())" }.join(', ')
      driver.query("INSERT INTO benchmark_data (data, created_at) VALUES #{values}")
    end
  end

  # Benchmark: Large result set memory
  puts "\n--- Large Result Set Memory Usage ---"
  [100, 1000, 10000, 50000].each do |limit|
    puts "\n  #{limit} rows:"

    r.each_driver do |name, driver|
      puts "    #{name}:"

      report = Benchmark.memory do |x|
        x.report("select #{limit}") do
          result = driver.query("SELECT * FROM benchmark_data LIMIT #{limit}")
          count = 0
          result.each { |row| count += 1 } if result.respond_to?(:each)
        end
      end

      entry = report.entries.first
      total_mb = (entry.measurement.memory.allocated / 1024.0 / 1024.0).round(2)
      per_row = entry.measurement.memory.allocated / limit

      puts "      Total allocated: #{total_mb} MB"
      puts "      Per row: #{per_row} bytes"
      puts "      Allocated objects: #{entry.measurement.objects.allocated}"
      puts "      Retained: #{entry.measurement.memory.retained} bytes"
    end
  end

  # Benchmark: Streaming vs loading all at once
  puts "\n--- Memory: Streaming Behavior ---"

  r.each_driver do |name, driver|
    puts "  #{name}:"

    # Measure peak memory during result iteration
    GC.start
    before_stat = GC.stat

    result = driver.query("SELECT * FROM benchmark_data LIMIT 10000")

    after_query_stat = GC.stat
    query_objects = after_query_stat[:total_allocated_objects] - before_stat[:total_allocated_objects]

    count = 0
    result.each { |row| count += 1 } if result.respond_to?(:each)

    after_iteration_stat = GC.stat
    iteration_objects = after_iteration_stat[:total_allocated_objects] - after_query_stat[:total_allocated_objects]

    puts "    Objects from query: #{query_objects}"
    puts "    Objects from iteration: #{iteration_objects}"
    puts "    Total: #{query_objects + iteration_objects}"
    puts "    Ratio: #{(iteration_objects.to_f / query_objects * 100).round(2)}%"
  end

  # Benchmark: Large BLOB/TEXT fields
  puts "\n--- Large BLOB/TEXT Memory ---"

  # Create test table with large fields
  r.each_driver do |name, driver|
    driver.query('DROP TABLE IF EXISTS large_field_test')
    driver.query('CREATE TABLE large_field_test (id INT PRIMARY KEY AUTO_INCREMENT, large_text TEXT, large_blob BLOB)')

    # Insert rows with large content
    10.times do |i|
      large_content = 'x' * 100000  # 100KB per field
      escaped = driver.escape(large_content)
      driver.query("INSERT INTO large_field_test (large_text, large_blob) VALUES ('#{escaped}', '#{escaped}')")
    end
  end

  r.each_driver do |name, driver|
    puts "  #{name}:"

    report = Benchmark.memory do |x|
      x.report("large fields") do
        result = driver.query("SELECT * FROM large_field_test")
        result.each { |row| row } if result.respond_to?(:each)
      end
    end

    entry = report.entries.first
    total_mb = (entry.measurement.memory.allocated / 1024.0 / 1024.0).round(2)
    per_row = (entry.measurement.memory.allocated / 10.0 / 1024.0 / 1024.0).round(2)

    puts "    Total allocated: #{total_mb} MB"
    puts "    Per row (200KB data): #{per_row} MB"
    puts "    Overhead ratio: #{(per_row / 0.2).round(2)}x"
  end

  # Cleanup
  r.each_driver do |name, driver|
    driver.query('DROP TABLE large_field_test')
  end

  # Benchmark: Repeated large queries (memory stability)
  puts "\n--- Repeated Large Queries (Memory Leak Test) ---"

  r.each_driver do |name, driver|
    puts "  #{name}:"

    GC.start
    initial_rss = `ps -o rss= -p #{Process.pid}`.to_i

    memory_samples = []

    10.times do |i|
      # Run large query
      result = driver.query("SELECT * FROM benchmark_data LIMIT 10000")
      result.each { |row| row } if result.respond_to?(:each)

      # Force GC and measure
      GC.start
      current_rss = `ps -o rss= -p #{Process.pid}`.to_i
      memory_samples << current_rss

      if i % 2 == 0
        puts "    Iteration #{i + 1}: #{current_rss} KB (Δ #{current_rss - initial_rss} KB)"
      end
    end

    # Analyze trend
    early_avg = memory_samples[0..2].sum / 3
    late_avg = memory_samples[-3..-1].sum / 3
    growth = late_avg - early_avg

    puts "    Early iterations avg: #{early_avg} KB"
    puts "    Late iterations avg: #{late_avg} KB"
    puts "    Growth: #{growth} KB"
    puts "    #{growth > 1000 ? 'POTENTIAL LEAK' : 'STABLE'}"
  end

  r.teardown_drivers
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('Memory - Large Results', runner.collector.summary)
