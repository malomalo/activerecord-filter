require 'test_helper'

class ArrayColumnFilterTest < ActiveSupport::TestCase

  test "::filter :array_column => str" do
    a1 = create(:property, :aliases => ['Skyscraper 1'])

    assert_equal [a1], Property.filter(:aliases => 'Skyscraper 1')
    assert_equal [a1], Property.filter(:aliases => ['Skyscraper 1'])
  end
    
end