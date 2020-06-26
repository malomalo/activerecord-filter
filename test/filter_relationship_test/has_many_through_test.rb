require 'test_helper'

class HasManyThroughFilterTest < ActiveSupport::TestCase

  schema do
    create_table "accounts", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end
    
    create_table "localities", force: :cascade do |t|
      t.string   "record_type"
      t.integer  "record_id"
      t.integer  "region_id"
    end
    
    create_table "regions" do |t|
      t.string   "name",                    limit: 255
    end
  end

  class Account < ActiveRecord::Base
    has_many :localities, as: :record
    has_many :regions, through: :localities
  end

  class Locality < ActiveRecord::Base
    belongs_to :subject, polymorphic: true
    belongs_to :region
  end

  class Region < ActiveRecord::Base
    has_many :localities
  end

  # TODO: Optimize this test to use the foreign_key instead of doing the extra join when where is only on id
  test "::filter has_many_through_polymorhic_ids: id" do
    query = Account.filter(region_ids: 10)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      LEFT OUTER JOIN localities ON
        localities.record_type = 'HasManyThroughFilterTest::Account'
        AND localities.record_id = accounts.id
      LEFT OUTER JOIN regions ON
        regions.id = localities.region_id
      WHERE regions.id = 10
    SQL
  end

end