require 'test_helper'

class HABTMTest < ActiveSupport::TestCase

  test '::filter :habtm => INT' do
    r1 = create(:region)
    r2 = create(:region)
    r3 = create(:region)
    p1 = create(:property)
    p2 = create(:property, :regions => [r1, r3])

    assert_equal [p2], Property.filter(:regions => r1.id)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), Property.filter(:regions => 1).to_sql.strip.gsub('"', ''))
      SELECT properties.* FROM properties
      INNER JOIN properties_regions ON properties_regions.property_id = properties.id
      INNER JOIN regions ON regions.id = properties_regions.region_id
      WHERE regions.id = 1
    SQL
  end

  test '::filter :habtm_with_with_self => INT' do
    r1 = create(:region)
    r2 = create(:region, :parents => [r1])
    r3 = create(:region, :parents => [r1, r2])

    assert_equal [r1].map(&:id), Region.filter(:children => r2.id).map(&:id)    
    query = Region.filter(:children => r1.id)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT regions.* FROM regions
      INNER JOIN regions_regions ON regions_regions.parent_id = regions.id
      INNER JOIN regions children_regions ON children_regions.id = regions_regions.child_id
      WHERE children_regions.id = #{r1.id}
    SQL

    assert_equal [r2, r3].map(&:id), Region.filter(:parents => r1.id).map(&:id)
    query = Region.filter(:parents => r1.id)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT regions.* FROM regions
      INNER JOIN regions_regions ON regions_regions.child_id = regions.id
      INNER JOIN regions parents_regions ON parents_regions.id = regions_regions.parent_id
      WHERE parents_regions.id = #{r1.id}
    SQL
  end

  test '::filter :habtm_with_with_self => [INT]' do
    r1 = create(:region)
    r2 = create(:region, :parents => [r1])
    r3 = create(:region, :parents => [r1, r2])

    assert_equal [r1].map(&:id), Region.filter(:children => {id: [r2.id]}).map(&:id)    
    query = Region.filter(:children => {id: [r1.id]})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT regions.* FROM regions
      INNER JOIN regions_regions ON regions_regions.parent_id = regions.id
      INNER JOIN regions children_regions ON children_regions.id = regions_regions.child_id
      WHERE children_regions.id IN (#{r1.id})
    SQL

    assert_equal [r2, r3].map(&:id), Region.filter(:parents => {id: [r1.id]}).map(&:id)
    query = Region.filter(:parents => {id: [r1.id]})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT regions.* FROM regions
      INNER JOIN regions_regions ON regions_regions.child_id = regions.id
      INNER JOIN regions parents_regions ON parents_regions.id = regions_regions.parent_id
      WHERE parents_regions.id IN (#{r1.id})
    SQL
  end

  test '::filter :habtm_with_with_self => FILTER' do
    r1 = create(:region)
    r2 = create(:region)
    r3 = create(:region)
    p1 = create(:property, :name => 'Property', :regions => [r2])
    p2 = create(:property, :regions => [r1, r3])

    assert_equal [r2].map(&:id),  Region.filter(:properties => {:name => 'Property'}).map(&:id)
    
        
    query = Region.filter(:properties => {:name => 'Property'})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT regions.* FROM regions
      INNER JOIN properties_regions ON properties_regions.region_id = regions.id
      INNER JOIN properties ON properties.id = properties_regions.property_id
      WHERE properties.name = 'Property'
    SQL
  end

end