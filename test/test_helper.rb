require 'simplecov'
SimpleCov.start

# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../../lib', __FILE__)


require 'byebug'
require "minitest/autorun"
require 'minitest/reporters'
require 'active_record/filter'
require 'faker'
require 'activerecord-postgis-adapter'

# Setup the test db
ActiveSupport.test_order = :random

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

class ActiveSupport::TestCase
  
  # File 'lib/active_support/testing/declarative.rb'
  def self.test(name, &block)
    test_name = "test_#{name.gsub(/\s+/, '_')}".to_sym
    defined = method_defined? test_name
    raise "#{test_name} is already defined in #{self}" if defined
    if block_given?
      define_method(test_name, &block)
    else
      define_method(test_name) do
        skip "No implementation provided for #{name}"
      end
    end
  end
  
  def self.schema(&block)
    self.class_variable_set(:@@schema, block)
  end
  
  set_callback(:setup, :before) do
    if !self.class.class_variable_defined?(:@@suite_setup_run) && self.class.class_variable_defined?(:@@schema)
      ActiveRecord::Base.establish_connection({
        adapter:  "postgis",
        database: "activerecord-filter-test",
        encoding: "utf8"
      })

      db_config = ActiveRecord::Base.connection_db_config
      db_tasks = ActiveRecord::Tasks::PostgreSQLDatabaseTasks.new(db_config)
      db_tasks.purge

      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Schema.define(&self.class.class_variable_get(:@@schema))
        ActiveRecord::Migration.execute("SELECT c.relname FROM pg_class c WHERE c.relkind = 'S'").each_row do |row|
          ActiveRecord::Migration.execute("ALTER SEQUENCE #{row[0]} RESTART WITH #{rand(50_000)}")
        end
      end
    end
    self.class.class_variable_set(:@@suite_setup_run, true)
  end
  
  def assert_sql(expected, query)
    assert_equal(
          expected.strip.gsub(/"(\w+)"/, '\1').gsub(/\(\s+/, '(').gsub(/\s+\)/, ')').gsub(/[\s|\n]+/, ' '),
      query.to_sql.strip.gsub(/"(\w+)"/, '\1').gsub(/\(\s+/, '(').gsub(/\s+\)/, ')').gsub(/[\s|\n]+/, ' ')
    )
  end
end
