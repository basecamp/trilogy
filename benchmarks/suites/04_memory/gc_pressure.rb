require_relative '../../lib/benchmark_runner'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

runner.run_suite('Memory - GC Pressure') do |r|
  r.setup_drivers

  # Benchmark: GC invocations during queries
  puts "\n--- GC Invocations ---"
  ITERATIONS = 1000

  r.each_driver do |name, driver|
    puts "  #{name} (#{ITERATIONS} queries):"

    GC.start
    before_stat = GC.stat

    ITERATIONS.times do
      driver.query('SELECT 1')
    end

    after_stat = GC.stat

    puts "    Minor GC runs: #{after_stat[:minor_gc_count] - before_stat[:minor_gc_count]}"
    puts "    Major GC runs: #{after_stat[:major_gc_count] - before_stat[:major_gc_count]}"
    puts "    Total GC runs: #{after_stat[:count] - before_stat[:count]}"
    puts "    Objects allocated: #{after_stat[:total_allocated_objects] - before_stat[:total_allocated_objects]}"
    puts "    Heap pages: #{after_stat[:heap_allocated_pages] - before_stat[:heap_allocated_pages]}"
  end

  # Benchmark: GC during result iteration
  puts "\n--- GC During Result Iteration ---"
  [100, 1000, 10000].each do |limit|
    puts "\n  #{limit} rows:"

    r.each_driver do |name, driver|
      puts "    #{name}:"

      GC.start
      before_stat = GC.stat

      10.times do
        result = driver.query("SELECT * FROM benchmark_data LIMIT #{limit}")
        result.each { |row| row } if result.respond_to?(:each)
      end

      after_stat = GC.stat

      gc_runs = after_stat[:count] - before_stat[:count]
      objects = after_stat[:total_allocated_objects] - before_stat[:total_allocated_objects]

      puts "      GC runs: #{gc_runs}"
      puts "      Objects allocated: #{objects}"
      puts "      Objects per row: #{objects / (limit * 10)}"
    end
  end

  # Benchmark: Sustained load GC behavior
  puts "\n--- Sustained Load GC Behavior ---"
  DURATION = 10  # seconds

  r.each_driver do |name, driver|
    puts "  #{name} (#{DURATION}s sustained load):"

    GC.start
    before_stat = GC.stat
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    queries = 0
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time < DURATION
      driver.query('SELECT 1')
      queries += 1
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    after_stat = GC.stat

    gc_runs = after_stat[:count] - before_stat[:count]
    gc_time = after_stat[:time] - before_stat[:time]  # in microseconds

    puts "    Queries executed: #{queries}"
    puts "    QPS: #{(queries / elapsed).round(2)}"
    puts "    GC runs: #{gc_runs}"
    puts "    GC time: #{(gc_time / 1_000_000.0).round(3)}s"
    puts "    GC overhead: #{((gc_time / 1_000_000.0) / elapsed * 100).round(2)}%"
    puts "    Queries per GC: #{queries / gc_runs}" if gc_runs > 0
  end

  # Benchmark: Memory stability over time
  puts "\n--- Memory Stability ---"

  r.each_driver do |name, driver|
    puts "  #{name}:"

    GC.start
    baseline_rss = `ps -o rss= -p #{Process.pid}`.to_i

    # Run queries and check RSS growth
    snapshots = []
    5.times do |i|
      1000.times do
        result = driver.query('SELECT * FROM benchmark_data LIMIT 100')
        result.each { |row| row } if result.respond_to?(:each)
      end

      GC.start
      current_rss = `ps -o rss= -p #{Process.pid}`.to_i
      snapshots << current_rss

      puts "    After #{(i + 1) * 1000} queries: #{current_rss} KB (Δ #{current_rss - baseline_rss} KB)"
    end

    # Check for memory leak
    growth = snapshots.last - snapshots.first
    puts "    Total RSS growth: #{growth} KB"
    puts "    Per 1000 queries: #{(growth / 5.0).round(2)} KB"
  end

  # Benchmark: GC disabled performance
  puts "\n--- Performance Without GC ---"

  r.each_driver do |name, driver|
    puts "  #{name}:"

    # With GC
    GC.enable
    GC.start

    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    1000.times { driver.query('SELECT 1') }
    with_gc = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

    # Without GC
    GC.disable

    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    1000.times { driver.query('SELECT 1') }
    without_gc = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

    GC.enable

    improvement = ((with_gc - without_gc) / with_gc * 100).round(2)

    puts "    With GC: #{with_gc.round(3)}s"
    puts "    Without GC: #{without_gc.round(3)}s"
    puts "    GC impact: #{improvement}%"
  end

  r.teardown_drivers
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('Memory - GC Pressure', runner.collector.summary)
