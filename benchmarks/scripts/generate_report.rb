#!/usr/bin/env ruby

# Generate HTML report from benchmark results

require 'json'
require 'erb'
require 'terminal-table'

REPORTS_DIR = File.expand_path('../reports', __dir__)

# Find all result files
result_files = Dir[File.join(REPORTS_DIR, 'benchmark_results_*.json')]

if result_files.empty?
  puts "No benchmark results found in #{REPORTS_DIR}"
  exit 1
end

# Load most recent results
latest_results = result_files.sort.last
puts "Loading results from: #{latest_results}"

data = JSON.parse(File.read(latest_results))

# Generate terminal summary
puts "\n=== Benchmark Summary ==="
puts "Generated: #{Time.now}"
puts ""

data.each do |benchmark_name, metrics|
  puts "\n#{benchmark_name}"
  puts "─" * 80

  metrics.each do |metric_type, metric_data|
    case metric_type
    when 'performance'
      puts "  Performance: #{metric_data.inspect}"
    when 'memory'
      if metric_data['total_allocated']
        allocated_mb = (metric_data['total_allocated'].to_f / 1024 / 1024).round(2)
        puts "  Memory: #{allocated_mb} MB allocated, #{metric_data['allocated_objects']} objects"
      end
    when 'gc_stats'
      if metric_data['gc_count']
        puts "  GC: #{metric_data['gc_count']} runs, #{(metric_data['elapsed_time'] * 1000).round(2)}ms total"
      end
    when 'concurrent'
      if metric_data['threads']
        puts "  Concurrency: #{metric_data['threads']} threads, #{metric_data['total_time'].round(3)}s"
      end
    end
  end
end

# Generate Markdown report
markdown = <<~MD
# Trilogy Benchmark Results

**Generated:** #{Time.now}

## Summary

This report contains benchmark results comparing trilogy and mysql2 MySQL drivers.

## Benchmarks Run

#{data.keys.map { |k| "- #{k}" }.join("\n")}

## Detailed Results

MD

data.each do |benchmark_name, metrics|
  markdown << "\n### #{benchmark_name}\n\n"

  metrics.each do |metric_type, metric_data|
    markdown << "**#{metric_type.capitalize}:**\n"
    markdown << "```\n"
    markdown << JSON.pretty_generate(metric_data)
    markdown << "\n```\n\n"
  end
end

markdown << <<~MD

## Environment

- Ruby: #{RUBY_VERSION}
- Platform: #{RUBY_PLATFORM}

## Notes

- Lower memory allocations are better
- Higher iterations/sec are better
- Lower GC pressure is better
- Better GVL release allows higher concurrency

MD

# Write markdown report
report_path = File.join(REPORTS_DIR, "summary_#{Time.now.to_i}.md")
File.write(report_path, markdown)

puts "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
puts "✓ Report generated: #{report_path}"
puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
