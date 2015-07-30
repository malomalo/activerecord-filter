require 'test_helper'

class BooleanFilterTest < ActiveSupport::TestCase

  test "::filter :boolean_column => boolean " do
    l1 = create(:property, active: true)
    l2 = create(:property, active: false)

    assert_equal [l1], Property.filter(active: true)
    assert_equal [l2], Property.filter(active: false)
  end

  test "::filter :boolean_column => str " do
    l1 = create(:property, active: true)
    l2 = create(:property, active: false)

    assert_equal [l1], Property.filter(active: 'true')
    assert_equal [l2], Property.filter(active: 'false')
  end

  test "::filter :boolean_column => nil " do
    l1 = create(:property, active: true)
    l2 = create(:property, active: nil)

    assert_equal [l2], Property.filter(active: nil)
  end

end
