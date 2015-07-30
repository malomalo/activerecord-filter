require 'test_helper'

class ArrayColumnFilterTest < ActiveSupport::TestCase

  test "::filter :array_column => str" do
    a1 = create(:property, :aliases => ['Skyscraper 1'])
    a2 = create(:property, :aliases => ['Skyscraper 1', 'Skyscraper 2'])
    a3 = create(:property, :aliases => ['Skyscraper'])

    assert_equal [a1, a2], Property.filter(:aliases => 'Skyscraper 1')
    assert_equal [a1, a2], Property.filter(:aliases => ['Skyscraper 1', 'Skyscraper 2'])
  end
    
end