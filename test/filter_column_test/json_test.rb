require 'test_helper'

class JsonFilterTest < ActiveSupport::TestCase

  schema do
    create_table "properties", force: :cascade do |t|
      t.jsonb     'metadata'
    end
  end

  class Property < ActiveRecord::Base
  end

  test "::filter json_column: STRING throws an error" do
    assert_raises(ActiveRecord::UnkownFilterError) do
      Property.filter(metadata: 'string').load
    end
  end
  
  test "::filter json_column: {eq: JSON_HASH}" do
    query = Property.filter(metadata: {eq: {json: 'string'}})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip)
      SELECT "properties".*
      FROM "properties"
      WHERE "properties"."metadata" = '{\"json\":\"string\"}'
    SQL
  end
  
  test "::filter json_column: {contains: JSON_HASH}" do
    query = Property.filter(metadata: {contains: {json: 'string'}})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip)
      SELECT "properties".*
      FROM "properties"
      WHERE ("properties"."metadata" @> '{\"json\":\"string\"}')
    SQL
  end

  test "::filter json_column: {contained_by: JSON_HASH}" do
    query = Property.filter(metadata: {contained_by: {json: 'string'}})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip)
      SELECT "properties".*
      FROM "properties"
      WHERE ("properties"."metadata" <@ '{\"json\":\"string\"}')
    SQL
  end
  
  test "::filter json_column: {has_key: STRING}" do
    query = Property.filter(metadata: {has_key: 'string'})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip)
      SELECT "properties".*
      FROM "properties"
      WHERE ("properties"."metadata" ? 'string')
    SQL
  end
  
  test "::filter json_column.subkey: {eq: JSON_HASH}" do
    query = Property.filter("metadata.subkey" => {eq: 'string'})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip)
      SELECT "properties".*
      FROM "properties"
      WHERE "properties"."metadata"#>'{subkey}' = 'string'
    SQL
  end
  
  test "::filter json_column: BOOLEAN" do
    query = Property.filter(metadata: true)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip)
      SELECT "properties".*
      FROM "properties"
      WHERE ("properties"."metadata" IS NOT NULL)
    SQL
    
    query = Property.filter(metadata: "true")
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip)
      SELECT "properties".*
      FROM "properties"
      WHERE ("properties"."metadata" IS NOT NULL)
    SQL
    
    query = Property.filter(metadata: false)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip)
      SELECT "properties".*
      FROM "properties"
      WHERE "properties"."metadata" IS NULL
    SQL
    
    query = Property.filter(metadata: "false")
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip)
      SELECT "properties".*
      FROM "properties"
      WHERE "properties"."metadata" IS NULL
    SQL
  end

end
