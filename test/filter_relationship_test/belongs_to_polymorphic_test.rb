require 'test_helper'

class BelongsToPolymorphicFilterTest < ActiveSupport::TestCase

  schema do
    create_table "views", force: :cascade do |t|
      t.string  "subject_type"
      t.integer "subject_id"
      t.integer  "account_id"
    end

    create_table "accounts" do |t|
      t.string   "name",                    limit: 255
    end
    
    create_table "properties" do |t|
      t.string   "name",                    limit: 255
      t.integer  "account_id"
      t.integer  "region_id"
      t.string   "region_type"
    end
    
    create_table "countries" do |t|
      t.string  "name",                    limit: 255
    end
  end

  class View < ActiveRecord::Base
    belongs_to :subject, polymorphic: true
    belongs_to :account
  end

  class Account < ActiveRecord::Base
    belongs_to :friend, class_name: 'BelongsToPolymorphicFilterTest::Account'
    belongs_to :other_friend, class_name: 'BelongsToPolymorphicFilterTest::Account'
  end

  class Property < ActiveRecord::Base
    belongs_to :account
    belongs_to :region, polymorphic: true
  end
  
  class Country < ActiveRecord::Base
    has_many :properties
  end

  test "::filter :belongs_to => {ID: VALUE}" do
    query = View.filter(subject: {as: "BelongsToPolymorphicFilterTest::Property", name: 'Name'})
    assert_sql(<<-SQL, query)
      SELECT views.*
      FROM views
      LEFT OUTER JOIN properties
        ON properties.id = views.subject_id AND views.subject_type = 'BelongsToPolymorphicFilterTest::Property'
      WHERE properties.name = 'Name'
    SQL
  end

  test '::filter with seperate joins' do
    query = View.filter(subject: {as: "BelongsToPolymorphicFilterTest::Property", name: 'Name'}, account: {name: 'Account'})
    assert_sql(<<-SQL, query)
      SELECT views.* FROM views
      LEFT OUTER JOIN accounts
        ON accounts.id = views.account_id
      LEFT OUTER JOIN properties
        ON properties.id = views.subject_id AND views.subject_type = 'BelongsToPolymorphicFilterTest::Property'
      WHERE properties.name = 'Name' AND accounts.name = 'Account'
    SQL
  end

  test '::filter beyond polymorphic boundary' do
    query = View.filter({
      subject: {
        as: "BelongsToPolymorphicFilterTest::Property",
        account: {name: 'Name'}
      }
    })

    assert_sql(<<-SQL, query)
      SELECT views.* FROM views
      LEFT OUTER JOIN properties
        ON properties.id = views.subject_id
        AND views.subject_type = 'BelongsToPolymorphicFilterTest::Property'
      LEFT OUTER JOIN accounts
        ON accounts.id = properties.account_id
      WHERE accounts.name = 'Name'
    SQL
  end
  
  test '::filter nested polymorphic' do
    query = View.filter({
      subject: {
        as: "BelongsToPolymorphicFilterTest::Property",
        region: {
          as: 'BelongsToPolymorphicFilterTest::Country',
          name: 'USA'
        }
      }
    })

    assert_sql(<<-SQL, query)
      SELECT views.* FROM views
      LEFT OUTER JOIN properties
        ON properties.id = views.subject_id
      LEFT OUTER JOIN countries
        ON countries.id = properties.region_id
        AND properties.subject_type = 'BelongsToPolymorphicFilterTest::Country'
      WHERE properties.name = 'USA'
    SQL
  end

  test '::filter beyond polymorphic boundary with the same table twice' do
    query = View.filter({
      subject: {
        as: "BelongsToPolymorphicFilterTest::Account",
        friend: {name: 'Name'},
        other_friend: {name: 'Name2'}
      }
    })

    assert_sql(<<-SQL, query)
      SELECT views.* FROM views
      LEFT OUTER JOIN accounts
        ON accounts.id = views.subject_id
        AND views.subject_type = 'BelongsToPolymorphicFilterTest::Account'
      LEFT OUTER JOIN accounts friends_accounts
        ON friends_accounts.id = accounts.friend_id
      LEFT OUTER JOIN accounts other_friends_accounts
        ON other_friends_accounts.id = accounts.other_friend_id
      WHERE
        friends_accounts.name = 'Name'
        AND other_friends_accounts.name = 'Name2'
      SQL
  end
end
