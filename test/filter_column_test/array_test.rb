require 'test_helper'

class ArrayColumnFilterTest < ActiveSupport::TestCase

  test "::filter :array_column => STRING" do
    a1 = create(:property, :aliases => ['Skyscraper 1'])
    a2 = create(:property, :aliases => ['Skyscraper 1', 'Skyscraper 2'])
    a3 = create(:property, :aliases => ['Skyscraper'])

    assert_equal [a1, a2], Property.filter(:aliases => 'Skyscraper 1')
  end
  
  test "::filter :array_column => [STRING, STRING]" do
    a1 = create(:property, :aliases => ['Skyscraper 1'])
    a2 = create(:property, :aliases => ['Skyscraper 1', 'Skyscraper 2'])
    a3 = create(:property, :aliases => ['Skyscraper'])

    assert_equal [a2], Property.filter(:aliases => ['Skyscraper 1', 'Skyscraper 2'])
  end

  test "::filter :array_column => {contains: [STRING, STRING]}" do
    a1 = create(:property, :aliases => ['Skyscraper 1'])
    a2 = create(:property, :aliases => ['Skyscraper 1', 'Skyscraper 2'])
    a3 = create(:property, :aliases => ['Skyscraper'])

    assert_equal [a1, a2], Property.filter(:aliases => {contains: ['Skyscraper 1']})
  end
  
  test "::filter :array_column => {overlaps: [STRING, STRING]}" do
    a1 = create(:property, :aliases => ['Skyscraper 1'])
    a2 = create(:property, :aliases => ['Skyscraper 1', 'Skyscraper 2'])
    a3 = create(:property, :aliases => ['Skyscraper'])

    assert_equal [a2, a3], Property.filter(:aliases => {overlaps: ['Skyscraper 2', 'Skyscraper']})
  end
    
end