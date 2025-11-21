require_relative '../../lib/benchmark_runner'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

TEST_STRINGS = [
  "simple string",
  "string with 'quotes'",
  "string with \"double quotes\"",
  "string with 'mixed' \"quotes\"",
  "string\nwith\nnewlines",
  "string\twith\ttabs",
  "string with \\ backslash",
  "string with NULL\0character",
  "string with unicode: 你好世界 🚀",
  "O'Reilly",
  "It's a test",
  "DROP TABLE users; --",
  "'; DROP TABLE users; --",
  "1' OR '1'='1",
  "<script>alert('xss')</script>"
]

runner.run_suite('Basic Operations - String Escaping') do |r|
  # Benchmark escaping short strings
  r.compare_drivers('escape simple string') do |driver|
    driver.escape('simple string')
  end

  # Benchmark escaping strings with quotes
  r.compare_drivers('escape with quotes') do |driver|
    driver.escape("string with 'quotes'")
  end

  # Benchmark escaping strings with special characters
  r.compare_drivers('escape special chars') do |driver|
    driver.escape("string\nwith\nnewlines\tand\ttabs")
  end

  # Benchmark escaping unicode
  r.compare_drivers('escape unicode') do |driver|
    driver.escape("string with unicode: 你好世界 🚀")
  end

  # Benchmark escaping potential SQL injection
  r.compare_drivers('escape SQL injection') do |driver|
    driver.escape("'; DROP TABLE users; --")
  end

  # Benchmark escaping all test strings
  r.compare_drivers('escape mixed strings') do |driver|
    TEST_STRINGS.each { |s| driver.escape(s) }
  end

  # Memory impact of escaping
  r.benchmark_memory('escaping memory') do |driver|
    1000.times do
      TEST_STRINGS.each { |s| driver.escape(s) }
    end
  end

  # GC impact
  r.benchmark_gc_impact('escaping GC impact') do |driver|
    TEST_STRINGS.each { |s| driver.escape(s) }
  end
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('String Escaping', runner.collector.summary)
