require "trilogy"
require_relative "base_driver"

class TrilogyDriver < BaseDriver
  def connect
    @connection = Trilogy.new(config)
    @version = Trilogy::VERSION
    self
  end

  def disconnect
    @connection&.close
    @connection = nil
  end

  def connected?
    if @connection
      begin
        @connection.ping
        true
      rescue
        false
      end
    end
  end

  def ping
    @connection.ping
  end

  def query(sql, *params)
    if params.empty?
      @connection.query(sql)
    else
      # Simple parameter substitution for benchmarking
      # In production, use proper prepared statements
      escaped_params = params.map { |p| escape(p.to_s) }
      sql_with_params = sql.dup
      escaped_params.each do |param|
        sql_with_params = sql_with_params.sub("?", "'#{param}'")
      end
      @connection.query(sql_with_params)
    end
  end

  def escape(string)
    @connection.escape(string)
  end

  def last_insert_id
    @connection.last_insert_id
  end

  def affected_rows
    @connection.affected_rows
  end

  def multi_query(sql)
    results = []
    @connection.query(sql).each do |result|
      results << result
    end
    results
  end

  def server_info
    @connection.server_info
  end

  def driver_version
    Trilogy::VERSION
  end

  def supports_multi_statements?
    true
  end

  def supports_async?
    true  # Trilogy works with fiber schedulers
  end

  # Trilogy-specific methods for deeper benchmarking
  def query_flags
    @connection.query_flags
  end

  def server_status
    @connection.server_status
  end

  def warning_count
    @connection.warning_count
  end
end
