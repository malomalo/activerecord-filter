require 'test_helper'

class RangeColumnFilterTest < ActiveSupport::TestCase

  schema do
    create_table "players", force: :cascade do |t|
      t.tsrange   "career_period"
      t.daterange "season"
      t.int4range "jersey_numbers"
    end
  end

  class Player < ActiveRecord::Base
  end

  # `contains` (@>) against a single point casts the operand to the range's
  # element type — PostgreSQL rejects a bare unknown-typed literal here.
  test "contains a point" do
    query = Player.filter(career_period: {contains: '2005-06-15'})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period @> CAST('2005-06-15' AS timestamp)
    SQL
  end

  # The four bound combinations. Exclusivity lives in the key name, so all of
  # them are expressible; the two with an inclusive lower bound become a Ruby
  # Range, and the two without fall back to the range constructor.
  test "begin/end is inclusive on both ends" do
    query = Player.filter(jersey_numbers: {contains: {begin: 1, end: 3}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.jersey_numbers @> '[1,3]'
    SQL
  end

  test "end_before excludes the upper bound" do
    query = Player.filter(jersey_numbers: {contains: {begin: 1, end_before: 3}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.jersey_numbers @> '[1,3)'
    SQL
  end

  test "begin_after excludes the lower bound" do
    query = Player.filter(jersey_numbers: {contains: {begin_after: 1, end: 3}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.jersey_numbers @> int4range(1, 3, '(]')
    SQL
  end

  test "begin_after with end_before excludes both bounds" do
    query = Player.filter(jersey_numbers: {contains: {begin_after: 1, end_before: 3}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.jersey_numbers @> int4range(1, 3, '()')
    SQL
  end

  # A Ruby Range says the same thing as the Hash, and is accepted directly.
  test "a Ruby Range is accepted as a value" do
    assert_equal(
      Player.filter(jersey_numbers: {contains: {begin: 1, end: 3}}).to_sql,
      Player.filter(jersey_numbers: {contains: 1..3}).to_sql
    )
    assert_equal(
      Player.filter(jersey_numbers: {contains: {begin: 1, end_before: 3}}).to_sql,
      Player.filter(jersey_numbers: {contains: 1...3}).to_sql
    )
    assert_equal(
      Player.filter(jersey_numbers: {contains: 1...3}).to_sql,
      Player.filter(jersey_numbers: {contains: Range.new(1, 3, true)}).to_sql
    )
  end

  test "overlaps a range" do
    query = Player.filter(career_period: {overlaps: {begin: '2008-01-01', end_before: '2016-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period && '[2008-01-01 00:00:00,2016-01-01 00:00:00)'
    SQL
  end

  test "contained_by a range" do
    query = Player.filter(career_period: {contained_by: {begin: '1999-01-01', end_before: '2011-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period <@ '[1999-01-01 00:00:00,2011-01-01 00:00:00)'
    SQL
  end

  # An absent bound is an unbounded end.
  test "an omitted end is unbounded" do
    query = Player.filter(jersey_numbers: {overlaps: {begin: 1}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.jersey_numbers && '[1,]'
    SQL
  end

  test "an omitted begin is unbounded" do
    query = Player.filter(jersey_numbers: {overlaps: {end: 3}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.jersey_numbers && '[,3]'
    SQL
  end

  test "an omitted end with an exclusive begin is unbounded" do
    query = Player.filter(jersey_numbers: {overlaps: {begin_after: 1}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.jersey_numbers && int4range(1, NULL, '(]')
    SQL
  end

  test "eq with a range hash is range equality" do
    query = Player.filter(career_period: {eq: {begin: '2015-01-01', end_before: '2025-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period = '[2015-01-01 00:00:00,2025-01-01 00:00:00)'
    SQL
  end

  # The serialized literal and the point cast both track the column's own type.
  test "a daterange column serializes dates and casts a date point" do
    query = Player.filter(season: {contains: '2026-06-15', eq: {begin: '2026-01-01', end_before: '2026-12-31'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.season @> CAST('2026-06-15' AS date)
        AND players.season = '[2026-01-01,2026-12-31)'
    SQL
  end

  # Two range predicates on one column compose with AND.
  test "range predicates compose" do
    query = Player.filter(career_period: {contains: '2005-01-01', contained_by: {begin: '1990-01-01', end_before: '2030-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period @> CAST('2005-01-01' AS timestamp)
        AND players.career_period <@ '[1990-01-01 00:00:00,2030-01-01 00:00:00)'
    SQL
  end

  # Naming one end twice is a contradiction, not a precedence question.
  test "conflicting bounds on the same end raise" do
    error = assert_raises(ActiveRecord::UnkownFilterError) do
      Player.filter(jersey_numbers: {contains: {begin: 1, begin_after: 2, end: 3}}).to_sql
    end
    assert_match(/Conflicting range bounds/, error.message)

    assert_raises(ActiveRecord::UnkownFilterError) do
      Player.filter(jersey_numbers: {contains: {begin: 1, end: 3, end_before: 4}}).to_sql
    end
  end

  # Every generated form has to survive contact with PostgreSQL.
  test "every bound combination executes" do
    [
      {begin: 1, end: 3},
      {begin: 1, end_before: 3},
      {begin_after: 1, end: 3},
      {begin_after: 1, end_before: 3},
      {begin: 1},
      {end: 3},
      {begin_after: 1}
    ].each do |bounds|
      Player.filter(jersey_numbers: {contains: bounds}).to_a
    end
  end

  # ActiveRecord models every range column with OID::Range, including types
  # declared with `CREATE TYPE ... AS RANGE`. A hardcoded list of the built-in
  # range type names would not have covered this one.
  test "a user-defined range type is recognised" do
    connection = ActiveRecord::Base.lease_connection
    connection.execute("CREATE TYPE textrange AS RANGE (subtype = text)")
    connection.execute("ALTER TABLE players ADD COLUMN nicknames textrange")
    Player.reset_column_information

    query = Player.filter(nicknames: {contains: {begin: 'a', end_before: 'm'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.nicknames @> '[a,m)'
    SQL
    query.to_a
  ensure
    connection.execute("ALTER TABLE players DROP COLUMN IF EXISTS nicknames")
    connection.execute("DROP TYPE IF EXISTS textrange")
    Player.reset_column_information
  end

  # A Hash operand to a range predicate is always a range, so an unrecognised
  # bound key is a typo rather than something to fall through on.
  test "an unknown bound key raises" do
    error = assert_raises(ActiveRecord::UnkownFilterError) do
      Player.filter(career_period: {contains: {bgein: '2005-01-01', end: '2009-01-01'}}).to_sql
    end
    assert_match(/Unknown range bound "bgein"/, error.message)

    assert_raises(ActiveRecord::UnkownFilterError) do
      Player.filter(career_period: {eq: {bgein: '2005-01-01'}}).to_sql
    end

    assert_raises(ActiveRecord::UnkownFilterError) do
      Player.filter(career_period: {contains: {}}).to_sql
    end
  end

  # The element type is resolved through the connection rather than a constant
  # because ActiveRecord shifts the subtype symbol with the app's datetime_type
  # setting — :datetime under one, :timestamp under the other. type_to_sql is
  # what reconciles them, so a tsrange casts to timestamp either way. A static
  # :datetime => 'timestamp' map would emit timestamptz under the second.
  test "the point cast survives a datetime_type change" do
    adapter = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
    original = adapter.datetime_type

    [:timestamp, :timestamptz].each do |setting|
      adapter.datetime_type = setting
      Player.reset_column_information

      assert_sql(<<-SQL, Player.filter(career_period: {contains: '2005-06-15'}))
        SELECT players.*
        FROM players
        WHERE players.career_period @> CAST('2005-06-15' AS timestamp)
      SQL
    end
  ensure
    adapter.datetime_type = original
    Player.reset_column_information
  end

  # neq is the mirror of eq, so it takes a range the same way.
  test "neq with a range hash is range inequality" do
    query = Player.filter(career_period: {neq: {begin: '2015-01-01', end_before: '2025-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period != '[2015-01-01 00:00:00,2025-01-01 00:00:00)'
    SQL
    query.to_a
  end

  test "not and not_equal are aliases for neq" do
    expected = Player.filter(career_period: {neq: {begin: '2015-01-01', end: '2025-01-01'}}).to_sql

    assert_equal expected, Player.filter(career_period: {not: {begin: '2015-01-01', end: '2025-01-01'}}).to_sql
    assert_equal expected, Player.filter(career_period: {not_equal: {begin: '2015-01-01', end: '2025-01-01'}}).to_sql
  end

end
