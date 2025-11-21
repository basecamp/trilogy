require_relative '../../lib/benchmark_runner'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

runner.run_suite('Concurrency - GVL Release') do |r|
  # This benchmark measures how well drivers release the GVL during I/O operations
  # We do this by running a CPU-bound task in parallel with database I/O

  puts "\n--- GVL Release Test ---"
  puts "Running CPU work in parallel with DB queries to measure GVL release"

  QUERY_COUNT = 100
  CPU_ITERATIONS = 1_000_000

  r.each_driver_class do |name, driver_class|
    puts "\n  #{name}:"

    # Test 1: Serial execution (baseline)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    conn = driver_class.new(r.db_config)
    conn.connect

    QUERY_COUNT.times do
      conn.query('SELECT SLEEP(0.001)')  # 1ms sleep
    end

    conn.disconnect

    # CPU work
    sum = 0
    CPU_ITERATIONS.times { |i| sum += i }

    serial_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    puts "    Serial (DB then CPU): #{serial_time.round(3)}s"

    # Test 2: Parallel execution (tests GVL release)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    db_thread = Thread.new do
      conn = driver_class.new(r.db_config)
      conn.connect

      QUERY_COUNT.times do
        conn.query('SELECT SLEEP(0.001)')
      end

      conn.disconnect
    end

    cpu_thread = Thread.new do
      sum = 0
      CPU_ITERATIONS.times { |i| sum += i }
    end

    db_thread.join
    cpu_thread.join

    parallel_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    puts "    Parallel (DB + CPU): #{parallel_time.round(3)}s"

    speedup = serial_time / parallel_time
    gvl_release_efficiency = ((speedup - 1.0) / 1.0 * 100).round(2)

    puts "    Speedup: #{speedup.round(2)}x"
    puts "    GVL release efficiency: #{gvl_release_efficiency}%"
    puts "    (Higher % = better GVL release during I/O)"
  end

  # Test 3: Multiple threads doing I/O
  puts "\n--- Multiple Concurrent I/O Operations ---"

  THREAD_COUNTS = [2, 4, 8]

  THREAD_COUNTS.each do |thread_count|
    puts "\n  #{thread_count} threads:"

    r.each_driver_class do |name, driver_class|
      # Serial baseline
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      thread_count.times do
        conn = driver_class.new(r.db_config)
        conn.connect
        10.times { conn.query('SELECT SLEEP(0.01)') }  # 10ms sleep
        conn.disconnect
      end

      serial = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

      # Parallel execution
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      threads = thread_count.times.map do
        Thread.new do
          conn = driver_class.new(r.db_config)
          conn.connect
          10.times { conn.query('SELECT SLEEP(0.01)') }
          conn.disconnect
        end
      end

      threads.each(&:join)
      parallel = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

      speedup = serial / parallel
      efficiency = (speedup / thread_count * 100).round(2)

      puts "    #{name}:"
      puts "      Serial: #{serial.round(3)}s"
      puts "      Parallel: #{parallel.round(3)}s"
      puts "      Speedup: #{speedup.round(2)}x"
      puts "      Parallel efficiency: #{efficiency}%"
    end
  end

  # Test 4: GVL hold time measurement
  puts "\n--- Estimated GVL Hold Time ---"

  r.each_driver_class do |name, driver_class|
    conn = driver_class.new(r.db_config)
    conn.connect

    # Measure time for query that returns immediately
    times = []
    100.times do
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
      conn.query('SELECT 1')
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - start
      times << elapsed
    end

    conn.disconnect

    avg = times.sum / times.size
    min = times.min
    max = times.max

    puts "  #{name}:"
    puts "    Avg query time: #{(avg / 1_000_000.0).round(3)}ms"
    puts "    Min: #{(min / 1_000_000.0).round(3)}ms"
    puts "    Max: #{(max / 1_000_000.0).round(3)}ms"
    puts "    (Lower is better - less GVL hold time)"
  end
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('Concurrency - GVL Release', runner.collector.summary)
