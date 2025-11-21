require 'bundler/setup'

require 'yaml'
require 'terminal-table'
require 'rainbow'
require_relative 'metrics_collector'
require_relative 'drivers/base_driver'
require_relative 'drivers/trilogy_driver'
require_relative 'drivers/mysql2_driver'

class BenchmarkRunner
  attr_reader :config, :db_config, :drivers, :collector

  def initialize(config_path: nil, db_config_path: nil)
    # Find the benchmarks root directory (one level up from lib/)
    benchmark_root = File.expand_path('..', __dir__)

    config_path ||= File.join(benchmark_root, 'config/benchmark_config.yml')
    db_config_path ||= File.join(benchmark_root, 'config/database.yml')

    @config = YAML.load_file(config_path, aliases: true)
    db_config_raw = YAML.load_file(db_config_path, aliases: true)['development']

    # Add unique suffix to database name for concurrent execution
    @db_suffix = ENV['BENCHMARK_DB_SUFFIX'] || Process.pid.to_s

    # Convert string keys to symbols for driver compatibility
    @db_config = db_config_raw.transform_keys(&:to_sym)

    # Append unique suffix to database name
    if @db_config[:database]
      @db_config[:database] = "#{@db_config[:database]}_#{@db_suffix}"
    end

    @drivers = {}
    @collector = MetricsCollector.new
    @results = {}
    @database_created = false
  end

  # Register drivers to benchmark
  def register_driver(name, driver_class)
    @drivers[name] = driver_class
  end

  # Initialize all drivers
  def setup_drivers
    @driver_instances = {}
    @drivers.each do |name, driver_class|
      @driver_instances[name] = driver_class.new(@db_config)
      @driver_instances[name].connect
    end
  end

  # Clean up all drivers
  def teardown_drivers
    @driver_instances&.each_value(&:disconnect)
  end

  # Ensure database exists
  def ensure_database
    return if @database_created

    # Create database if it doesn't exist
    base_config = @db_config.dup
    base_config.delete(:database)

    # Use trilogy to create the database
    require 'trilogy'
    conn = Trilogy.new(base_config)

    begin
      conn.query("CREATE DATABASE IF NOT EXISTS `#{@db_config[:database]}`")
      conn.query("USE `#{@db_config[:database]}`")

      # Create benchmark tables
      conn.query(<<~SQL)
        CREATE TABLE IF NOT EXISTS benchmark_data (
          id INT PRIMARY KEY AUTO_INCREMENT,
          data VARCHAR(255),
          created_at DATETIME,
          INDEX idx_created_at (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
      SQL

      # Seed initial data (batch insert for speed)
      values = 100.times.map { |i| "('seed_row_#{i}', NOW())" }.join(', ')
      conn.query("INSERT INTO benchmark_data (data, created_at) VALUES #{values}")

      @database_created = true
      puts Rainbow("  ✓ Database '#{@db_config[:database]}' ready").green if ENV['DEBUG']
    rescue => e
      puts Rainbow("  ⚠ Database setup warning: #{e.message}").yellow
    ensure
      conn&.close
    end
  end

  # Clean up database
  def cleanup_database
    return unless @database_created

    base_config = @db_config.dup
    base_config.delete(:database)

    require 'trilogy'
    conn = Trilogy.new(base_config)

    begin
      conn.query("DROP DATABASE IF EXISTS `#{@db_config[:database]}`")
      puts Rainbow("  ✓ Database '#{@db_config[:database]}' cleaned up").green if ENV['DEBUG']
    rescue => e
      puts Rainbow("  ⚠ Database cleanup warning: #{e.message}").yellow
    ensure
      conn&.close
    end
  end

  # Run a benchmark suite
  def run_suite(suite_name, &block)
    puts Rainbow("\n=== Running #{suite_name} ===").bright.cyan
    ensure_database
    setup_drivers

    begin
      block.call(self)
    ensure
      teardown_drivers
      cleanup_database if ENV['BENCHMARK_CLEANUP'] != 'false'
    end
  end

  # Run a single benchmark across all drivers
  def benchmark(name, &block)
    puts Rainbow("  Benchmarking: #{name}").yellow

    # Auto-setup drivers if not already done
    setup_drivers unless @driver_instances && !@driver_instances.empty?

    @driver_instances.each do |driver_name, driver|
      benchmark_name = "#{name} (#{driver_name})"

      begin
        collector.measure_performance(benchmark_name,
                                     warmup: config['warmup'],
                                     time: config['time']) do
          block.call(driver)
        end
      rescue => e
        puts Rainbow("    ERROR in #{driver_name}: #{e.message}").red
        puts Rainbow("      #{e.class}").red
        puts Rainbow("      #{e.backtrace.first(3).join("\n      ")}").red if ENV['DEBUG']
      end
    end
  end

  # Memory benchmark across all drivers
  def benchmark_memory(name, &block)
    puts Rainbow("  Memory benchmark: #{name}").yellow

    # Auto-setup drivers if not already done
    setup_drivers unless @driver_instances && !@driver_instances.empty?

    @driver_instances.each do |driver_name, driver|
      benchmark_name = "#{name} (#{driver_name})"

      begin
        collector.measure_memory(benchmark_name) do
          block.call(driver)
        end
      rescue => e
        puts Rainbow("    ERROR in #{driver_name}: #{e.message}").red
      end
    end
  end

  # Concurrency benchmark
  def benchmark_concurrent(name, threads:, &block)
    puts Rainbow("  Concurrent benchmark: #{name} (#{threads} threads)").yellow

    @driver_instances.each do |driver_name, driver|
      benchmark_name = "#{name} (#{driver_name}, #{threads} threads)"

      begin
        # Each thread gets its own connection
        collector.measure_concurrent(benchmark_name, threads: threads) do
          temp_driver = @drivers[driver_name].new(@db_config)
          temp_driver.connect
          block.call(temp_driver)
          temp_driver.disconnect
        end
      rescue => e
        puts Rainbow("    ERROR in #{driver_name}: #{e.message}").red
      end
    end
  end

  # GC impact benchmark
  def benchmark_gc_impact(name, &block)
    puts Rainbow("  GC impact benchmark: #{name}").yellow

    @driver_instances.each do |driver_name, driver|
      benchmark_name = "#{name} (#{driver_name})"

      begin
        collector.measure_with_gc_stats(benchmark_name) do
          1000.times { block.call(driver) }
        end
      rescue => e
        puts Rainbow("    ERROR in #{driver_name}: #{e.message}").red
      end
    end
  end

  # Compare drivers side-by-side
  def compare_drivers(name, &block)
    puts Rainbow("  Comparing drivers: #{name}").green

    require 'benchmark/ips'

    Benchmark.ips do |x|
      x.config(warmup: config['warmup'], time: config['time'])

      @driver_instances.each do |driver_name, driver|
        x.report(driver_name) { block.call(driver) }
      end

      x.compare!
    end
  end

  # Display results summary
  def display_summary(style: :compact)
    if style == :polished
      # Load and run the polished summary generator
      summary_path = File.expand_path('../scripts/generate_summary.rb', __dir__)
      load summary_path if File.exist?(summary_path)
    else
      # Original compact summary
      puts Rainbow("\n=== Benchmark Results Summary ===").bright.green
      results = collector.summary

      if results.empty?
        puts "No results collected"
        return
      end

      # Group results by benchmark name
      results.each do |benchmark_name, metrics|
        puts Rainbow("\n#{benchmark_name}").cyan
        metrics.each do |metric_type, data|
          puts "  #{metric_type}: #{data.inspect}"
        end
      end
    end
  end

  # Export results
  def export_results(filename = "reports/benchmark_results_#{Time.now.to_i}.json")
    collector.export(filename)
    puts Rainbow("\nResults exported to #{filename}").green
  end

  # Helper to get driver instances
  def driver(name)
    @driver_instances[name]
  end

  def each_driver(&block)
    @driver_instances.each(&block)
  end

  def each_driver_class(&block)
    @drivers.each(&block)
  end
end
