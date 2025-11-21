require_relative '../../lib/benchmark_runner'

runner = BenchmarkRunner.new
runner.register_driver('trilogy', TrilogyDriver)
runner.register_driver('mysql2', Mysql2Driver)

runner.run_suite('Real World - Rails Simulation') do |r|
  r.setup_drivers

  # Seed some test data
  r.each_driver do |name, driver|
    driver.query('TRUNCATE TABLE benchmark_data')
    100.times do |i|
      driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('user_#{i}', NOW())")
    end
  end

  # Simulate typical Rails queries
  puts "\n--- Typical Rails Query Patterns ---"

  # Pattern 1: Find by ID
  r.compare_drivers('ActiveRecord find(id)') do |driver|
    driver.query('SELECT * FROM benchmark_data WHERE id = 1')
  end

  # Pattern 2: Where clause
  r.compare_drivers('ActiveRecord where(condition)') do |driver|
    driver.query("SELECT * FROM benchmark_data WHERE data LIKE 'user_%' LIMIT 10")
  end

  # Pattern 3: Order and limit
  r.compare_drivers('ActiveRecord order + limit') do |driver|
    driver.query('SELECT * FROM benchmark_data ORDER BY id DESC LIMIT 20')
  end

  # Pattern 4: Count query
  r.compare_drivers('ActiveRecord count') do |driver|
    driver.query('SELECT COUNT(*) FROM benchmark_data')
  end

  # Pattern 5: Create (INSERT)
  r.compare_drivers('ActiveRecord create') do |driver|
    driver.query("INSERT INTO benchmark_data (data, created_at) VALUES ('new_record', NOW())")
    driver.last_insert_id
  end

  # Pattern 6: Update
  r.compare_drivers('ActiveRecord update') do |driver|
    driver.query("UPDATE benchmark_data SET data = 'updated' WHERE id = 1")
    driver.affected_rows
  end

  # Pattern 7: Destroy (DELETE)
  r.compare_drivers('ActiveRecord destroy') do |driver|
    driver.query('DELETE FROM benchmark_data WHERE id = 999')
    driver.affected_rows
  end

  # Simulate a typical Rails request lifecycle
  puts "\n--- Rails Request Simulation ---"

  r.compare_drivers('Typical Rails request (5 queries)') do |driver|
    # 1. Session lookup
    driver.query('SELECT * FROM benchmark_data WHERE id = 1')

    # 2. Find user's data
    driver.query("SELECT * FROM benchmark_data WHERE data = 'user_1'")

    # 3. Count related items
    driver.query('SELECT COUNT(*) FROM benchmark_data WHERE id < 10')

    # 4. Fetch collection
    driver.query('SELECT * FROM benchmark_data ORDER BY id DESC LIMIT 10')

    # 5. Update last_seen
    driver.query("UPDATE benchmark_data SET data = 'seen' WHERE id = 1")
  end

  # Simulate N+1 query problem
  puts "\n--- N+1 Query Problem Simulation ---"

  r.compare_drivers('N+1 (1 + 20 queries)') do |driver|
    # Get users
    users = driver.query('SELECT * FROM benchmark_data LIMIT 20')

    # For each user, fetch related data (N+1!)
    users.each do |user|
      driver.query("SELECT * FROM benchmark_data WHERE id = #{user['id']}")
    end if users.respond_to?(:each)
  end

  # Simulate batch loading (proper way)
  r.compare_drivers('Batch loading (2 queries)') do |driver|
    # Get users
    users = driver.query('SELECT * FROM benchmark_data LIMIT 20')

    # Batch fetch related data
    ids = []
    users.each { |u| ids << u['id'] } if users.respond_to?(:each)
    driver.query("SELECT * FROM benchmark_data WHERE id IN (#{ids.join(',')})")
  end

  # Memory comparison
  puts "\n--- Memory Usage ---"

  r.benchmark_memory('Rails request memory') do |driver|
    10.times do
      driver.query('SELECT * FROM benchmark_data WHERE id = 1')
      driver.query('SELECT * FROM benchmark_data ORDER BY id DESC LIMIT 10')
      driver.query("UPDATE benchmark_data SET data = 'updated' WHERE id = 1")
    end
  end

  # Cleanup
  r.each_driver { |_, d| d.query('TRUNCATE TABLE benchmark_data') }

  r.teardown_drivers
end

runner.export_results

# Display polished suite summary
require_relative '../../lib/suite_summary'
SuiteSummary.display('Real World - Rails Simulation', runner.collector.summary)
