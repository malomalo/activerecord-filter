require 'test_helper'

class ArrayColumnFilterTest < ActiveSupport::TestCase

  schema do
    create_table "properties", force: :cascade do |t|
      t.string   "aliases",              default: [],   array: true
    end
  end

  class Property < ActiveRecord::Base
  end

  test "::filter :array_column => STRING" do
    query = Property.filter(aliases: 'Skyscraper 1')
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.aliases @> '{Skyscraper 1}')
    SQL
  end
  
  test "::filter :array_column => [STRING, STRING]" do
    query = Property.filter(aliases: ['Skyscraper 1', 'Skyscraper 2'])
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.aliases @> '{Skyscraper 1,Skyscraper 2}')
    SQL
  end

  test "::filter :array_column => {contains: [STRING, STRING]}" do
    query = Property.filter(aliases: {contains: ['Skyscraper 1']})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.aliases @> '{Skyscraper 1}')
    SQL
  end
  
  test "::filter :array_column => {overlaps: [STRING, STRING]}" do
    query = Property.filter(aliases: {overlaps: ['Skyscraper 2', 'Skyscraper']})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.aliases && '{Skyscraper 2,Skyscraper}')
    SQL
  end
    
end