require_relative '../../lib/benchmark_runner'
require 'benchmark/memory'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

runner.run_suite('Memory - Allocations') do |r|
  r.setup_drivers

  # Benchmark: Connection allocations
  puts "\n--- Connection Allocations ---"
  r.each_driver_class do |name, driver_class|
    puts "  #{name}:"

    report = Benchmark.memory do |x|
      x.report("connect/disconnect") do
        conn = driver_class.new(r.db_config)
        conn.connect
        conn.disconnect
      end
    end

    entry = report.entries.first
    puts "    Total allocated: #{entry.measurement.memory.allocated} bytes"
    puts "    Total retained: #{entry.measurement.memory.retained} bytes"
    puts "    Allocated objects: #{entry.measurement.objects.allocated}"
    puts "    Retained objects: #{entry.measurement.objects.retained}"
  end

  # Benchmark: Query allocations
  puts "\n--- Query Allocations ---"
  r.each_driver do |name, driver|
    puts "  #{name}:"

    report = Benchmark.memory do |x|
      x.report("SELECT 1") do
        100.times { driver.query('SELECT 1') }
      end
    end

    entry = report.entries.first
    avg_allocated = entry.measurement.memory.allocated / 100
    avg_retained = entry.measurement.memory.retained / 100

    puts "    Per query allocated: #{avg_allocated} bytes"
    puts "    Per query retained: #{avg_retained} bytes"
    puts "    Total objects: #{entry.measurement.objects.allocated}"
  end

  # Benchmark: Result set allocations
  puts "\n--- Result Set Allocations ---"
  [10, 100, 1000].each do |limit|
    puts "\n  #{limit} rows:"

    r.each_driver do |name, driver|
      puts "    #{name}:"

      report = Benchmark.memory do |x|
        x.report("SELECT #{limit}") do
          result = driver.query("SELECT * FROM benchmark_data LIMIT #{limit}")
          result.each { |row| row } if result.respond_to?(:each)
        end
      end

      entry = report.entries.first
      per_row = entry.measurement.memory.allocated / limit

      puts "      Total allocated: #{entry.measurement.memory.allocated} bytes"
      puts "      Per row: #{per_row} bytes"
      puts "      Allocated objects: #{entry.measurement.objects.allocated}"
    end
  end

  # Benchmark: String escaping allocations
  puts "\n--- String Escaping Allocations ---"
  test_strings = [
    "simple",
    "with 'quotes'",
    "longer string with more content and special chars: \n\t",
    "x" * 1000
  ]

  r.each_driver do |name, driver|
    puts "  #{name}:"

    test_strings.each_with_index do |str, i|
      report = Benchmark.memory do |x|
        x.report("escape #{i}") do
          100.times { driver.escape(str) }
        end
      end

      entry = report.entries.first
      avg = entry.measurement.memory.allocated / 100

      puts "    String #{i} (#{str.length} chars): #{avg} bytes/escape"
    end
  end

  # Benchmark: Insert allocations
  puts "\n--- Insert Allocations ---"
  r.each_driver do |name, driver|
    puts "  #{name}:"

    report = Benchmark.memory do |x|
      x.report("INSERT") do
        10.times do
          driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('test', NOW())")
        end
      end
    end

    entry = report.entries.first
    per_insert = entry.measurement.memory.allocated / 10

    puts "    Per INSERT: #{per_insert} bytes"
    puts "    Total objects: #{entry.measurement.objects.allocated}"

    # Cleanup
    driver.query('DELETE FROM benchmark_data WHERE data = "test"')
  end

  # Detailed memory profiling with MemoryProfiler
  puts "\n--- Detailed Memory Profile (100 queries) ---"
  r.each_driver do |name, driver|
    puts "  #{name}:"

    require 'memory_profiler'
    report = MemoryProfiler.report do
      100.times { driver.query('SELECT 1') }
    end

    puts "    Total allocated: #{report.total_allocated_memsize} bytes"
    puts "    Total retained: #{report.total_retained_memsize} bytes"
    puts "    Allocated objects: #{report.total_allocated}"
    puts "    Retained objects: #{report.total_retained}"
    puts "    Strings allocated: #{report.strings_allocated}"
    puts "    Strings retained: #{report.strings_retained}"

    # Top allocations by class
    puts "    Top 5 allocated classes:"
    report.allocated_memory_by_class.first(5).each do |item|
      puts "      #{item[:data]}: #{item[:count]} objects (#{item[:memsize]} bytes)"
    end
  end

  r.teardown_drivers
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('Memory - Allocations', runner.collector.summary)
