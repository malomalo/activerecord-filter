require 'test_helper'

class IntegerFilterTest < ActiveSupport::TestCase

  schema do
    create_table "properties", force: :cascade do |t|
      t.integer  "constructed"
    end
  end

  class Property < ActiveRecord::Base
  end

  test "::filter :integer_column => {:gt => x}" do
    query = Property.filter(constructed: { gt: 1 })
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.constructed > 1)
    SQL
    
    query = Property.filter(constructed: { greater_than: 1 })
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.constructed > 1)
    SQL
  end

  test "::filter :integer_column => {:gteq => x}" do
    query = Property.filter(constructed: { gte: 1 })
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.constructed >= 1)
    SQL

    query = Property.filter(constructed: { gteq: 1 })
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.constructed >= 1)
    SQL

    query = Property.filter(constructed: { greater_than_or_equal_to: 1 })
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.constructed >= 1)
    SQL
  end

  test "::filter :integer_column => {:lt => x}" do
    query = Property.filter(constructed: { lt: 1 })
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.constructed < 1)
    SQL
    
    query = Property.filter(constructed: { less_than: 1 })
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.constructed < 1)
    SQL
  end

  test "::filter :integer_column => {:lteq => x}" do
    query = Property.filter(constructed: { lte: 1 })
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.constructed <= 1)
    SQL
    
    query = Property.filter(constructed: { lteq: 1 })
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.constructed <= 1)
    SQL
    
    query = Property.filter(constructed: { less_than_or_equal_to: 1 })
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.constructed <= 1)
    SQL
  end

  test "::filter :integer_column => int " do
    query = Property.filter(constructed: 1)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.constructed = 1
    SQL
  end

  test "::filter :integer_column => str" do
    query = Property.filter(constructed: '1')
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.constructed = 1
    SQL
  end

  test "::filter :integer_column => bool " do
    query = Property.filter(constructed: true)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.constructed IS NOT NULL)
    SQL

    query = Property.filter(constructed: "true")
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.constructed IS NOT NULL)
    SQL
    
    query = Property.filter(constructed: false)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.constructed IS NULL
    SQL

    query = Property.filter(constructed: "false")
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.constructed IS NULL
    SQL
  end

end
