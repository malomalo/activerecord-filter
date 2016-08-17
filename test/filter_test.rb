require 'test_helper'

class FilterTest < ActiveSupport::TestCase

  test '::filter nil' do
    a = create(:property)

    assert_equal([a], Property.filter(nil))
  end

  test '::filter not existant filter' do
    class X; end

    assert_raises(ActiveRecord::UnkownFilterError) do
      Property.filter(unkown_column: X.new)
    end
  end

  # test '::filter not existant column' do
  #   assert_raises(ActiveRecord::UnkownFilterError) do
  #     Property.filter(unkown_column: 1)
  #   end
  # end

  test "::filter with lambda" do
    a1 = create(:property, :name => 'CA')
    a2 = create(:property, :name => 'NY')

    assert_equal [a2], Property.filter(:state => 'NY')
    assert_equal [a2], Property.filter(:state => 'ny')
  end
  
  test '::filter with an array' do
    a1 = create(:property)
    a2 = create(:property)
    a3 = create(:property)

    assert_equal [a2, a3], Property.filter([a2.id, a3.id.to_s])
  end

end
