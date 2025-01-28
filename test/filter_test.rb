require 'test_helper'
require 'action_controller/metal/strong_parameters'

class FilterTest < ActiveSupport::TestCase

  schema do
    create_table "properties" do |t|
      t.string   "name",                    limit: 255
      t.string   "state",                    limit: 255

      t.integer  'score'
      t.datetime 'touched_at'
    end

    create_table "photos", force: :cascade do |t|
      t.integer  "property_id"
    end
  end
  
  class Property < ActiveRecord::Base
    has_many :photos
  end

  class Photo < ActiveRecord::Base
    belongs_to :property
  end

  
  test '::filter nil' do
    query = Property.filter(nil)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
    SQL
  end

  test '::filter not existant column or filter' do
    assert_raises(ActiveRecord::UnkownFilterError) do
      Property.filter(unkown_column: 1).load
    end
  end

  test "::filter with lambda" do
    query = Property.filter(state: 'NY')
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.state = 'NY'
    SQL
  end


  test "::filter with nested ActionController::Parameters" do
    query = Property.filter(ActionController::Parameters.new(where: [{id: {lt: 2}}, 'OR', [{id: {gt: 3}}, 'AND', {state: 'VT'}]])[:where])
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE ((properties.id < 2) OR (properties.id > 3 AND properties.state = 'VT'))
    SQL
  end

  test '::filter(OR CONDITION)' do
    query = Property.filter([{id: 10}, 'OR', {name: 'name'}])
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE ((properties.id = 10) OR (properties.name = 'name'))
    SQL
  end

  test '::filter(AND & OR CONDITION)' do
    query = Property.filter([{id: 10}, 'AND', [{id: 10}, 'OR', {name: 'name'}]])
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT properties.*
      FROM properties
      WHERE properties.id = 10 AND ((properties.id = 10) OR (properties.name = 'name'))
    SQL
  end
  
  test '::where with eager_load' do
    query = Property.eager_load(:photos).filter(id: 2)
    
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT
        properties.id AS t0_r0,
        properties.name AS t0_r1,
        properties.state AS t0_r2,
        properties.score AS t0_r3,
        properties.touched_at AS t0_r4,
        photos.id AS t1_r0,
        photos.property_id AS t1_r1
      FROM properties
      LEFT OUTER JOIN photos ON photos.property_id = properties.id
      WHERE properties.id = 2
    SQL
  end
  
  test '::filter on relationship' do
    queries = [
      Property.filter("photos" => { "id" => [ 1, 2 ] }),
      Property.filter(photos: { id: [ 1, 2 ]})
    ].map { |q| q.to_sql.strip.gsub('"', '') }

    queries.each do |query|
      assert_equal <<~SQL.strip, query
        SELECT properties.* FROM properties LEFT OUTER JOIN photos ON photos.property_id = properties.id WHERE photos.id IN (1, 2)
      SQL
    end
  end

end
