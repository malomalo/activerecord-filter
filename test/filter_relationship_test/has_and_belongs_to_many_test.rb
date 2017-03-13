require 'test_helper'

class HABTMTest < ActiveSupport::TestCase

  schema do
    create_table "properties", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end

    create_table "regions", force: :cascade do |t|
    end
    
    create_table "properties_regions", id: false, force: :cascade do |t|
      t.integer "property_id", null: false
      t.integer "region_id",  null: false
    end
    
    create_table "regions_regions", id: false, force: :cascade do |t|
      t.integer "parent_id", null: false
      t.integer "child_id",  null: false
    end
  end

  class Property < ActiveRecord::Base
    has_and_belongs_to_many :regions
  end

  class Region < ActiveRecord::Base
    has_and_belongs_to_many :properties
    has_and_belongs_to_many :parents, :join_table => 'regions_regions', :class_name => 'Region', :foreign_key => 'child_id', :association_foreign_key => 'parent_id'
    has_and_belongs_to_many :children, :join_table => 'regions_regions', :class_name => 'Region', :foreign_key => 'parent_id', :association_foreign_key => 'child_id'
  end
  
  # test '::filter :habtm => INT' do
  #   r1 = create(:region)
  #   r2 = create(:region)
  #   r3 = create(:region)
  #   p1 = create(:property)
  #   p2 = create(:property, :regions => [r1, r3])
  #
  #   assert_equal [p2], Property.filter(:regions => r1.id)
  #   assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), Property.filter(:regions => 1).to_sql.strip.gsub('"', ''))
  #     SELECT properties.* FROM properties
  #     INNER JOIN properties_regions ON properties_regions.property_id = properties.id
  #     WHERE properties_regions.region_id = 1
  #   SQL
  # end

  # test '::filter :habtm_with_with_self => INT' do
  #   r1 = create(:region)
  #   r2 = create(:region, :parents => [r1])
  #   r3 = create(:region, :parents => [r1, r2])
  #
  #   assert_equal [r1].map(&:id), Region.filter(:children => r2.id).map(&:id)
  #   query = Region.filter(:children => r1.id)
  #   assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
  #     SELECT regions.* FROM regions
  #     INNER JOIN regions_regions regions_children ON regions_children.parent_id = regions.id
  #     WHERE regions_children.child_id = #{r1.id}
  #   SQL
  #
  #   assert_equal [r2, r3].map(&:id), Region.filter(:parents => r1.id).map(&:id)
  #   query = Region.filter(:parents => r1.id)
  #   assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
  #     SELECT regions.* FROM regions
  #     INNER JOIN regions_regions regions_parents ON regions_parents.child_id = regions.id
  #     WHERE regions_parents.parent_id = #{r1.id}
  #   SQL
  # end

  test '::filter :habtm_with_with_self => FILTER' do
    query = Region.filter(properties: {name: 'Property'})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT regions.* FROM regions
      INNER JOIN properties_regions habtmtest_regions_properties ON habtmtest_regions_properties.region_id = regions.id
      INNER JOIN properties habtmtest_regions_properties-properties ON habtmtest_regions_properties-properties.id = habtmtest_regions_properties.property_id
      WHERE habtmtest_regions_properties-properties.name = 'Property'
    SQL
  end

end