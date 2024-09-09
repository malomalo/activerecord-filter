require 'test_helper'

class GeometryColumnFilterTest < ActiveSupport::TestCase

  schema do
    enable_extension 'postgis'
    create_table "properties", force: :cascade do |t|
      t.geometry "geo"
    end
  end

  class Property < ActiveRecord::Base
    has_many :regions
  end

  test "::filter :geometry_column => EWKT" do
    query = Property.filter(geo: 'POINT (28.182869232095754 11.073276002261096)')
    assert_sql(<<-SQL, query)
      SELECT properties.*
      FROM properties
      WHERE properties.geo = ST_SetSRID(ST_GeomFromText('POINT (28.182869232095754 11.073276002261096)'), 4326)
    SQL
  end

  test "::filter :geometry_column => unencoded EWKB" do
    query = Property.filter(geo: "\x01\x01\x00\x00\x00\xC0K\x9B\x84\xD0.<@\b\x96\xA2n\x84%&@")
    assert_sql(<<-SQL, query)
      SELECT properties.*
      FROM properties
      WHERE properties.geo = ST_SetSRID(ST_GeomFromEWKB('\\x0101000000c04b9b84d02e3c400896a26e84252640'), 4326)
    SQL
  end

  test "::filter :geometry_column => hex encoded EWKB" do
    query = Property.filter(geo: "0101000000c04b9b84d02e3c400896a26e84252640")
    assert_sql(<<-SQL, query)
      SELECT properties.*
      FROM properties
      WHERE properties.geo = ST_SetSRID(ST_GeomFromEWKB('\\x0101000000c04b9b84d02e3c400896a26e84252640'), 4326)
    SQL
  end

  test "::filter :geometry_column => {equals: geoJSON}" do
    query = Property.filter(geo: {eq: {"type":"Point","coordinates":[28.182869232095754,11.073276002261096]}})
    assert_sql(<<-SQL, query)
      SELECT properties.*
      FROM properties
      WHERE ST_Equals(properties.geo, ST_SetSRID(ST_GeomFromGeoJSON('{type:Point,coordinates:[28.182869232095754,11.073276002261096]}'), 4326))
    SQL
  end

  test "::filter :geometry_column => [EWKT, EWKB, hex EWKB, geoJSON]" do
    query = Property.filter(geo: [
      'POINT (28.182869232095754 11.073276002261096)',
      "\x01\x01\x00\x00\x00\xC0K\x9B\x84\xD0.<@\b\x96\xA2n\x84%&@",
      "0101000000c04b9b84d02e3c400896a26e84252640",
      {"type":"Point","coordinates":[28.182869232095754,11.073276002261096]}
    ])
    assert_sql(<<-SQL, query)
      SELECT properties.*
      FROM properties
      WHERE properties.geo IN (
        ST_SetSRID(ST_GeomFromText('POINT (28.182869232095754 11.073276002261096)'), 4326),
        ST_SetSRID(ST_GeomFromEWKB('\\x0101000000c04b9b84d02e3c400896a26e84252640'), 4326),
        ST_SetSRID(ST_GeomFromEWKB('\\x0101000000c04b9b84d02e3c400896a26e84252640'), 4326),
        ST_SetSRID(ST_GeomFromGeoJSON('{"type":"Point","coordinates":[28.182869232095754,11.073276002261096]}'), 4326)
      )
    SQL
  end

  test "::filter geometry_column: {contians: EWKT}" do
    query = Property.filter(geo: {contains: 'POINT (28.182869232095754 11.073276002261096)'})
    assert_sql(<<-SQL, query)
      SELECT properties.*
      FROM properties
      WHERE ST_Contains(properties.geo, ST_SetSRID(ST_GeomFromText('POINT (28.182869232095754 11.073276002261096)'), 4326))
    SQL
  end

  test "::filter geometry_column: {within: EWKT}" do
    query = Property.filter(geo: {within: 'POINT (28.182869232095754 11.073276002261096)'})
    assert_sql(<<-SQL, query)
      SELECT properties.*
      FROM properties
      WHERE ST_Within(properties.geo, ST_SetSRID(ST_GeomFromText('POINT (28.182869232095754 11.073276002261096)'), 4326))
    SQL
  end

  test "::filter geometry_column: { overlaps: EWKT }" do
    query = Property.filter(geo: { overlaps: 'POINT (28.182869232095754 11.073276002261096)' })
    assert_sql(<<-SQL, query)
      SELECT properties.*
      FROM properties
      WHERE properties.geo && ST_SetSRID(ST_GeomFromText('POINT (28.182869232095754 11.073276002261096)'), 4326)
    SQL
  end

end
