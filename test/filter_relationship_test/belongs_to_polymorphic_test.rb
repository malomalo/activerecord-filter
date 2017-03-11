require 'test_helper'

class BelongsToPolymorphicFilterTest < ActiveSupport::TestCase

  test "::filter :belongs_to => BOOL" do
    TODO: join via arel: Listing.arel_table.join(Property.arel_table).on(Listing.arel_table[:property_id].eq(Property.arel_table[:id]))
    query = View.filter(subject: {as: "Property", regions: {id: 3362}})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT *
      FROM "views"
      LEFT OUTER JOIN "localities" ON "localities"."property_id" = "properties"."id"
      LEFT OUTER JOIN "regions" ON "regions"."id" = "localities"."region_id"
      INNER JOIN "properties" ON "properties"."id" = "views"."subject_id" AND "views"."subject_type" = 'Property'
      WHERE "regions"."id" = 3362
    SQL
  end

end
