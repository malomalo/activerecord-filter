require 'test_helper'

class BelongsToFilterTest < ActiveSupport::TestCase

  schema do
    create_table "accounts", force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.integer  'photos_count', null: false, default: 0
    end
    
    create_table "photos", force: :cascade do |t|
      t.integer  "account_id"
      t.integer  "property_id"
      t.string   "format",                 limit: 255
    end
  end

  class Account < ActiveRecord::Base
    has_many :photos
  end

  class Photo < ActiveRecord::Base
    belongs_to :account, counter_cache: true
  end

  test "::filter :belongs_to => BOOL" do
    query = Photo.filter(account: true)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT photos.*
      FROM photos
      WHERE photos.account_id IS NOT NULL
    SQL

    query = Photo.filter(account: "true")
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT photos.*
      FROM photos
      WHERE photos.account_id IS NOT NULL
    SQL

    query = Photo.filter(account: false)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT photos.*
      FROM photos
      WHERE photos.account_id IS NULL
    SQL

    query = Photo.filter(account: "false")
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT photos.*
      FROM photos
      WHERE photos.account_id IS NULL
    SQL
  end

  test "::filter :belongs_to => NIL" do
    query = Photo.filter(account: nil)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT photos.*
      FROM photos
      WHERE photos.account_id IS NULL
    SQL
  end

  test "::filter :belongs_to => FILTER" do
    query = Photo.filter(account: {name: 'Minx'})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT photos.*
      FROM photos
      LEFT OUTER JOIN accounts ON accounts.id = photos.account_id
      WHERE accounts.name = 'Minx'
    SQL
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
