#!/usr/bin/env ruby

# Quick comparison example - demonstrates basic usage

require_relative 'lib/benchmark_runner'
require 'rainbow'

puts Rainbow("=== Quick Trilogy vs MySQL2 Comparison ===").bright.cyan
puts ""

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

runner.run_suite('Quick Comparison') do |r|
  puts Rainbow("Testing basic operations...").yellow
  puts ""

  # Simple query comparison
  r.compare_drivers('Simple query (SELECT 1)') do |driver|
    driver.query('SELECT 1')
  end

  puts ""

  # Query with results
  r.compare_drivers('Query with results (100 rows)') do |driver|
    result = driver.query('SELECT * FROM benchmark_data LIMIT 100')
    count = 0
    result.each { |row| count += 1 } if result.respond_to?(:each)
  end

  puts ""

  # String escaping
  r.compare_drivers('String escaping') do |driver|
    driver.escape("O'Reilly")
  end

  puts ""

  # Insert operation
  r.compare_drivers('INSERT query') do |driver|
    driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('benchmark', NOW())")
  end

  puts ""
  puts Rainbow("=== Memory Comparison ===").bright.cyan
  puts ""

  # Memory comparison
  r.benchmark_memory('SELECT query memory (100 iterations)') do |driver|
    100.times { driver.query('SELECT 1') }
  end

  puts ""

  # Display summary
  puts Rainbow("=== Summary ===").bright.green
  puts ""
  puts "✓ Trilogy generally shows:"
  puts "  - Similar or better query performance"
  puts "  - Lower memory allocations"
  puts "  - Better GVL release for concurrency"
  puts "  - Fiber scheduler support (async gem)"
  puts ""
  puts "✓ Run './scripts/run_all.sh' for comprehensive benchmarks"
  puts ""
end
