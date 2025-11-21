require_relative '../../lib/benchmark_runner'
require 'concurrent'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

THREAD_COUNTS = [1, 2, 4, 8, 16]
QUERIES_PER_THREAD = 100

runner.run_suite('Concurrency - Thread Pool') do |r|
  THREAD_COUNTS.each do |thread_count|
    puts "\n--- Testing with #{thread_count} threads ---"

    # Benchmark: Concurrent simple queries
    r.each_driver_class do |name, driver_class|
      puts "  #{name}:"

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      threads = thread_count.times.map do
        Thread.new do
          # Each thread gets its own connection
          conn = driver_class.new(r.db_config)
          conn.connect

          QUERIES_PER_THREAD.times do
            conn.query('SELECT 1')
          end

          conn.disconnect
        end
      end

      threads.each(&:join)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      total_queries = thread_count * QUERIES_PER_THREAD
      qps = total_queries / elapsed

      puts "    Total time: #{elapsed.round(3)}s"
      puts "    Total queries: #{total_queries}"
      puts "    Queries/sec: #{qps.round(2)}"
    end

    # Benchmark: Concurrent INSERT operations
    r.each_driver_class do |name, driver_class|
      puts "  #{name} (concurrent INSERTs):"

      # Clear table first
      temp = driver_class.new(r.db_config)
      temp.connect
      temp.query('TRUNCATE TABLE benchmark_data')
      temp.disconnect

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      threads = thread_count.times.map do |thread_id|
        Thread.new do
          conn = driver_class.new(r.db_config)
          conn.connect

          QUERIES_PER_THREAD.times do |i|
            conn.query("INSERT INTO benchmark_data (data, created_at) VALUES ('thread_#{thread_id}_row_#{i}', NOW())")
          end

          conn.disconnect
        end
      end

      threads.each(&:join)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      total_inserts = thread_count * QUERIES_PER_THREAD
      ips = total_inserts / elapsed

      puts "    Total time: #{elapsed.round(3)}s"
      puts "    Total inserts: #{total_inserts}"
      puts "    Inserts/sec: #{ips.round(2)}"
    end
  end

  # Test connection pool with concurrent-ruby
  puts "\n--- Connection Pool Benchmark ---"
  POOL_SIZE = 10

  r.each_driver_class do |name, driver_class|
    puts "  #{name} (pool size: #{POOL_SIZE}):"

    # Create connection pool
    pool = Queue.new
    POOL_SIZE.times do
      conn = driver_class.new(r.db_config)
      conn.connect
      pool << conn
    end

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # 50 threads sharing 10 connections
    threads = 50.times.map do
      Thread.new do
        10.times do
          # Get a connection from pool (exclusive access)
          conn = pool.pop
          begin
            conn.query('SELECT 1')
          ensure
            pool << conn
          end
        end
      end
    end

    threads.each(&:join)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    puts "    50 threads sharing #{POOL_SIZE} connections"
    puts "    Total time: #{elapsed.round(3)}s"
    puts "    Queries/sec: #{(500 / elapsed).round(2)}"

    # Cleanup pool
    # Cleanup pool
    until pool.empty?
      conn = pool.pop
      conn.disconnect
    end
  end
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('Concurrency - Thread Pool', runner.collector.summary)
