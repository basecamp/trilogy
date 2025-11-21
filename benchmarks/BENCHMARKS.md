# Benchmark Suite Index

Complete listing of all benchmarks in this suite.

## Quick Reference

```bash
# Setup and run everything
./scripts/setup.sh && ./scripts/run_all.sh

# Quick comparison
./example_quick_comparison.rb

# Individual suites
ruby suites/01_basic_operations/connection.rb
ruby suites/03_concurrency/gvl_release.rb
```

## Benchmark Categories

### 1. Basic Operations (4 benchmarks)

Fundamental driver operations - connection, queries, escaping, metadata.

| Benchmark | File | Tests |
|-----------|------|-------|
| Connection | `01_basic_operations/connection.rb` | Connect, disconnect, ping, connection check |
| Simple Queries | `01_basic_operations/simple_queries.rb` | SELECT, INSERT, UPDATE, DELETE |
| String Escaping | `01_basic_operations/escaping.rb` | Various string escaping scenarios |
| Metadata | `01_basic_operations/metadata.rb` | last_insert_id, affected_rows, server_info |

**Key Metrics:** ops/sec, latency, memory per operation

### 2. Data Operations (3 benchmarks)

Bulk data handling and various data types.

| Benchmark | File | Tests |
|-----------|------|-------|
| Bulk Insert | `02_data_operations/bulk_insert.rb` | Individual vs batch inserts (10-10k rows) |
| Bulk Select | `02_data_operations/bulk_select.rb` | Large result sets (10-50k rows) |
| Data Types | `02_data_operations/data_types.rb` | INT, VARCHAR, TEXT, BLOB, JSON, DATETIME |

**Key Metrics:** throughput (rows/sec), memory per row, GC impact

### 3. Concurrency (3 benchmarks)

Parallel execution, GVL behavior, threading vs fibers.

| Benchmark | File | Tests |
|-----------|------|-------|
| Thread Pool | `03_concurrency/thread_pool.rb` | Multi-threaded queries (1-16 threads) |
| Fiber Scheduler | `03_concurrency/fiber_scheduler.rb` | Async/fiber support (requires async gem) |
| GVL Release | `03_concurrency/gvl_release.rb` | GVL release during I/O operations |

**Key Metrics:** parallel efficiency, GVL release %, concurrency overhead

**Important:** Fiber scheduler tests require Ruby 3.0+ and async gem. Only trilogy supports fiber schedulers.

### 4. Memory (3 benchmarks)

Memory efficiency, allocations, GC pressure, leak detection.

| Benchmark | File | Tests |
|-----------|------|-------|
| Allocations | `04_memory/allocations.rb` | Object allocation tracking per operation |
| GC Pressure | `04_memory/gc_pressure.rb` | GC frequency and overhead under load |
| Large Results | `04_memory/large_results.rb` | Memory behavior with large datasets |

**Key Metrics:** bytes allocated, GC runs per 1000 queries, RSS growth

### 5. Advanced (1 benchmark)

Advanced features like transactions, prepared statements.

| Benchmark | File | Tests |
|-----------|------|-------|
| Transactions | `05_advanced/transactions.rb` | BEGIN/COMMIT, rollback, savepoints |

**Key Metrics:** transaction overhead, rollback performance

### 6. Real World (1 benchmark)

Realistic application patterns, especially Rails-style queries.

| Benchmark | File | Tests |
|-----------|------|-------|
| Rails Simulation | `06_real_world/rails_simulation.rb` | Typical ActiveRecord query patterns, N+1 problem |

**Key Metrics:** request lifecycle timing, N+1 vs batch loading

## Total Benchmarks

- **15 benchmark files** across 6 categories
- **100+ individual test cases**
- **Performance, memory, and concurrency** metrics for each
- **Both drivers tested** in parallel for direct comparison

## Benchmark Timing

Approximate time to run all benchmarks:

- Basic Operations: ~2-3 minutes
- Data Operations: ~5-10 minutes (includes seeding large datasets)
- Concurrency: ~5-8 minutes
- Memory: ~8-12 minutes (includes leak detection)
- Advanced: ~1-2 minutes
- Real World: ~2-3 minutes

**Total: ~25-40 minutes** depending on hardware

To run faster, execute individual suites or reduce warmup/time in `config/benchmark_config.yml`.

## Key Comparisons

### Trilogy Expected Advantages

1. **Concurrency**: Better GVL release, fiber scheduler support
2. **Memory**: Lower allocations, less GC pressure
3. **Streaming**: More efficient large result sets

### MySQL2 Expected Advantages

1. **Mature**: Battle-tested, widely used
2. **Prepared Statements**: Native support (trilogy doesn't expose this yet)
3. **Compatibility**: Works with older Ruby versions

### Neutral/Similar

- Basic query performance (SELECT, INSERT, etc.)
- Connection establishment
- String escaping

## Interpreting Results

Look for:

- **2-10x** better concurrency with trilogy (GVL release)
- **20-40%** lower memory allocations with trilogy
- **Similar** single-threaded performance
- **Only trilogy** works with fiber schedulers

See README.md for detailed interpretation guidance.

## Adding Custom Benchmarks

Create new file in appropriate suite directory:

```ruby
require_relative '../../lib/benchmark_runner'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

runner.run_suite('My Custom Test') do |r|
  r.compare_drivers('My benchmark') do |driver|
    # Your test code
  end
end

runner.display_summary
runner.export_results
```

Add to `scripts/run_all.sh` if desired.

## Configuration

- Database: `config/database.yml`
- Benchmark params: `config/benchmark_config.yml`
- Schema: `data/schema.sql`

## Support

See README.md for:
- Setup instructions
- Troubleshooting
- Performance interpretation
- Contributing guidelines
