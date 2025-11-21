require_relative '../../lib/benchmark_runner'

# Only run if async gem is available
begin
  require 'async'
  require 'async/io'
rescue LoadError
  puts "Async gem not available, skipping fiber scheduler benchmarks"
  exit
end

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

FIBER_COUNTS = [1, 10, 100, 1000]
QUERIES_PER_FIBER = 10

runner.run_suite('Concurrency - Fiber Scheduler') do |r|
  FIBER_COUNTS.each do |fiber_count|
    puts "\n--- Testing with #{fiber_count} fibers ---"

    r.each_driver_class do |name, driver_class|
      puts "  #{name}:"

      if name == 'mysql2'
        puts "    SKIPPED (mysql2 doesn't support fiber schedulers)"
        next
      end

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      Async do
        # Create tasks (async blocks run as fibers)
        tasks = fiber_count.times.map do
          Async do
            conn = driver_class.new(r.db_config)
            conn.connect

            QUERIES_PER_FIBER.times do
              conn.query('SELECT 1')
            end

            conn.disconnect
          end
        end

        # Wait for all tasks to complete
        tasks.each(&:wait)
      end

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      total_queries = fiber_count * QUERIES_PER_FIBER
      qps = total_queries / elapsed

      puts "    Total time: #{elapsed.round(3)}s"
      puts "    Total queries: #{total_queries}"
      puts "    Queries/sec: #{qps.round(2)}"
      puts "    Concurrency benefit: #{(fiber_count.to_f / elapsed).round(2)}x"
    end

    # Benchmark: Concurrent I/O-bound operations
    r.each_driver_class do |name, driver_class|
      next if name == 'mysql2'

      puts "  #{name} (with SLEEP):"

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      Async do
        tasks = fiber_count.times.map do
          Async do
            conn = driver_class.new(r.db_config)
            conn.connect

            # Simulate I/O-bound work with SLEEP
            conn.query('SELECT SLEEP(0.01)')

            conn.disconnect
          end
        end

        tasks.each(&:wait)
      end

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      puts "    Total time: #{elapsed.round(3)}s"
      puts "    Expected serial time: #{(fiber_count * 0.01).round(3)}s"
      puts "    Speedup: #{((fiber_count * 0.01) / elapsed).round(2)}x"
    end
  end

  # Compare fiber scheduler vs threads
  puts "\n--- Fiber vs Thread Comparison ---"
  CONCURRENT_OPS = 100

  r.each_driver_class do |name, driver_class|
    next if name == 'mysql2'

    puts "  #{name}:"

    # Threads
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    threads = CONCURRENT_OPS.times.map do
      Thread.new do
        conn = driver_class.new(r.db_config)
        conn.connect
        conn.query('SELECT 1')
        conn.disconnect
      end
    end
    threads.each(&:join)

    thread_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    # Fibers
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    Async do
      tasks = CONCURRENT_OPS.times.map do
        Async do
          conn = driver_class.new(r.db_config)
          conn.connect
          conn.query('SELECT 1')
          conn.disconnect
        end
      end
      tasks.each(&:wait)
    end

    fiber_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    puts "    Threads: #{thread_time.round(3)}s"
    puts "    Fibers: #{fiber_time.round(3)}s"
    puts "    Fiber advantage: #{(thread_time / fiber_time).round(2)}x faster"
  end
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('Concurrency - Fiber Scheduler', runner.collector.summary)
