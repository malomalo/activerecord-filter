require 'test_helper'

class FilterTest < ActiveSupport::TestCase

  test '::filter nil' do
    a = create(:property)

    assert_equal([a], Property.filter(nil))
  end

  test '::filter not existant filter' do
    class X; end

    assert_raises(ActiveRecord::UnkownFilterError) do
      Property.filter(id: X.new)
    end
  end

  test '::filter not existant column or filter' do
    assert_raises(ActiveRecord::UnkownFilterError) do
      Property.filter(unkown_column: 1)
    end
  end

  test "::filter with lambda" do
    a1 = create(:property, :name => 'CA')
    a2 = create(:property, :name => 'NY')

    assert_equal [a2], Property.filter(:state => 'NY')
    assert_equal [a2], Property.filter(:state => 'ny')
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
