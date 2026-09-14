require 'test_helper'
require 'active_support/testing/time_helpers'

class RelativeTimeFilterTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  schema do
    create_table "properties", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.date     "opened_on"
      t.tsrange  "window"
      t.daterange "span"
      t.int4range "seats"
    end

    create_table "photos", force: :cascade do |t|
      t.integer  "property_id"
      t.datetime "created_at", null: false
    end
  end

  class Property < ActiveRecord::Base
    has_many :photos
  end

  class Photo < ActiveRecord::Base
    belongs_to :property
  end

  NOW = Time.utc(2026, 8, 27, 14, 23, 45)

  setup do
    @original_zone = Time.zone
    Time.zone = 'UTC'
    travel_to NOW
    ActiveRecord::Filter::RelativeTime.enable!
  end

  teardown do
    ActiveRecord::Filter::RelativeTime.disable!
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

    # The same unit names `add`/`subtract` take, abbreviations included.
    assert_filter(format_time(NOW.beginning_of_hour), {created_at: {gt: {at: 'now', start_of: 'hr'}}})
    assert_filter(format_time(NOW.beginning_of_quarter), {created_at: {gt: {at: 'now', start_of: 'qtr'}}})
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

  test "every value in one query resolves against one reading of the clock" do
    # `tick` moves the clock in the middle of the build. The reading is taken
    # once, at the top, so the columns resolved after it still agree with the
    # ones resolved before — without that, a range could straddle a tick, and
    # at the wrong moment a day.
    # The block runs against the predicate builder, so the clock is moved
    # through the test case itself.
    test_case = self
    Property.filter_on(:tick) do |klass, table, key, value, relation_trail, alias_tracker|
      test_case.travel_to(NOW + 1.hour)
      table.arel_table[:id].not_eq(nil)
    end

    sql = Property.filter(tick: true, created_at: {gte: 'now'}, opened_on: {lt: 'now'}).to_sql

    assert_includes sql, format_time(NOW)
    assert_includes sql, NOW.to_date.iso8601
    refute_includes sql, format_time(NOW + 1.hour)

    # The next query reads the clock again.
    assert_includes Property.filter(created_at: {gte: 'now'}).to_sql, format_time(NOW + 1.hour)
  end

  test "every 'now' in one value is the same 'now'" do
    # The clock is read once per value and carried down, so the two halves of
    # a range cannot land on either side of a tick — at the wrong moment,
    # either side of a day. Passing the reading in is what makes that visible.
    anchor = Time.utc(2021, 3, 4, 5, 6, 7)

    resolved = ActiveRecord::Filter::RelativeTime.resolve_filter_value(
      {gte: 'now', lt: {at: 'now', add: '1 day'}},
      anchor
    )

    assert_equal anchor, resolved[:gte]
    assert_equal anchor + 1.day, resolved[:lt]
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

  # --- range columns over a date/time element type ---

  test "a point in a range column" do
    query = Property.filter(window: {contains: 'now'})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.window @> CAST('#{format_time(NOW)}' AS timestamp)
    SQL
  end

  test "either bound of a range operand" do
    query = Property.filter(window: {
      overlaps: {begin: {at: 'now', start_of: 'day'}, end_before: {at: 'now', add: '1 day'}}
    })

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.window && '[#{format_time(NOW.beginning_of_day)},#{format_time(NOW + 1.day)})'
    SQL
  end

  test "a bound the range type cannot carry" do
    # `begin_after` has no Ruby Range, so RangeHelper builds the operand with
    # PostgreSQL's own constructor — the bounds are resolved either way.
    query = Property.filter(window: {overlaps: {begin_after: 'now', end: {at: 'now', add: '1 day'}}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.window && tsrange('#{format_time(NOW)}', '#{format_time(NOW + 1.day)}', '(]')
    SQL
  end

  test "a Ruby Range of relative values" do
    # Both ends are resolved. A Range can only hold ends Ruby can compare, so
    # mixing a keyword with an `at` Hash means writing the bounds out instead.
    query = Property.filter(window: {contained_by: ('now'..'2027-01-01')})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.window <@ '[#{format_time(NOW)},#{format_time(Time.utc(2027, 1, 1))}]'
    SQL
  end

  test "a daterange resolves to the element type" do
    query = Property.filter(span: {contains: {at: 'now', add: '1 day'}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.span @> CAST('#{(NOW + 1.day).to_date.iso8601}' AS date)
    SQL
  end

  test "a range column over any other element type is left alone" do
    query = Property.filter(seats: {contains: 5})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.* FROM properties WHERE properties.seats @> CAST(5 AS integer)
    SQL

    # Nothing resolves 'now' for it, so it is still read as an integer.
    assert_raises(ActiveRecord::UnkownFilterError) do
      Property.filter(seats: {contains: 'now'}).to_sql
    end
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

  # `ActionController::Parameters#to_unsafe_h` (see RelationExtension#clean_filters)
  # returns a HashWithIndifferentAccess, and that indifference reaches all the
  # way down into an operation Hash's keys. `apply` used to convert those keys
  # with `transform_keys { key.to_s.to_sym }`, but a HashWithIndifferentAccess
  # re-stringifies whatever a block returns, so the Symbol never survives and
  # every operation looked unknown.
  # https://github.com/malomalo/activerecord-filter/pull/29#issuecomment-5639385327
  test "an operation Hash that is itself indifferent still resolves" do
    indifferent = { 'contains' => { 'at' => 'now', 'subtract' => '1 weeks' } }.with_indifferent_access

    assert_filter(
      format_time(NOW - 1.week),
      { created_at: indifferent[:contains] },
      operator: '='
    )

    query = Property.filter(window: { indifferent.keys.first => indifferent.values.first })
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.window @> CAST('#{format_time(NOW - 1.week)}' AS timestamp)
    SQL
  end

  # --- the opt-in itself ---

  test "disabled, a relative value is left to ActiveRecord" do
    ActiveRecord::Filter::RelativeTime.disable!

    # The guarantee that matters: with the feature off, nothing in this module
    # touches the value, so upgrading cannot change an existing filter.
    refute_includes Property.filter(created_at: {gt: "now"}).to_sql, format_time(NOW)
  end

  test "enable! is idempotent" do
    ActiveRecord::Filter::RelativeTime.enable!
    ActiveRecord::Filter::RelativeTime.enable!

    occurrences = ActiveRecord::PredicateBuilder.ancestors.count do |mod|
      mod == ActiveRecord::Filter::RelativeTime::PredicateBuilderExtension
    end

    assert_equal 1, occurrences
  end

  test "the global switch covers filters across associations" do
    # Nested builders are built from the associated class, so this only works
    # because enable! patches the shared PredicateBuilder rather than a model.
    assert_includes Property.filter(photos: {created_at: {gt: "now"}}).to_sql, format_time(NOW)
  end
end
