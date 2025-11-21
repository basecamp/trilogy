# Trilogy MySQL Driver Benchmarks

Comprehensive benchmark suite for comparing trilogy with mysql2 and other MySQL drivers, focusing on low-level performance metrics and concurrency behavior.

## Overview

This benchmark suite provides rigorous, reproducible comparisons across multiple dimensions:

- **Low-level Performance**: Query timing, throughput, latency percentiles
- **Memory Efficiency**: Allocations, GC pressure, memory stability
- **Concurrency**: GVL release, threading, fiber support
- **Real-world Scenarios**: Typical application patterns and edge cases

## Quick Start

### Prerequisites

- Ruby 2.7+ (Ruby 3.0+ recommended for fiber scheduler support)
- MySQL 5.7+ or MariaDB 10.3+
- Bundler

### Setup

```bash
# Install dependencies and create database
./scripts/setup.sh

# Run all benchmarks (includes polished summary at end)
./scripts/run_all.sh

# Or run individual suites
ruby suites/01_basic_operations/connection.rb
ruby suites/03_concurrency/gvl_release.rb

# Generate polished summary anytime
./summary
# or
ruby scripts/generate_summary.rb
```

### Benchmark Output

**Every benchmark suite** now includes a **polished, domain-specific summary** at the end:

```bash
# Each individual suite shows targeted analysis
ruby suites/01_basic_operations/simple_queries.rb
# ↳ Shows: Query Performance summary with ops/sec comparisons

ruby suites/03_concurrency/gvl_release.rb
# ↳ Shows: Concurrency & GVL analysis with efficiency metrics

ruby suites/04_memory/allocations.rb
# ↳ Shows: Memory & Allocation breakdown with impact analysis
```

**Suite summaries include:**
- **Comparison Table** - Side-by-side metrics with clear winners
- **Key Insights** - Domain-specific analysis (e.g., "5x faster result iteration")
- **Impact Analysis** - What the numbers mean for your application
- **Visual Indicators** - 🥇 medals, color-coded winners, percentage differences

**Full benchmark suite summary:**

After running `./scripts/run_all.sh`, you also get a **comprehensive executive summary**:

- **Executive Summary** - Overall scores and key metrics comparison
- **Domain Rankings** - Performance breakdown by category (speed, memory, concurrency, etc.)
- **Outlier Highlights** - Significant performance differences highlighted
- **Recommendations** - Use-case specific guidance on which driver to choose

The polished reports use beautiful text UI with Unicode tables, rankings, and visual indicators to make results immediately actionable.

## Benchmark Suites

### 1. Basic Operations

Tests fundamental driver operations:

- **Connection** (`connection.rb`): Connect/disconnect, ping, connection checks
- **Simple Queries** (`simple_queries.rb`): SELECT, INSERT, UPDATE, DELETE
- **Escaping** (`escaping.rb`): String escaping performance and correctness
- **Metadata** (`metadata.rb`): last_insert_id, affected_rows, server_info

**Key Metrics:**
- Iterations per second (ops/sec)
- Latency (ms)
- Memory allocations per operation

### 2. Data Operations

Tests data handling efficiency:

- **Bulk Insert** (`bulk_insert.rb`): Single vs batch inserts at various scales (10-10k rows)
- **Bulk Select** (`bulk_select.rb`): Large result set retrieval and iteration
- **Data Types** (`data_types.rb`): INT, VARCHAR, TEXT, BLOB, JSON, DATETIME performance

**Key Metrics:**
- Throughput (rows/sec)
- Memory per row
- GC impact

### 3. Concurrency

Tests parallel execution and GVL behavior:

- **Thread Pool** (`thread_pool.rb`): Multi-threaded queries (1-16 threads)
- **Fiber Scheduler** (`fiber_scheduler.rb`): Async/fiber support with the async gem
- **GVL Release** (`gvl_release.rb`): Measures GVL release during I/O operations

**Key Metrics:**
- Parallel efficiency (speedup vs thread count)
- GVL release percentage
- Concurrency overhead

**Important:** The fiber scheduler benchmark requires the `async` gem and only works with drivers that support Ruby's fiber scheduler (trilogy does, mysql2 doesn't).

### 4. Memory

Tests memory efficiency and stability:

- **Allocations** (`allocations.rb`): Object allocation tracking per operation
- **GC Pressure** (`gc_pressure.rb`): GC frequency and overhead under load
- **Large Results** (`large_results.rb`): Memory behavior with large datasets, leak detection

**Key Metrics:**
- Bytes allocated per operation
- GC runs per 1000 queries
- Memory stability (RSS growth)

## Understanding Results

### Performance Metrics

**Iterations per Second (IPS)**
- Higher is better
- Typical ranges:
  - Simple queries: 10k-50k ops/sec
  - Complex queries: 100-10k ops/sec

**Latency**
- Lower is better
- Typical ranges:
  - Simple query: 0.02-0.1ms
  - Large result set: 1-100ms

### Memory Metrics

**Allocations**
- Lower is better
- Typical ranges:
  - Simple query: 1-10 KB
  - 100 row result: 10-100 KB

**GC Pressure**
- Lower GC frequency is better
- Target: <1 GC per 1000 queries

### Concurrency Metrics

**GVL Release Efficiency**
- Percentage of time GVL is released during I/O
- Higher is better (>80% is excellent)
- Allows other Ruby threads to run during database I/O

**Parallel Speedup**
- Ideal: N threads = Nx speedup
- Reality: Depends on GVL release
- Good: >50% efficiency with 4+ threads

## Architecture

### Driver Abstraction Layer

The `BaseDriver` class provides a common interface ensuring fair comparison:

```ruby
# All drivers implement the same interface
driver.connect
driver.query(sql)
driver.escape(string)
driver.last_insert_id
driver.disconnect
```

Adapters for each driver (`TrilogyDriver`, `Mysql2Driver`) normalize behavior differences.

### Metrics Collection

The `MetricsCollector` class uses:
- `benchmark-ips` for iterations/sec
- `benchmark-memory` for allocation tracking
- `memory_profiler` for detailed memory analysis
- `stackprof` for CPU profiling
- Custom GC.stat tracking

### Fair Comparison

To ensure fairness:
1. Warm-up phase before measurements
2. Same query patterns across drivers
3. GC disabled during critical timing
4. Multiple runs with statistical analysis
5. Isolated connection pools per driver

## Adding New Drivers

To benchmark a new driver:

1. Create adapter in `lib/drivers/`:

```ruby
class NewDriver < BaseDriver
  def connect
    @connection = NewGem.new(@config)
  end

  def query(sql)
    @connection.execute(sql)
  end
  # ... implement other methods
end
```

2. Register in benchmark files:

```ruby
runner.register_driver('new_driver', NewDriver)
```

## Configuration

### Database Config

Edit `config/database.yml`:

```yaml
default:
  host: 127.0.0.1
  port: 3306
  username: root
  password:
  database: trilogy_benchmark
```

### Benchmark Parameters

Edit `config/benchmark_config.yml`:

```yaml
warmup: 2              # seconds
time: 10               # seconds per benchmark
iterations: 5          # repeat count

data_sizes:
  small: 100
  medium: 1000
  large: 10000
```

## Interpreting Specific Results

### Trilogy vs MySQL2: Expected Differences

**Performance:**
- Trilogy typically shows similar or slightly better query performance
- Lower memory allocations per query
- Better streaming behavior for large results

**Concurrency:**
- Trilogy: Excellent GVL release, fiber scheduler support
- MySQL2: Limited GVL release, no fiber support
- Trilogy can show 2-10x better concurrency in Ruby applications

**Memory:**
- Trilogy: Lower allocations, less GC pressure
- Uses buffer pool to reduce allocations
- More stable memory with large result sets

### When Results Matter

**Low concurrency** (1-2 threads): Differences may be small
**High concurrency** (4+ threads): Trilogy's GVL release shines
**Fiber-based apps**: Only trilogy supports fiber schedulers
**Large results**: Trilogy typically more memory efficient

## CI Integration

To track performance over time:

```bash
# Run benchmarks and save results
./scripts/run_all.sh > results.txt
./scripts/generate_report.rb

# Compare with previous runs
# (add historical tracking as needed)
```

## Troubleshooting

**"Cannot connect to MySQL"**
- Ensure MySQL is running: `mysql.server start`
- Check credentials in `config/database.yml`

**"Gem not found"**
- Run `bundle install` in benchmarks directory

**Fiber scheduler tests fail**
- Install async gem: `gem install async`
- Requires Ruby 3.0+

**Inconsistent results**
- Close other applications
- Disable CPU throttling
- Run multiple times and average

## Performance Tips

For production applications based on these benchmarks:

1. **Use connection pooling** (5-10 connections per process)
2. **Enable prepared statements** when supported
3. **Batch operations** where possible
4. **Monitor GC overhead** in production
5. **Use fibers** with trilogy for high-concurrency apps

## Contributing

To add new benchmarks:

1. Create file in appropriate suite directory
2. Follow existing patterns (use BenchmarkRunner)
3. Document what's being tested
4. Include both performance and memory tests
5. Add to `run_all.sh`

## License

Same as trilogy (MIT)

## Further Reading

- [Trilogy GitHub](https://github.com/trilogy-libraries/trilogy)
- [MySQL2 GitHub](https://github.com/brianmario/mysql2)
- [Ruby GVL and Concurrency](https://www.speedshop.co/2020/05/11/the-ruby-gvl-and-scaling.html)
- [Ruby Fiber Scheduler](https://brunosutic.com/blog/ruby-fiber-scheduler)
