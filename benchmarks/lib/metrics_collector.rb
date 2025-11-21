require 'benchmark'
require 'benchmark/ips'
require 'benchmark/memory'

class MetricsCollector
  attr_reader :results

  def initialize
    @results = {}
  end

  # Run performance benchmark using benchmark-ips
  def measure_performance(name, warmup: 2, time: 10, &block)
    result = nil
    Benchmark.ips do |x|
      x.config(warmup: warmup, time: time)
      x.report(name) { block.call }

      # Capture the result
      result = x
    end

    store_result(name, :performance, extract_ips_stats(result))
  end

  # Run memory benchmark using benchmark-memory
  def measure_memory(name, &block)
    result = Benchmark.memory do |x|
      x.report(name) { block.call }
    end

    entry = result.entries.first
    stats = {
      total_allocated: entry.measurement.memory.allocated,
      total_retained: entry.measurement.memory.retained,
      allocated_objects: entry.measurement.objects.allocated,
      retained_objects: entry.measurement.objects.retained,
      allocated_strings: entry.measurement.strings.allocated,
      retained_strings: entry.measurement.strings.retained
    }

    store_result(name, :memory, stats)
  end

  # Detailed memory profiling with MemoryProfiler
  def profile_memory(name, &block)
    require 'memory_profiler'

    report = MemoryProfiler.report do
      block.call
    end

    stats = {
      total_allocated: report.total_allocated_memsize,
      total_retained: report.total_retained_memsize,
      allocated_objects: report.total_allocated,
      retained_objects: report.total_retained,
      strings_allocated: report.strings_allocated,
      strings_retained: report.strings_retained
    }

    store_result(name, :memory_profile, stats)
  end

  # Measure GC stats
  def measure_with_gc_stats(name, &block)
    GC.start
    before_gc = GC.stat

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    block.call
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    after_gc = GC.stat

    stats = {
      elapsed_time: elapsed,
      gc_count: after_gc[:count] - before_gc[:count],
      major_gc_count: after_gc[:major_gc_count] - before_gc[:major_gc_count],
      minor_gc_count: after_gc[:minor_gc_count] - before_gc[:minor_gc_count],
      total_allocated_objects: after_gc[:total_allocated_objects] - before_gc[:total_allocated_objects],
      heap_allocated_pages: after_gc[:heap_allocated_pages] - before_gc[:heap_allocated_pages]
    }

    store_result(name, :gc_stats, stats)
  end

  # Measure with GC disabled (for more accurate timing)
  def measure_without_gc(name, &block)
    GC.start
    GC.disable

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    iterations = 0

    while Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time < 5
      block.call
      iterations += 1
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    GC.enable

    stats = {
      iterations: iterations,
      elapsed_time: elapsed,
      iterations_per_second: iterations / elapsed,
      avg_time_per_iteration: elapsed / iterations
    }

    store_result(name, :no_gc, stats)
  end

  # CPU profiling with stackprof
  def profile_cpu(name, mode: :wall, &block)
    require 'stackprof'

    profile = StackProf.run(mode: mode, raw: true, &block)

    stats = {
      mode: mode,
      samples: profile[:samples],
      gc_samples: profile[:gc_samples],
      missed_samples: profile[:missed_samples]
    }

    store_result(name, :cpu_profile, stats)
  end

  # Measure concurrency metrics
  def measure_concurrent(name, threads: 1, &block)
    require 'concurrent'

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    pool = Concurrent::FixedThreadPool.new(threads)
    futures = threads.times.map do
      Concurrent::Future.execute(executor: pool) do
        block.call
      end
    end

    futures.each(&:wait)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    pool.shutdown
    pool.wait_for_termination

    stats = {
      threads: threads,
      total_time: elapsed,
      avg_time_per_thread: elapsed / threads
    }

    store_result(name, :concurrent, stats)
  end

  # Compare multiple drivers
  def compare(name, drivers: [], warmup: 2, time: 5, &block)
    comparison_results = {}

    Benchmark.ips do |x|
      x.config(warmup: warmup, time: time)

      drivers.each do |driver|
        x.report(driver.name) { block.call(driver) }
      end

      x.compare!
    end

    store_result(name, :comparison, comparison_results)
  end

  # Get summary of all results
  def summary
    @results
  end

  # Export results to file
  def export(filename)
    require 'json'
    File.write(filename, JSON.pretty_generate(@results))
  end

  private

  def store_result(name, type, data)
    @results[name] ||= {}
    @results[name][type] = data
  end

  def extract_ips_stats(result)
    # Extract stats from benchmark-ips result
    # This is a simplified version - actual implementation would parse the result more thoroughly
    {
      type: :ips,
      timestamp: Time.now
    }
  end
end
