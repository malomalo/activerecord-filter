require 'test_helper'

class BelongsToFilterTest < ActiveSupport::TestCase

  test "::filter :belongs_to => BOOL" do
    account = create(:account)
    p1 = create(:photo);
    p2 = create(:photo, :account => account);
    
    assert_equal [p2], Photo.filter(:account => true)
    assert_equal [p2], Photo.filter(:account => "true")
    
    assert_equal [p1], Photo.filter(:account => false)
    assert_equal [p1], Photo.filter(:account => "false")
  end

  test "::filter :belongs_to => NIL" do
    account = create(:account)
    p1 = create(:photo);
    p2 = create(:photo, :account => account);
    
    assert_equal [p1], Photo.filter(:account => nil)
  end
  
  test "::filter :belongs_to => INT" do
    account = create(:account)
    p1 = create(:photo);
    p2 = create(:photo, :account => account);
    
    assert_equal [p2], Photo.filter(:account => account.id)
    assert_equal [p2], Photo.filter(:account => account.id.to_s)
  end

  # test "::filter on model and belongs_to_association" do
  #   a1 = create(:property, photos_count: 1)
  #   a2 = create(:property, photos_count: 3)
  #   a3 = create(:property, photos_count: 1)
  #   a4 = create(:property, photos_count: 3)
  #   l1 = create(:listing, :property => a1)
  #   l2 = create(:listing, :property => a2)
  #   l3 = create(:listing, :property => a3, :authorized => false)
  #   l4 = create(:listing, :property => a4, :authorized => false)
  #
  #   assert_equal [l2], Listing.filter(:authorized => true, :property => { photos_count: { :gteq => 2 }})
  #   assert_equal [l1, l2], Listing.filter(:authorized => true, :property => { photos_count: { :gteq => 1 }}).order(:id)
  # end
  
  # test "::filter :belongs_to_association => { :boolean_column => boolean } " do
  #   a1 = create(:property, photos_count: 1)
  #   a2 = create(:property, photos_count: 0)
  #   l1 = create(:listing, :property => a1)
  #   l2 = create(:listing, :property => a2)
  #
  #   assert_equal [l1], Listing.filter(:property => { :photos => true })
  #   assert_equal [l2], Listing.filter(:property => { :photos => false })
  # end
  #
  # test "::filter belongs_to_association with lambda" do
  #   a1 = create(:property, addresses: [create(:address, location: 'POINT(0 0)')]).address
  #   a2 = create(:property, addresses: [create(:address, location: 'POINT(5 5)')]).address
  #   assert_equal [a1], Address.filter(:property => { :bounds => [1, 1, -1, -1] })
  # end


end
