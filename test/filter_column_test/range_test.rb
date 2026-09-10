require 'test_helper'

class RangeColumnFilterTest < ActiveSupport::TestCase

  schema do
    create_table "players", force: :cascade do |t|
      t.tsrange   "career_period"
      t.daterange "season"
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

  # A range operand becomes a `tsrange(lower, upper)` constructor; the
  # constructor's argument types cast the bounds, so they need no explicit cast.
  test "contains a range" do
    query = Player.filter(career_period: {contains: {from: '2001-01-01', to: '2009-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period @> tsrange('2001-01-01', '2009-01-01')
    SQL
  end

  test "overlaps a range" do
    query = Player.filter(career_period: {overlaps: {from: '2008-01-01', to: '2016-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period && tsrange('2008-01-01', '2016-01-01')
    SQL
  end

  test "contained_by a range" do
    query = Player.filter(career_period: {contained_by: {from: '1999-01-01', to: '2011-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period <@ tsrange('1999-01-01', '2011-01-01')
    SQL
  end

  # A missing or nil bound is unbounded (SQL NULL).
  test "an omitted upper bound is unbounded" do
    query = Player.filter(career_period: {overlaps: {from: '2024-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period && tsrange('2024-01-01', NULL)
    SQL
  end

  test "an omitted lower bound is unbounded" do
    query = Player.filter(career_period: {overlaps: {to: '2024-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period && tsrange(NULL, '2024-01-01')
    SQL
  end

  # `bounds` sets the inclusivity string PostgreSQL takes as the third argument.
  test "explicit bounds are passed through" do
    query = Player.filter(career_period: {overlaps: {from: '2010-01-01', to: '2020-01-01', bounds: '[]'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period && tsrange('2010-01-01', '2020-01-01', '[]')
    SQL
  end

  # `from`/`to` have aliases so a range reads naturally in either vocabulary.
  test "lower/upper are accepted as bound aliases" do
    query = Player.filter(career_period: {overlaps: {lower: '2010-01-01', upper: '2020-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period && tsrange('2010-01-01', '2020-01-01')
    SQL
  end

  # A bare range Hash (no predicate key) is range equality.
  test "a bare range hash is an equality check" do
    query = Player.filter(career_period: {from: '2000-01-01', to: '2010-01-01'})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period = tsrange('2000-01-01', '2010-01-01')
    SQL
  end

  test "eq with a range hash is range equality" do
    query = Player.filter(career_period: {eq: {from: '2015-01-01', to: '2025-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period = tsrange('2015-01-01', '2025-01-01')
    SQL
  end

  # The range constructor and element cast track the column's own range type.
  test "a daterange column uses the daterange constructor and date cast" do
    query = Player.filter(season: {contains: '2026-06-15', eq: {from: '2026-01-01', to: '2026-12-31'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.season @> CAST('2026-06-15' AS date)
        AND players.season = daterange('2026-01-01', '2026-12-31')
    SQL
  end

  # Two range predicates on one column compose with AND.
  test "range predicates compose" do
    query = Player.filter(career_period: {contains: '2005-01-01', contained_by: {from: '1990-01-01', to: '2030-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period @> CAST('2005-01-01' AS timestamp)
        AND players.career_period <@ tsrange('1990-01-01', '2030-01-01')
    SQL
  end

end
