require 'test_helper'
require 'active_support/testing/time_helpers'

class RelativeTimeFilterTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  schema do
    create_table "properties", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.date     "opened_on"
    end
  end

  class Property < ActiveRecord::Base
  end

  NOW = Time.utc(2026, 8, 27, 14, 23, 45)

  setup do
    @original_zone = Time.zone
    Time.zone = 'UTC'
    travel_to NOW
  end

  teardown do
    travel_back
    Time.zone = @original_zone
  end

  # Matches how ActiveRecord quotes a time, which omits sub-second precision
  # when there is none.
  def format_time(value)
    ActiveRecord::Base.lease_connection.quoted_date(value)
  end

  def assert_filter(expected_time, filter, column: 'created_at', operator: '>')
    query = Property.filter(filter)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.#{column} #{operator} '#{expected_time}'
    SQL
  end

  test "'now' as a value" do
    assert_filter(format_time(NOW), {created_at: {gt: 'now'}})
  end

  test "'now' as a bare value is an equality check" do
    assert_filter(format_time(NOW), {created_at: 'now'}, operator: '=')
  end

  test "a keyword may be a Symbol" do
    assert_filter(format_time(NOW + 7.days), {created_at: {gt: {at: :now, add: '7 days'}}})
    assert_filter(format_time(NOW), {created_at: :now}, operator: '=')
  end

  test "'today', 'yesterday' and 'tomorrow'" do
    assert_filter(format_time(NOW.beginning_of_day), {created_at: {gt: 'today'}})
    assert_filter(format_time(NOW.yesterday.beginning_of_day), {created_at: {gt: 'yesterday'}})
    assert_filter(format_time(NOW.tomorrow.beginning_of_day), {created_at: {gt: 'tomorrow'}})
  end

  test "an :at anchor with no operations" do
    assert_filter(format_time(NOW), {created_at: {gt: {at: 'now'}}})
    assert_filter(format_time(Time.utc(2026, 1, 1)), {created_at: {gt: {at: '2026-01-01'}}})
    assert_filter(
      format_time(Time.utc(2026, 1, 1, 6, 30)),
      {created_at: {gt: {at: '2026-01-01 06:30:00'}}}
    )
  end

  test "the :at key may be a String" do
    assert_filter(format_time(NOW + 1.day), {created_at: {gt: {'at' => 'now', 'add' => '1 day'}}})
  end

  test ":add on 'now'" do
    assert_filter(format_time(NOW + 7.days), {created_at: {gt: {at: 'now', add: '7 days'}}})
    assert_filter(format_time(NOW + 1.week), {created_at: {gt: {at: 'now', add: '1 week'}}})
    assert_filter(format_time(NOW + 3.months), {created_at: {gt: {at: 'now', add: '3 months'}}})
    assert_filter(format_time(NOW + 2.years), {created_at: {gt: {at: 'now', add: '2 years'}}})
  end

  test ":subtract on a date anchor" do
    assert_filter(
      format_time(Time.utc(2026, 8, 2) - 5.months),
      {created_at: {lte: {at: '2026-08-02', subtract: '5 months'}}},
      operator: '<='
    )
  end

  test ":add accepts singular, abbreviated and multi-part durations" do
    assert_filter(format_time(NOW + 1.day), {created_at: {gt: {at: 'now', add: '1 day'}}})
    assert_filter(format_time(NOW + 3.hours), {created_at: {gt: {at: 'now', add: '3 hrs'}}})
    assert_filter(format_time(NOW + 90.seconds), {created_at: {gt: {at: 'now', add: '90s'}}})
    assert_filter(format_time(NOW + 6.months), {created_at: {gt: {at: 'now', add: '2 quarters'}}})
    assert_filter(
      format_time(NOW + 1.year + 2.months + 3.days),
      {created_at: {gt: {at: 'now', add: '1 year 2 months 3 days'}}}
    )
  end

  test ":add accepts a Hash of units" do
    assert_filter(
      format_time(NOW + 1.month + 10.days),
      {created_at: {gt: {at: 'now', add: {months: 1, days: 10}}}}
    )
  end

  test ":add accepts a negative amount" do
    assert_filter(format_time(NOW - 7.days), {created_at: {gt: {at: 'now', add: '-7 days'}}})
  end

  test ":start_of" do
    assert_filter(format_time(NOW.beginning_of_day), {created_at: {gt: {at: 'now', start_of: 'day'}}})
    assert_filter(format_time(NOW.beginning_of_week), {created_at: {gt: {at: 'now', start_of: 'week'}}})
    assert_filter(format_time(NOW.beginning_of_month), {created_at: {gt: {at: 'now', start_of: 'month'}}})
    assert_filter(format_time(NOW.beginning_of_quarter), {created_at: {gt: {at: 'now', start_of: 'quarter'}}})
    assert_filter(format_time(NOW.beginning_of_year), {created_at: {gt: {at: 'now', start_of: 'year'}}})
    assert_filter(format_time(NOW.change(usec: 0)), {created_at: {gt: {at: 'now', start_of: 'second'}}})
  end

  test ":end_of" do
    assert_filter(
      format_time(Time.utc(2027, 1, 5).end_of_month),
      {created_at: {lt: {at: '2027-01-05', end_of: 'month'}}},
      operator: '<'
    )
    assert_filter(format_time(NOW.end_of_day), {created_at: {lt: {at: 'now', end_of: 'day'}}}, operator: '<')
    assert_filter(
      format_time(NOW.change(usec: 999999)),
      {created_at: {lt: {at: 'now', end_of: 'second'}}},
      operator: '<'
    )
  end

  test "shifting happens before truncating, whatever the key order" do
    expected = format_time((NOW - 1.month).beginning_of_month)

    assert_filter(expected, {created_at: {gte: {at: 'now', subtract: '1 month', start_of: 'month'}}}, operator: '>=')
    assert_filter(expected, {created_at: {gte: {at: 'now', start_of: 'month', subtract: '1 month'}}}, operator: '>=')
    assert_filter(expected, {created_at: {gte: {start_of: 'month', subtract: '1 month', at: 'now'}}}, operator: '>=')
  end

  test "combining relative predicates" do
    query = Property.filter(created_at: {
      gte: {at: 'now', subtract: '1 month', start_of: 'month'},
      lt:  {at: 'now', start_of: 'month'}
    })

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.created_at >= '#{format_time((NOW - 1.month).beginning_of_month)}'
        AND properties.created_at < '#{format_time(NOW.beginning_of_month)}'
    SQL
  end

  test "relative values inside :in" do
    query = Property.filter(created_at: {in: ['now', {at: 'now', add: '1 day'}]})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.created_at IN ('#{format_time(NOW)}', '#{format_time(NOW + 1.day)}')
    SQL
  end

  test "relative values on a date column" do
    query = Property.filter(opened_on: {gt: {at: 'now', subtract: '1 year', start_of: 'year'}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.opened_on > '#{(NOW - 1.year).beginning_of_year.to_date.iso8601}'
    SQL
  end

  test "a relative hash as a bare value is an equality check" do
    assert_filter(
      format_time(NOW.beginning_of_day),
      {created_at: {at: 'now', start_of: 'day'}},
      operator: '='
    )
  end

  test "existing behavior is unchanged" do
    time = Time.utc(2026, 2, 3, 4, 5, 6)

    assert_filter(format_time(time), {created_at: {gt: time}})
    assert_filter(format_time(time), {created_at: time}, operator: '=')

    # A plain date string is still cast by ActiveRecord, not parsed here.
    assert_filter('2026-02-03 00:00:00', {created_at: {gt: '2026-02-03'}})

    query = Property.filter(created_at: nil)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.* FROM properties WHERE properties.created_at IS NULL
    SQL
  end

  test "a predicate hash is never mistaken for a relative hash" do
    # Without an `at` key there is nothing to resolve, so an unknown predicate
    # is still rejected as before.
    assert_raises(RuntimeError) do
      Property.filter(created_at: {some_predicate: 'now'}).to_sql
    end
  end

  test "an unknown anchor raises" do
    assert_raises(ActiveRecord::UnkownFilterError) do
      Property.filter(created_at: {gt: {at: 'not-a-date', add: '1 day'}}).to_sql
    end

    assert_raises(ActiveRecord::UnkownFilterError) do
      Property.filter(created_at: {gt: {at: 'not-a-date'}}).to_sql
    end
  end

  test "an unknown operation raises" do
    assert_raises(ActiveRecord::UnkownFilterError) do
      Property.filter(created_at: {gt: {at: 'now', round_to: 'day'}}).to_sql
    end
  end

  test "an unknown unit raises" do
    assert_raises(ActiveRecord::UnkownFilterError) do
      Property.filter(created_at: {gt: {at: 'now', add: '1 fortnight'}}).to_sql
    end

    assert_raises(ActiveRecord::UnkownFilterError) do
      Property.filter(created_at: {gt: {at: 'now', start_of: 'fortnight'}}).to_sql
    end
  end

  test "a malformed duration raises" do
    assert_raises(ActiveRecord::UnkownFilterError) do
      Property.filter(created_at: {gt: {at: 'now', add: 'a week'}}).to_sql
    end
  end
end
