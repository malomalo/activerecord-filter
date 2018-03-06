require 'test_helper'

class DatetimeFilterTest < ActiveSupport::TestCase
  schema do
    create_table "properties", force: :cascade do |t|
      t.datetime "created_at",                         null: false
    end
  end

  class Property < ActiveRecord::Base
  end
  
  def format_time(value)
    value.utc.iso8601(6).sub(/T/, ' ').sub(/Z$/, '')
  end

  test "::filter :datetime_column => {:gt => date, :lt => date}" do
    t1 = 5.days.ago
    t2 = 4.days.ago
    t3 = 1.day.ago
    t4 = 1.day.from_now

    query = Property.filter(created_at: {gte: t2, lte: t3})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.created_at >= '#{format_time(t2)}'
        AND properties.created_at <= '#{format_time(t3)}'
    SQL
    

    query = Property.filter(:created_at => {gt: t1, lt: t2})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.created_at > '#{format_time(t1)}'
        AND properties.created_at < '#{format_time(t2)}'
    SQL

    query = Property.filter(:created_at => {gte: t3, lte: t4})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.created_at >= '#{format_time(t3)}'
        AND properties.created_at <= '#{format_time(t4)}'
    SQL
  end

  test "::filter :datetime_column => date" do
    time = Time.now
    
    query = Property.filter(created_at: time)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.created_at = '#{format_time(time)}'
    SQL
  end

end
