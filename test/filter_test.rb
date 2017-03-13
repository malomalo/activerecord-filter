require 'test_helper'

class FilterTest < ActiveSupport::TestCase

  schema do
    create_table "properties" do |t|
      t.string   "name",                    limit: 255
      t.string   "state",                    limit: 255
    end
  end
  
  class Property < ActiveRecord::Base
  end
  
  class IAmNotAFilter
  end

  test '::filter nil' do
    query = Property.filter(nil)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
    SQL
  end

  test '::filter not existant filter' do
    assert_raises(ActiveRecord::UnkownFilterError) do
      Property.filter(id: IAmNotAFilter.new)
    end
  end

  test '::filter not existant column or filter' do
    assert_raises(ActiveRecord::UnkownFilterError) do
      Property.filter(unkown_column: 1)
    end
  end

  test "::filter with lambda" do
    query = Property.filter(state: 'NY')
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.state = 'NY'
    SQL
  end

  test '::filter(OR CONDITION)' do
    query = Property.filter([{id: 10}, 'OR', {name: 'name'}])
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE ((properties.id = 10) OR (properties.name = 'name'))
    SQL
  end

  test '::where(AND & OR CONDITION)' do
    query = Property.filter([{id: 10}, 'AND', [{id: 10}, 'OR', {name: 'name'}]])
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.id = 10 AND ((properties.id = 10) OR (properties.name = 'name')))
    SQL
  end

end
