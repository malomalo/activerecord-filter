require 'test_helper'

class StringFilterTest < ActiveSupport::TestCase

  test "::filter :string_column => string" do
    l1 = create(:property, name: nil)
    l2 = create(:property, name: 'b')

    assert_equal [l2], Property.filter(name: 'b')
  end

  test "::filter :string_column => nil" do
    l1 = create(:property, name: nil)
    l2 = create(:property, name: 'b')

    assert_equal [l1], Property.filter(name: nil)
  end
  
  test "::filter :string_column => boolean" do
    l1 = create(:property, name: nil)
    l2 = create(:property, name: 'b')

    assert_equal [l1], Property.filter(name: false)
    assert_equal [l2], Property.filter(name: true)
  end
  
  test "::filter :string_column => {:not => STRING}" do
    l1 = create(:property, name: 'a')
    l2 = create(:property, name: 'b')

    assert_equal [l1], Property.filter(name: {not: 'b'})
  end
  
  test "::filter :array_column => {:not_in => [STRING, STRING]}" do
    a1 = create(:property, :name => 'a')
    
    assert_equal [a1], Property.filter(:name => {:not_in => ['b', 'c']})
    
    query = Property.filter(:name => {:not_in => ['b', 'c']})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE (properties.name NOT IN ('b', 'c') OR properties.name IS NULL)
    SQL
  end

end