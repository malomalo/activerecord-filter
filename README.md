# ActiveRecord::filter

`ActiveRecord::filter` provides and easy way to accept user input and filter a query by the input.

Installtion
-----------

- Add `gem 'activerecord-filter', require: 'active_record/filter'`
- Run `bundle install`

Examples
--------

Normal columns:

```ruby
Property.filter(id: 5).to_sql
Property.filter(id: {eq: 5}).to_sql
Property.filter(id: {equal_to: 5}).to_sql
# => "... WHERE properties.id = 5 ..."

Property.filter(id: {not: 5}).to_sql
Property.filter(id: {neq: 5}).to_sql
Property.filter(id: {not_equal: 5}).to_sql
# => "... WHERE properties.id != 5 ..."

Property.filter(id: [5, 10, 15]).to_sql
# => "... WHERE properties.id IN (5, 10, 15) ..."

Property.filter(id: {in: [5, 10, 15]}).to_sql
# => "... WHERE properties.id IN (5, 10, 15) ..."

Property.filter(id: {not_in: [5, 10, 15]}).to_sql
# => "... WHERE properties.id NOT IN (5, 10, 15) ..."

Property.filter(id: {gt: 5}).to_sql
Property.filter(id: {greater_than: 5}).to_sql
# => "... WHERE properties.id > 5 ..."

Property.filter(id: {gte: 5}).to_sql
Property.filter(id: {gteq: 5}).to_sql
Property.filter(id: {greater_than_or_equal_to: 5}).to_sql
# => "... WHERE properties.id >= 5 ..."

Property.filter(id: {lt: 5}).to_sql
Property.filter(id: {less_than: 5}).to_sql
# => "... WHERE properties.id < 5 ..."

Property.filter(id: {lte: 5}).to_sql
Property.filter(id: {lteq: 5}).to_sql
Property.filter(id: {less_than_or_equal_to: 5}).to_sql
# => "... WHERE properties.id <= 5 ..."

Property.filter(address_id: nil).to_sql
# => "... WHERE properties.address_id IS NULL ..."

Property.filter(address_id: false).to_sql
# => "... WHERE properties.address_id IS NULL ..."

Property.filter(boolean_column: false).to_sql
# => "... WHERE properties.boolean_column = FALSE ..."

Property.filter(address_id: true).to_sql
# => "... WHERE properties.address_id IS NOT NULL ..."

Property.filter(boolean_column: true).to_sql
# => "... WHERE properties.boolean_column = TRUE ..."
```

String columns:

```ruby
Property.filter(name: {like: 'nam%'}).to_sql
# => "... WHERE properties.name LIKE 'nam%' ..."

Property.filter(name: {ts_match: 'name'}).to_sql
# => "... WHERE to_tsvector("properties"."name") @@ to_tsquery('name') ..."
```

It can also work with array columns:

```ruby
Property.filter(tags: 'Skyscraper').to_sql
# => "...WHERE properties.tags = '{'Skyscraper'}'..."

Property.filter(tags: ['Skyscraper', 'Brick']).to_sql
# => "...WHERE properties.tags = '{"Skyscraper", "Brick"}'..."

Property.filter(tags: {overlaps: ['Skyscraper', 'Brick']}).to_sql
# => "...WHERE properties.tags && '{"Skyscraper", "Brick"}'..."

Property.filter(tags: {contains: ['Skyscraper', 'Brick']}).to_sql
# => "...WHERE accounts.tags @> '{"Skyscraper", "Brick"}'..."

Property.filter(tags: {excludes: ['Skyscraper', 'Brick']}).to_sql
# => "...WHERE NOT (accounts.tags @> '{"Skyscraper", "Brick"}')..."

Property.filter(tags: {contained_by: ['Skyscraper', 'Brick']}).to_sql
# => "...WHERE accounts.tags <@ '{"Skyscraper", "Brick"}'..."
```

And JSON columns:

```ruby
Property.filter(metadata: { eq: { key: 'value' } }).to_sql
# => "...WHERE "properties"."metadata" = '{\"key\":\"value\"}'..."

Property.filter(metadata: { contains: { key: 'value' } }).to_sql
# => "...WHERE "properties"."metadata" @> '{\"key\":\"value\"}'..."

Property.filter(metadata: { has_key: 'key' }).to_sql
# => "...WHERE "properties"."metadata" ? 'key'..."

Property.filter(metadata: { has_keys: ['key1', 'key2'] }).to_sql
# => "...WHERE "properties"."metadata" ?& array['key1', 'key2']..."

Property.filter(metadata: { has_any_key: ['key1', 'key2'] }).to_sql
# => "...WHERE "properties"."metadata" ?| array['key1', 'key2']..."

Property.filter("metadata.key": { eq: 'value' }).to_sql
# => "...WHERE "properties"."metadata" #> '{key}' = 'value'..."
```

It can also sort on relations:

```ruby
Photo.filter(property: {name: 'Empire State'}).to_sql
# => "... LEFT OUTER JOIN properties ON properties.id = photos.property_id ...
# => "... WHERE properties.name = 'Empire State'"
```
