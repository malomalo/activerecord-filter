require 'test_helper'

class HasManyFilterTest < ActiveSupport::TestCase

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
    create_table "properties" do |t|
      t.string   "name",                    limit: 255
      t.string   "state",                    limit: 255
    end
  end

  class Account < ActiveRecord::Base
    has_many :photos
  end

  class Photo < ActiveRecord::Base
    belongs_to :account, counter_cache: true
    belongs_to :property
    filter_on :no_properties_where_state_is_null, "LEFT OUTER JOIN \"properties\" ON \"properties\".\"id\" = \"photos\".\"property_id\" AND \"properties\".\"state\" IS NULL" do |klass, table, key, value, join_dependency|
      Property.arel_table['id'].eq(nil)
    end
  end

  class Property < ActiveRecord::Base
    has_many :photos
  end

  test "::filter has_many: BOOL (with counter_cache)" do
    query = Account.filter(photos: true)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      WHERE accounts.photos_count > 0
    SQL

    query = Account.filter(photos: "true")
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      WHERE accounts.photos_count > 0
    SQL


    query = Account.filter(photos: false)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      WHERE accounts.photos_count = 0
    SQL

    query = Account.filter(photos: "false")
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      WHERE accounts.photos_count = 0
    SQL
  end

  test "::filter has_many: FILTER" do
    query = Account.filter(photos: {format: 'jpg'})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      INNER JOIN photos ON photos.account_id = accounts.id
      WHERE photos.format = 'jpg'
    SQL
  end

  test "::filter nested relationships" do
    query = Account.filter(photos: {property: {name: 'Name'}})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      INNER JOIN photos ON photos.account_id = accounts.id
      INNER JOIN properties ON properties.id = photos.property_id
      WHERE properties.name = 'Name'
    SQL

    query = Account.filter(photos: [ { property: { name: 'Name' } } ])
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      INNER JOIN photos ON photos.account_id = accounts.id
      INNER JOIN properties ON properties.id = photos.property_id
      WHERE properties.name = 'Name'
    SQL

    query = Account.filter(photos: [ { property: { name: 'Name' } }, { account: { name: 'Person' } } ])
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      INNER JOIN photos ON photos.account_id = accounts.id
      INNER JOIN properties ON properties.id = photos.property_id
      INNER JOIN accounts accounts_photos ON accounts_photos.id = photos.account_id
      WHERE properties.name = 'Name'
        AND accounts_photos.name = 'Person'
    SQL
  end

  test "::filter has_many: INT" do
    query = Account.filter(photos: 1)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      INNER JOIN photos ON photos.account_id = accounts.id
      WHERE photos.id = 1
    SQL
  end

  test "::filter has_many_ids: INT" do
    query = Account.filter(photo_ids: 1)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      INNER JOIN photos ON photos.account_id = accounts.id
      WHERE photos.id = 1
    SQL
  end

  test "::filter has_many_ids: [INT]" do
    query = Account.filter(photo_ids: [1, 2])
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      INNER JOIN photos ON photos.account_id = accounts.id
      WHERE photos.id IN (1, 2)
    SQL
  end

  test "::filter filter_on" do
    query = Photo.filter(no_properties_where_state_is_null: true)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT photos.* FROM photos
      LEFT OUTER JOIN properties ON properties.id = photos.property_id AND properties.state IS NULL
      WHERE properties.id IS NULL
    SQL
  end

  test "::filter has_many filter_on" do
    query = Account.filter(photos: {no_properties_where_state_is_null: true})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      INNER JOIN photos ON photos.account_id = accounts.id
      LEFT OUTER JOIN properties ON properties.id = photos.property_id AND properties.state IS NULL
      WHERE properties.id IS NULL
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
