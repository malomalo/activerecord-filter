require 'test_helper'

class BooleanFilterTest < ActiveSupport::TestCase

  schema do
    create_table "properties", force: :cascade do |t|
      t.boolean  "active",             default: false
    end
  end

  class Property < ActiveRecord::Base
  end

  test "::filter :boolean_column => boolean" do
    query = Property.filter(active: true)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.active = TRUE
    SQL
    
    query = Property.filter(active: "true")
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.active = TRUE
    SQL
    
    
    query = Property.filter(active: false)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.active = FALSE
    SQL
    
    query = Property.filter(active: "false")
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.active = FALSE
    SQL
  end

  test "::filter :boolean_column => nil" do
    query = Property.filter(active: nil)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.active IS NULL
    SQL
  end

end
