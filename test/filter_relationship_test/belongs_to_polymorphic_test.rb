require 'test_helper'

class BelongsToPolymorphicFilterTest < ActiveSupport::TestCase

  test "::filter :belongs_to => {ID: VALUE}" do
    query = View.filter(subject: {type: "Property", regions: {id: 3362}})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT views.* FROM views
      INNER JOIN properties subject ON subject.id = views.subject_id AND views.subject_type = 'Property'
      INNER JOIN properties_regions subject-properties_regions ON subject-properties_regions.property_id = subject.id
      INNER JOIN regions subject-properties_regions-regions ON subject-properties_regions-regions.id = subject-properties_regions.region_id
      WHERE subject-properties_regions-regions.id = 3362
    SQL
  end
  
end
