require 'mysql2'
require_relative 'base_driver'

class Mysql2Driver < BaseDriver
  def connect
    @connection = Mysql2::Client.new(config)
    @version = Mysql2::VERSION
    self
  end

  def disconnect
    @connection&.close
    @connection = nil
  end

  def connected?
    return false unless @connection
    begin
      @connection.ping
      true
    rescue
      false
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
      escaped_params = params.map { |p| escape(p.to_s) }
      sql_with_params = sql.dup
      escaped_params.each do |param|
        sql_with_params = sql_with_params.sub('?', "'#{param}'")
      end
      @connection.query(sql_with_params)
    end
  end

  def escape(string)
    @connection.escape(string)
  end

  def last_insert_id
    @connection.last_id
  end

  def affected_rows
    @connection.affected_rows
  end

  def multi_query(sql)
    results = []
    @connection.query(sql, stream: false, multiple_statements: true)
    while @connection.next_result
      results << @connection.store_result
    end
    results
  end

  def prepare(sql)
    @connection.prepare(sql)
  end

  def execute_prepared(stmt, *params)
    stmt.execute(*params)
  end

  def server_info
    @connection.server_info
  end

  def driver_version
    Mysql2::VERSION
  end

  def supports_prepared_statements?
    true
  end

  def supports_multi_statements?
    true
  end

  def supports_async?
    false  # mysql2 doesn't support fiber schedulers by default
  end

  # MySQL2-specific options for benchmarking
  def query_options(options = {})
    @connection.query_options.merge!(options)
  end
end
