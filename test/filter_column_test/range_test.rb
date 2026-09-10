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

  # A range operand becomes a Ruby Range, which ActiveRecord serializes to a
  # PostgreSQL range literal through the column's own OID::Range type.
  test "contains a range" do
    query = Player.filter(career_period: {contains: {from: '2001-01-01', to: '2009-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period @> '[2001-01-01 00:00:00,2009-01-01 00:00:00)'
    SQL
  end

  test "overlaps a range" do
    query = Player.filter(career_period: {overlaps: {from: '2008-01-01', to: '2016-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period && '[2008-01-01 00:00:00,2016-01-01 00:00:00)'
    SQL
  end

  test "contained_by a range" do
    query = Player.filter(career_period: {contained_by: {from: '1999-01-01', to: '2011-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period <@ '[1999-01-01 00:00:00,2011-01-01 00:00:00)'
    SQL
  end

  # A missing or nil bound is an unbounded end.
  test "an omitted upper bound is unbounded" do
    query = Player.filter(career_period: {overlaps: {from: '2024-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period && '[2024-01-01 00:00:00,infinity)'
    SQL
  end

  test "an omitted lower bound is unbounded" do
    query = Player.filter(career_period: {overlaps: {to: '2024-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period && '[,2024-01-01 00:00:00)'
    SQL
  end

  # `bounds` picks the upper bound's inclusivity. '[)' is the default, matching
  # PostgreSQL's own.
  test "explicit bounds are honoured" do
    query = Player.filter(career_period: {overlaps: {from: '2010-01-01', to: '2020-01-01', bounds: '[]'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period && '[2010-01-01 00:00:00,2020-01-01 00:00:00]'
    SQL
  end

  # `from`/`to` have aliases so a range reads naturally in either vocabulary.
  test "lower/upper are accepted as bound aliases" do
    query = Player.filter(career_period: {overlaps: {lower: '2010-01-01', upper: '2020-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period && '[2010-01-01 00:00:00,2020-01-01 00:00:00)'
    SQL
  end

  # A bare range Hash (no predicate key) is range equality.
  test "a bare range hash is an equality check" do
    query = Player.filter(career_period: {from: '2000-01-01', to: '2010-01-01'})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period = '[2000-01-01 00:00:00,2010-01-01 00:00:00)'
    SQL
  end

  test "eq with a range hash is range equality" do
    query = Player.filter(career_period: {eq: {from: '2015-01-01', to: '2025-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period = '[2015-01-01 00:00:00,2025-01-01 00:00:00)'
    SQL
  end

  # The serialized literal and the point cast both track the column's own type.
  test "a daterange column serializes dates and casts a date point" do
    query = Player.filter(season: {contains: '2026-06-15', eq: {from: '2026-01-01', to: '2026-12-31'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.season @> CAST('2026-06-15' AS date)
        AND players.season = '[2026-01-01,2026-12-31)'
    SQL
  end

  # Two range predicates on one column compose with AND.
  test "range predicates compose" do
    query = Player.filter(career_period: {contains: '2005-01-01', contained_by: {from: '1990-01-01', to: '2030-01-01'}})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period @> CAST('2005-01-01' AS timestamp)
        AND players.career_period <@ '[1990-01-01 00:00:00,2030-01-01 00:00:00)'
    SQL
  end

  # A Ruby Range can be passed straight through, since that is what the Hash
  # form builds anyway.
  test "a Ruby Range is accepted as a value" do
    query = Player.filter(career_period: {contains: Time.utc(2001, 1, 1)...Time.utc(2009, 1, 1)})
    assert_sql(<<-SQL, query)
      SELECT players.*
      FROM players
      WHERE players.career_period @> '[2001-01-01 00:00:00,2009-01-01 00:00:00)'
    SQL
  end

  # PostgreSQL's exclusive lower bounds have no Ruby Range equivalent, so they
  # are rejected rather than silently widened to an inclusive one.
  test "an exclusive lower bound is rejected" do
    ['()', '(]'].each do |bounds|
      error = assert_raises(ActiveRecord::UnkownFilterError) do
        Player.filter(career_period: {overlaps: {from: '2010-01-01', to: '2020-01-01', bounds: bounds}}).to_sql
      end
      assert_match(/exclusive lower bound/, error.message)
    end
  end

end
