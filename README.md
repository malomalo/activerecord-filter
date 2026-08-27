# ActiveRecord::Filter

`ActiveRecord::Filter` provides an easy way to accept user input and filter a query by that input.

## Requirements

- Ruby >= 3.3
- ActiveRecord >= 8.0

## Installation

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

Property.filter(name: {ilike: 'nam%'}).to_sql
# => "... WHERE properties.name ILIKE 'nam%' ..."

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

It can also filter across associations. Any association (`belongs_to`,
`has_many`, `has_one`, `has_and_belongs_to_many`, `has_many :through`) can be
nested, and the join is added for you:

```ruby
Photo.filter(property: {name: 'Empire State'}).to_sql
# => "... LEFT OUTER JOIN properties ON properties.id = photos.property_id ...
# => "... WHERE properties.name = 'Empire State'"
```

Pass `true`/`false` against an association to filter on its presence:

```ruby
Account.filter(photos: true).to_sql   # accounts that have photos
Account.filter(photos: false).to_sql  # accounts with no photos
```

For a polymorphic association, scope it to a type with `as:`:

```ruby
View.filter(subject: {as: 'Property', name: 'Name'}).to_sql
```

Combining conditions with AND / OR
----------------------------------

Pass an array to group conditions. Use the strings `'AND'` / `'OR'` as
separators, and nest arrays for precedence:

```ruby
Property.filter([{id: 10}, 'OR', {name: 'name'}]).to_sql
# => "... WHERE ((properties.id = 10) OR (properties.name = 'name'))"

Property.filter([{id: 10}, 'AND', [{id: 10}, 'OR', {name: 'name'}]]).to_sql
# => "... WHERE properties.id = 10 AND ((properties.id = 10) OR (properties.name = 'name'))"
```
