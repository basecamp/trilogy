#!/bin/bash

# Run all benchmark suites

set -e

cd "$(dirname "$0")/.."

echo "=== Running All Trilogy Benchmarks ==="
echo ""

# Create reports directory if it doesn't exist
mkdir -p reports

# Record start time
START_TIME=$(date +%s)

# Basic Operations
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. BASIC OPERATIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ruby suites/01_basic_operations/connection.rb
ruby suites/01_basic_operations/simple_queries.rb
ruby suites/01_basic_operations/escaping.rb
ruby suites/01_basic_operations/metadata.rb

# Data Operations
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. DATA OPERATIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ruby suites/02_data_operations/bulk_insert.rb
ruby suites/02_data_operations/bulk_select.rb
ruby suites/02_data_operations/data_types.rb

# Concurrency
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. CONCURRENCY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ruby suites/03_concurrency/thread_pool.rb
ruby suites/03_concurrency/fiber_scheduler.rb || echo "Fiber scheduler benchmarks skipped (async gem not available)"
ruby suites/03_concurrency/gvl_release.rb

# Memory
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. MEMORY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ruby suites/04_memory/allocations.rb
ruby suites/04_memory/gc_pressure.rb
ruby suites/04_memory/large_results.rb

# Advanced
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. ADVANCED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ruby suites/05_advanced/transactions.rb

# Real World
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. REAL WORLD SCENARIOS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ruby suites/06_real_world/rails_simulation.rb

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ All benchmarks complete!"
echo "  Duration: ${MINUTES}m ${SECONDS}s"
echo "  Reports saved to: reports/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Generate polished summary
echo "Generating comprehensive analysis..."
ruby scripts/generate_summary.rb
