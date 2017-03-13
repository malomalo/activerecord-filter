require 'test_helper'

class BelongsToPolymorphicFilterTest < ActiveSupport::TestCase

  schema do
    create_table "views", force: :cascade do |t|
      t.string  "subject_type"
      t.integer "subject_id"
    end
    
    create_table "properties" do |t|
      t.string   "name",                    limit: 255
    end

  end
  
  class View < ActiveRecord::Base
    belongs_to :subject, polymorphic: true
  end
    
  class Property < ActiveRecord::Base
  end

  test "::filter :belongs_to => {ID: VALUE}" do
    query = View.filter(subject: {type: "Property", name: 'Name'})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT views.* FROM views
      INNER JOIN properties subject ON subject.id = views.subject_id AND views.subject_type = 'BelongsToPolymorphicFilterTest::Property'
      WHERE subject.name = 'Name'
    SQL
  end
  
end
