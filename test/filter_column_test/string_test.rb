require 'test_helper'

class StringFilterTest < ActiveSupport::TestCase
  schema do
    create_table "properties", force: :cascade do |t|
      t.string   "name",                    limit: 255
    end
  end

  class Property < ActiveRecord::Base
  end

  test "::filter :string_column => string" do
    query = Property.filter(name: 'b')
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.name = 'b'
    SQL
  end

  test "::filter :string_column => nil" do
    query = Property.filter(name: nil)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.name IS NULL
    SQL
    
    query = Property.filter(name: 'nil')
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.name IS NULL
    SQL
  end
  
  test "::filter :string_column => boolean" do
    query = Property.filter(name: true)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.name IS NOT NULL
    SQL
    
    query = Property.filter(name: false)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.name IS NULL
    SQL
  end
  
  test "::filter :string_column => {:not => STRING}" do
    query = Property.filter(name: {not: 'b'})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.name != 'b'
    SQL
    
    query = Property.filter(name: {not_equal: 'b'})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.name != 'b'
    SQL
    
    query = Property.filter(name: {neq: 'b'})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.name != 'b'
    SQL
  end
  
  test "::filter :array_column => {:not_in => [STRING, STRING]}" do
    query = Property.filter(name: {not_in: ['b', 'c']})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.name NOT IN ('b', 'c')
    SQL
  end
  
  test "::filter array_column: {like: STRING}" do
    query = Property.filter(name: {like: 'nam%'})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.name LIKE 'nam%'
    SQL
  end
  
  test "::filter array_column: {ilike: STRING}" do
    query = Property.filter(name: {ilike: 'nam%'})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.name ILIKE 'nam%'
    SQL
  end

end