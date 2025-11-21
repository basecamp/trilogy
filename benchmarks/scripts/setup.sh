#!/bin/bash

# Setup script for trilogy benchmarks

set -e

echo "=== Trilogy Benchmark Setup ==="

# Check if MySQL is running
if ! command -v mysql &> /dev/null; then
    echo "Error: MySQL client not found. Please install MySQL."
    exit 1
fi

# Test MySQL connection
if ! mysql -h 127.0.0.1 -u root -e "SELECT 1" &> /dev/null; then
    echo "Error: Cannot connect to MySQL. Please ensure MySQL is running and accessible."
    exit 1
fi

echo "✓ MySQL connection OK"

# Create database and schema
echo "Creating benchmark database..."
mysql -h 127.0.0.1 -u root < data/schema.sql

echo "✓ Base database created and seeded"
echo ""
echo "Note: Individual benchmark runs create isolated databases (trilogy_benchmark_PID)"
echo "      to allow concurrent execution without conflicts."

# Install Ruby gems
echo "Installing Ruby dependencies..."
cd "$(dirname "$0")/.."
bundle install

echo "✓ Dependencies installed"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "You can now run benchmarks:"
echo "  ./scripts/run_all.sh           # Run all benchmarks"
echo "  ruby suites/01_basic_operations/connection.rb"
echo "  ruby suites/03_concurrency/gvl_release.rb"
echo ""
