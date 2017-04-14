require 'test_helper'

class ArrayColumnFilterTest < ActiveSupport::TestCase

  schema do
    create_table "properties", force: :cascade do |t|
      t.string   "aliases",              default: [],   array: true
      t.integer  "region_ids",           default: [],   array: true
    end
  end

  class Property < ActiveRecord::Base
  end

  test "::filter :string_array_column => STRING" do
    query = Property.filter(aliases: 'Skyscraper 1')
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.aliases = '{Skyscraper 1}'
    SQL
  end
  
  test "::filter :string_array_column => [STRING, STRING]" do
    query = Property.filter(aliases: ['Skyscraper 1', 'Skyscraper 2'])
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.aliases = '{Skyscraper 1,Skyscraper 2}'
    SQL
  end

  test "::filter :string_array_column => {contains: [STRING, STRING]}" do
    query = Property.filter(aliases: {contains: ['Skyscraper 1']})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.aliases @> '{Skyscraper 1}')
    SQL
  end
  
  test "::filter :string_array_column => {overlaps: [STRING, STRING]}" do
    query = Property.filter(aliases: {overlaps: ['Skyscraper 2', 'Skyscraper']})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.aliases && '{Skyscraper 2,Skyscraper}')
    SQL
  end

  test "::filter :string_array_column => {contains: [STRING]}" do
    query = Property.filter(aliases: {contains: ['Skyscraper']})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.aliases @> '{Skyscraper}')
    SQL
  end

  test "::filter :string_array_column => {excludes: STRING}" do
    query = Property.filter(aliases: {excludes: 'Skyscraper'})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (NOT (properties.aliases @> '{Skyscraper}'))
    SQL
  end

  test "::filter :string_array_column => {excludes: [STRING]}" do
    query = Property.filter(aliases: {excludes: ['Skyscraper']})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (NOT (properties.aliases @> '{Skyscraper}'))
    SQL
  end
  
  test "::filter :int_array_column => {overlaps: [INT]}" do
    query = Property.filter(region_ids: {overlaps: [10]})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.region_ids && '{10}')
    SQL
  end
    
end