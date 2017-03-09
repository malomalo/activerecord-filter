require 'test_helper'

class HasManyFilterTest < ActiveSupport::TestCase
  
  test "::filter :has_many => BOOL (with counter_cache)" do
    a1 = create(:account)
    a2 = create(:account); 1.times { create(:photo, :account => a2) }
    a3 = create(:account); 3.times { create(:photo, :account => a3) }

    assert_equal [a2, a3].map(&:id).sort, Account.filter(:photos => true).map(&:id).sort
    assert_equal [a2, a3].map(&:id).sort, Account.filter(:photos => 'true').map(&:id).sort
  
    assert_equal [a1].map(&:id).sort, Account.filter(:photos => false).map(&:id).sort
    assert_equal [a1].map(&:id).sort, Account.filter(:photos => 'false').map(&:id).sort
  end
  
  test "::filter nested relationships" do
    account = create(:account)
    photo = create(:photo)
    property = create(:property)
    
    query = Account.filter(photos: {properties: {id: property.id}})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      INNER JOIN photos ON photos.account_id = accounts.id
      INNER JOIN photos_properties ON photos_properties.photo_id = photos.id
      INNER JOIN properties ON properties.id = photos_properties.property_id
      WHERE properties.id = #{property.id}
    SQL
  end
  
  # test "::filter :has_many with lambda" do
  #   a1 = create(:property)
  #   a2 = create(:property)
  #   create(:lease, :property => a1)
  #   create(:sublease, :property => a2)
  #
  #   assert_equal [a1], Property.filter(:listings => { :type => 'lease'} )
  #   assert_equal [a2], Property.filter(:listings => { :type => 'sublease'} )
  # end

end