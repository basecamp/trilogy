require "test_helper"

class FiberOwnershipTest < TrilogyTest
  def test_owner_cleared_after_exception_allows_reuse
    encoding = Trilogy::Encoding.find("utf8mb4")
    charset = Trilogy::Encoding.charset("utf8mb4")
    bad_opts = { host: "127.0.0.1", port: 9, username: "bad", password: "bad" }

    conn = Trilogy.allocate

    first_error = assert_raises(StandardError) do
      conn.send(:_connect, encoding, charset, bad_opts)
    end
    refute_instance_of(Trilogy::SynchronizationError, first_error)

    # If ownership is cleared in ensure, a subsequent attempt should raise a connection error,
    # not a SynchronizationError from a stuck owner_fiber.
    second_error = assert_raises(StandardError) do
      conn.send(:_connect, encoding, charset, bad_opts)
    end
    refute_instance_of(Trilogy::SynchronizationError, second_error)
  end

  def test_owner_cleared_after_query_exception
    client = new_tcp_client

    # Force a query error (syntax error)
    assert_raises(Trilogy::BaseError) do
      client.query("SELECT * FROM non_existent_table")
    end

    # Should be able to use connection again
    assert_equal 1, client.query("SELECT 1").rows.first.first
  ensure
    client&.close
  end

  def test_owner_cleared_after_ping_exception
    client = new_tcp_client
    client.close # Close it to force error on ping

    assert_raises(Trilogy::Error) do
      client.ping
    end

    # Re-open or check if we can try again (it will fail with closed connection, but NOT SynchronizationError)
    err = assert_raises(Trilogy::Error) do
      client.ping
    end
    refute_instance_of(Trilogy::SynchronizationError, err)
  end

  def test_concurrent_access_from_another_thread_raises
    client = new_tcp_client
    t = nil

    started = Queue.new
    error = nil

    t = Thread.new do
      started << true
      # This will hold the lease while sleeping
      client.query("SELECT SLEEP(0.5)")
    end

    started.pop      # Wait for thread to start
    sleep 0.05       # Give it time to acquire the lease

    begin
      client.ping
    rescue Trilogy::SynchronizationError => e
      error = e
    end

    t.join

    assert_instance_of Trilogy::SynchronizationError, error
    assert_match(/in use by another fiber or thread/, error.message)
  ensure
    t&.join          # Ensure thread finishes before closing
    client&.close
  end

  def test_same_fiber_can_reuse_connection
    client = new_tcp_client

    # Multiple operations from same fiber should work fine
    client.ping
    client.query("SELECT 1")
    client.ping
    result = client.query("SELECT 2")

    assert_equal 2, result.rows.first.first
  ensure
    client&.close
  end
end
