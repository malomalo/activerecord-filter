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
    end
  end

  class View < ActiveRecord::Base
    belongs_to :subject, polymorphic: true
    belongs_to :account
  end

  class Account < ActiveRecord::Base
  end

  class Property < ActiveRecord::Base
    belongs_to :account
  end

  test "::filter :belongs_to => {ID: VALUE}" do
    query = View.filter(subject: {as: "BelongsToPolymorphicFilterTest::Property", name: 'Name'})
    assert_sql(<<-SQL, query)
      SELECT views.*
      FROM views
      LEFT OUTER JOIN properties properties_as_subject
        ON properties_as_subject.id = views.subject_id AND views.subject_type = 'BelongsToPolymorphicFilterTest::Property'
      WHERE properties_as_subject.name = 'Name'
    SQL
  end

  test '::filter with seperate joins' do
    query = View.filter(subject: {as: "BelongsToPolymorphicFilterTest::Property", name: 'Name'}, account: {name: 'Account'})
    assert_sql(<<-SQL, query)
      SELECT views.* FROM views
      LEFT OUTER JOIN accounts
        ON accounts.id = views.account_id
      LEFT OUTER JOIN properties properties_as_subject
        ON properties_as_subject.id = views.subject_id AND views.subject_type = 'BelongsToPolymorphicFilterTest::Property'
      WHERE properties_as_subject.name = 'Name' AND accounts.name = 'Account'
    SQL
  end
  
  test '::filter beyond polymorphic boundary' do
    query = View.filter(subject: {as: "BelongsToPolymorphicFilterTest::Property", account: {name: 'Name'}})
    assert_sql(<<-SQL, query)
      SELECT views.* FROM views
      LEFT OUTER JOIN properties properties_as_subject
        ON properties_as_subject.id = views.subject_id AND views.subject_type = 'BelongsToPolymorphicFilterTest::Property'
      LEFT OUTER JOIN accounts
        ON accounts.id = properties_as_subject.account_id
      WHERE accounts.name = 'Name'
    SQL
  end

end
