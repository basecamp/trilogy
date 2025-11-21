require_relative '../../lib/benchmark_runner'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

runner.run_suite('Basic Operations - Connection') do |r|
  # Benchmark: Connect and disconnect
  # Note: This benchmark creates many connections rapidly, which can exhaust
  # MySQL's max_connections. We measure it manually with fewer iterations.
  puts Rainbow("  Benchmarking: connect_disconnect (manual timing)").yellow

  r.each_driver_class do |name, driver_class|
    iterations = 100
    times = []

    iterations.times do
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      temp = driver_class.new(r.db_config)
      temp.connect
      temp.disconnect
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      times << elapsed
      sleep 0.01  # Give MySQL time to clean up
    end

    avg = times.sum / times.size
    min = times.min
    max = times.max

    puts "    #{name}:"
    puts "      #{iterations} iterations"
    puts "      avg: #{(avg * 1000).round(3)}ms"
    puts "      min: #{(min * 1000).round(3)}ms"
    puts "      max: #{(max * 1000).round(3)}ms"
    puts "      ~#{(1.0 / avg).round(0)} connections/sec"
  end

  # Benchmark: Ping
  r.setup_drivers
  r.benchmark('ping') do |driver|
    driver.ping
  end

  # Benchmark: Connection check
  r.benchmark('connected?') do |driver|
    driver.connected?
  end

  r.teardown_drivers

  # Memory impact of connections
  # Use fewer iterations to avoid exhausting connections
  puts Rainbow("  Memory benchmark: connection_memory").yellow

  r.each_driver_class do |name, driver_class|
    require 'benchmark/memory'

    report = Benchmark.memory do |x|
      x.report("connection (#{name})") do
        10.times do  # Only 10 iterations instead of many
          temp = driver_class.new(r.db_config)
          temp.connect
          temp.disconnect
          sleep 0.01  # Give MySQL time to clean up
        end
      end
    end

    entry = report.entries.first
    total_mb = (entry.measurement.memory.allocated / 1024.0 / 1024.0).round(3)
    per_conn = (entry.measurement.memory.allocated / 10.0 / 1024.0).round(1)

    puts "    #{name}:"
    puts "      Total: #{total_mb} MB (10 connections)"
    puts "      Per connection: #{per_conn} KB"
    puts "      Objects: #{entry.measurement.objects.allocated}"
  end
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('Connection Performance', runner.collector.summary)
