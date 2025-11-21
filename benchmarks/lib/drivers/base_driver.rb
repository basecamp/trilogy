# Base driver interface for fair benchmark comparison
class BaseDriver
  attr_reader :name, :version

  def initialize(config)
    @config = config
    @name = self.class.name.split('::').last.gsub('Driver', '').downcase
    @connection = nil
  end

  # Connection management
  def connect
    raise NotImplementedError, "#{self.class} must implement #connect"
  end

  def disconnect
    raise NotImplementedError, "#{self.class} must implement #disconnect"
  end

  def connected?
    raise NotImplementedError, "#{self.class} must implement #connected?"
  end

  def ping
    raise NotImplementedError, "#{self.class} must implement #ping"
  end

  # Query methods
  def query(sql, *params)
    raise NotImplementedError, "#{self.class} must implement #query"
  end

  def escape(string)
    raise NotImplementedError, "#{self.class} must implement #escape"
  end

  # Metadata methods
  def last_insert_id
    raise NotImplementedError, "#{self.class} must implement #last_insert_id"
  end

  def affected_rows
    raise NotImplementedError, "#{self.class} must implement #affected_rows"
  end

  # Transaction support
  def transaction
    query("BEGIN")
    yield
    query("COMMIT")
  rescue => e
    query("ROLLBACK")
    raise e
  end

  # Multi-statement support
  def multi_query(sql)
    raise NotImplementedError, "#{self.class} must implement #multi_query"
  end

  # Prepared statements (if supported)
  def prepare(sql)
    raise NotImplementedError, "Prepared statements not supported by #{self.class}"
  end

  def execute_prepared(stmt, *params)
    raise NotImplementedError, "Prepared statements not supported by #{self.class}"
  end

  # Driver info
  def server_info
    raise NotImplementedError, "#{self.class} must implement #server_info"
  end

  def driver_version
    raise NotImplementedError, "#{self.class} must implement #driver_version"
  end

  # Configuration
  def supports_prepared_statements?
    false
  end

  def supports_multi_statements?
    false
  end

  def supports_async?
    false
  end

  protected

  attr_reader :config, :connection
end
