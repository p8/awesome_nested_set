module SqlAssertions
  def capture_sql
    ActiveRecord::Base.connection.materialize_transactions if Rails::VERSION::MAJOR > 5
    SQLCounter.clear_log
    yield
    SQLCounter.log.dup
  end

  def assert_sql(*patterns_to_match)
    capture_sql { yield }
  ensure
    failed_patterns = []
    patterns_to_match.compact.each do |pattern|
      failed_patterns << pattern unless SQLCounter.log_all.any? { |sql| pattern === sql }
    end
    assert failed_patterns.empty?, "Query pattern(s) #{failed_patterns.map(&:strip).join(', ')} not found.#{SQLCounter.log.size == 0 ? '' : "\nQueries:\n#{SQLCounter.log.map(&:inspect).join("\n")}"}"
  end

  class SQLCounter
    class << self
      attr_accessor :ignored_sql, :log, :log_all
      def clear_log; self.log = []; self.log_all = []; end
    end

    clear_log

    def call(name, start, finish, message_id, values)
      return if values[:cached]

      sql = values[:sql].squish
      self.class.log_all << sql
      self.class.log << sql unless ["SCHEMA", "TRANSACTION"].include? values[:name]
    end
  end

  ActiveSupport::Notifications.subscribe("sql.active_record", SQLCounter.new)
end
