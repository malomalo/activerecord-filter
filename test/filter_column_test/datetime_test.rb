require 'test_helper'

class DatetimeFilterTest < ActiveSupport::TestCase

  test "::filter :datetime_column => {:gt => date, :lt => date}" do
    l1, l2, l3 = nil, nil, nil
    travel_to(Date.today - 3.days) { l1 = create(:property) }
    travel_to(Date.today - 2.days) { l2 = create(:property) }
    travel_to(Date.today) { l3 = create(:property) }

    assert_equal [l1, l2], Property.filter(:created_at => {:gte => Date.today - 4.days, :lte => Date.today - 1.days}).order(:id)
    assert_equal [], Property.filter(:created_at => {:gte => Date.today - 5.days, :lte => Date.today - 4.days})
    assert_equal [l3], Property.filter(:created_at => {:gte => Date.today - 1.days, :lte => Date.today + 1.days})
  end

  test "::filter :datetime_column => date" do
    l1 = create(:property)
    assert_equal [l1], Property.filter(:created_at => [l1.created_at])
  end

end
