require 'test_helper'

class HasManyFilterTest < ActiveSupport::TestCase

  schema do
    create_table "accounts", force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.integer  'photos_count', null: false, default: 0
    end

    create_table "photos", force: :cascade do |t|
      t.integer  "account_id"
      t.integer  "property_id"
      t.string   "format",                 limit: 255
      t.string   "tags", array: true, default: [], null: false
    end
    create_table "properties" do |t|
      t.string   "name",                    limit: 255
      t.string   "state",                    limit: 255
    end
  end

  class Account < ActiveRecord::Base
    has_many :photos
    
    js = -> (filters) do
      x = if filters.is_a?(Array) && filters.size > 1
        reflection = self.reflect_on_association(:photos)
        filters.reduce([]) do |sum, f|
          if !f.is_a?(String)
            right_table = reflection.klass.arel_table.alias("photos_#{sum.size}")
            left_table = reflection.active_record.arel_table
            on = right_table[reflection.foreign_key].eq(left_table[reflection.klass.primary_key])
            sum + left_table.join(right_table, Arel::Nodes::OuterJoin).on(on).join_sources
          else
            sum
          end
        end
      else
        :photos
      end
    end
    
    filter_on :joinalias, js do |klass, table, key, value, relation_trail, alias_tracker|
      if value.is_a?(Array) && value.size > 1
        reflection = klass.reflect_on_association(:photos)
        
        builder = ActiveRecord::PredicateBuilder.new(ActiveRecord::TableMetadata.new(reflection.klass, reflection.klass.arel_table.alias("photos_0"), reflection))
        node = builder.build_from_filter_hash(value.shift, relation_trail + [reflection.name], alias_tracker)
        n = value.shift(2)
        t = 1
        while !n.empty?
          builder = ActiveRecord::PredicateBuilder.new(ActiveRecord::TableMetadata.new(reflection.klass, reflection.klass.arel_table.alias("photos_#{t}"), reflection))
          t += 1
          n[1] = builder.build_from_filter_hash(n[1], relation_trail + [reflection.name], alias_tracker)
          if n[0] == 'AND'
            if node.is_a?(Arel::Nodes::And)
              node.children.push(n[1])
            else
              node = node.and(n[1])
            end
          elsif n[0] == 'OR'
            node = Arel::Nodes::Grouping.new(node).or(Arel::Nodes::Grouping.new(n[1]))
          elsif !n[0].is_a?(String)
            builder = ActiveRecord::PredicateBuilder.new(ActiveRecord::TableMetadata.new(reflection.klass, reflection.klass.arel_table.alias("photos_#{t}"), reflection))
            t += 1
            n[0] = builder.build_from_filter_hash(n[0], relation_trail + [reflection.name], alias_tracker)
            if node.is_a?(Arel::Nodes::And)
              node.children.push(n[0])
            else
              node = node.and(n[0])
            end
          else
            raise 'lll'
          end
          n = value.shift(2)
        end
        node
      else
        expand_filter_for_relationship(relation, value, relation_trail, alias_tracker)
      end
    end
  end

  class Photo < ActiveRecord::Base
    belongs_to :account, counter_cache: true
    belongs_to :property
    filter_on :no_properties_where_state_is_null, "LEFT OUTER JOIN \"properties\" ON \"properties\".\"id\" = \"photos\".\"property_id\" AND \"properties\".\"state\" IS NULL" do |klass, table, key, value, join_dependency|
      Property.arel_table['id'].eq(nil)
    end
  end

  class Property < ActiveRecord::Base
    has_many :photos
  end

  test "::filter has_many: BOOL (with counter_cache)" do
    query = Account.filter(photos: true)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      WHERE accounts.photos_count > 0
    SQL

    query = Account.filter(photos: "true")
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      WHERE accounts.photos_count > 0
    SQL


    query = Account.filter(photos: false)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      WHERE accounts.photos_count = 0
    SQL

    query = Account.filter(photos: "false")
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      WHERE accounts.photos_count = 0
    SQL
  end

  test "::filter has_many: FILTER" do
    query = Account.filter(photos: {format: 'jpg'})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      LEFT OUTER JOIN photos ON photos.account_id = accounts.id
      WHERE photos.format = 'jpg'
    SQL
    
    query = Account.filter(photos: {tags: {overlaps: ['cute']}})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      LEFT OUTER JOIN photos ON photos.account_id = accounts.id
      WHERE photos.tags && '{cute}'
    SQL
  end

  test "::filter nested relationships" do
    query = Account.filter(photos: {property: {name: 'Name'}})
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      LEFT OUTER JOIN photos ON photos.account_id = accounts.id
      LEFT OUTER JOIN properties ON properties.id = photos.property_id
      WHERE properties.name = 'Name'
    SQL

    query = Account.filter(photos: [ { property: { name: 'Name' } } ])
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      LEFT OUTER JOIN photos ON photos.account_id = accounts.id
      LEFT OUTER JOIN properties ON properties.id = photos.property_id
      WHERE properties.name = 'Name'
    SQL

    query = Account.filter(photos: [ { property: { name: 'Name' } }, { account: { name: 'Person' } } ])
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      LEFT OUTER JOIN photos ON photos.account_id = accounts.id
      LEFT OUTER JOIN properties ON properties.id = photos.property_id
      LEFT OUTER JOIN accounts accounts_photos ON accounts_photos.id = photos.account_id
      WHERE properties.name = 'Name'
        AND accounts_photos.name = 'Person'
    SQL
  end

  test "::filter has_many: INT" do
    query = Account.filter(photos: 1)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      LEFT OUTER JOIN photos ON photos.account_id = accounts.id
      WHERE photos.id = 1
    SQL
  end

  test "::filter has_many_ids: INT" do
    query = Account.filter(photo_ids: 1)
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      LEFT OUTER JOIN photos ON photos.account_id = accounts.id
      WHERE photos.id = 1
    SQL
  end

  test "::filter has_many_ids: [INT]" do
    query = Account.filter(photo_ids: [1, 2])
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      LEFT OUTER JOIN photos ON photos.account_id = accounts.id
      WHERE photos.id IN (1, 2)
    SQL
  end

  test "::filter filter_on" do
    query = Photo.filter(no_properties_where_state_is_null: true)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT photos.* FROM photos
      LEFT OUTER JOIN properties ON properties.id = photos.property_id AND properties.state IS NULL
      WHERE properties.id IS NULL
    SQL
  end

  test "::filter has_many filter_on" do
    query = Account.filter(photos: {no_properties_where_state_is_null: true})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      LEFT OUTER JOIN photos ON photos.account_id = accounts.id
      LEFT OUTER JOIN properties ON properties.id = photos.property_id AND properties.state IS NULL
      WHERE properties.id IS NULL
    SQL
  end

  # test "::filter :has_many with lambda" do
  #   a1 = create(:property)
  #   a2 = create(:property)
  #   create(:lease, :property => a1)
  #   create(:sublease, :property => a2)
  #
  #   assert_equal [a1], Property.filter(:listings => { :type => 'lease'} )
  #   assert_equal [a2], Property.filter(:listings => { :type => 'sublease'} )
  # end

  test "::filter custom!" do
    query = Account.filter(joinalias: [{id: 1}, 'AND', {id: 2}])

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.strip.gsub('"', ''))
      SELECT accounts.* FROM accounts
      LEFT OUTER JOIN photos photos_0 ON photos_0.account_id = accounts.id
      LEFT OUTER JOIN photos photos_1 ON photos_1.account_id = accounts.id
      WHERE photos_0.id = 1
        AND photos_1.id = 2
    SQL
  end
end
