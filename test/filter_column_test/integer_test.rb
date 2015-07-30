require 'test_helper'

class IntegerFilterTest < ActiveSupport::TestCase

  test "::filter :integer_column => {:gt => x}" do
    a1 = create(:property, constructed: 0)
    a2 = create(:property, constructed: 1)

    assert_equal [], Property.filter(constructed: { gt: 1 }).order(:id)
    assert_equal [a2], Property.filter(constructed: { gt: 0 }).order(:id)
    assert_equal [a1, a2], Property.filter(constructed: { gt: -1 }).order(:id)

    assert_equal [], Property.filter(constructed: { greater_than: 1 }).order(:id)
    assert_equal [a2], Property.filter(constructed: { greater_than: 0 }).order(:id)
    assert_equal [a1, a2], Property.filter(constructed: { greater_than: -1 }).order(:id)
  end

  test "::filter :integer_column => {:gteq => x}" do
    a1 = create(:property, constructed: 0)
    a2 = create(:property, constructed: 1)

    assert_equal [], Property.filter(constructed: { gte: 2 }).order(:id)
    assert_equal [a2], Property.filter(constructed: { gte: 1 }).order(:id)
    assert_equal [a1, a2], Property.filter(constructed: { gte: 0 }).order(:id)

    assert_equal [], Property.filter(constructed: { gteq: 2 }).order(:id)
    assert_equal [a2], Property.filter(constructed: { gteq: 1 }).order(:id)
    assert_equal [a1, a2], Property.filter(constructed: { gteq: 0 }).order(:id)

    assert_equal [], Property.filter(constructed: { greater_than_or_equal_to: 2 }).order(:id)
    assert_equal [a2], Property.filter(constructed: { greater_than_or_equal_to: 1 }).order(:id)
    assert_equal [a1, a2], Property.filter(constructed: { greater_than_or_equal_to: 0 }).order(:id)
  end

  test "::filter :integer_column => {:lt => x}" do
    a1 = create(:property, constructed: 0)
    a2 = create(:property, constructed: 1)

    assert_equal [], Property.filter(constructed: { lt: 0 }).order(:id)
    assert_equal [a1], Property.filter(constructed: { lt: 1 }).order(:id)
    assert_equal [a1, a2], Property.filter(constructed: { lt: 2 }).order(:id)

    assert_equal [], Property.filter(constructed: { less_than: 0 }).order(:id)
    assert_equal [a1], Property.filter(constructed: { less_than: 1 }).order(:id)
    assert_equal [a1, a2], Property.filter(constructed: { less_than: 2 }).order(:id)
  end

  test "::filter :integer_column => {:lteq => x}" do
    a1 = create(:property, constructed: 0)
    a2 = create(:property, constructed: 1)

    assert_equal [], Property.filter(constructed: { lte: -1 }).order(:id)
    assert_equal [a1], Property.filter(constructed: { lte: 0 }).order(:id)
    assert_equal [a1, a2], Property.filter(constructed: { lte: 1 }).order(:id)

    assert_equal [], Property.filter(constructed: { lteq: -1 }).order(:id)
    assert_equal [a1], Property.filter(constructed: { lteq: 0 }).order(:id)
    assert_equal [a1, a2], Property.filter(constructed: { lteq: 1 }).order(:id)

    assert_equal [], Property.filter(constructed: { less_than_or_equal_to: -1 }).order(:id)
    assert_equal [a1], Property.filter(constructed: { less_than_or_equal_to: 0 }).order(:id)
    assert_equal [a1, a2], Property.filter(constructed: { less_than_or_equal_to: 1 }).order(:id)
  end

  test "::filter :integer_column => int " do
    a1 = create(:property, constructed: 0)
    a2 = create(:property, constructed: 1)

    assert_equal [a2], Property.filter(constructed: 1)
  end

 test "::filter :integer_column => str" do
    a1 = create(:property, constructed: 0)
    a2 = create(:property, constructed: 1)

    assert_equal [a2], Property.filter(constructed: '1')
  end

  test "::filter :integer_column => bool " do
    a1 = create(:property, constructed: nil)
    a2 = create(:property, constructed: 1999)

    assert_equal [a2], Property.filter(constructed: true)
    assert_equal [a2], Property.filter(constructed: 'true')
    assert_equal [a1], Property.filter(constructed: false)
    assert_equal [a1], Property.filter(constructed: 'false')
  end

end
