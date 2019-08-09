# ActiveRecord::filter

`ActiveRecord::filter` provides and easy way to accept user input and filter a query by the input.

Installtion
-----------

- Add `gem 'activerecord-filter', require: 'active_record/filter'
- Run `bundle install`

Examples
--------

Normal columns:

```ruby
Property.filter(:id => 5).to_sql
# => "...WHERE properties.id = 5"

Property.filter(:id => [5, 10, 15]).to_sql
# => "...WHERE properties.id IN (5, 10, 15)"

Property.filter(:id => {:gt => 5}).to_sql
# => "...WHERE properties.id > 5"

Property.filter(:id => {:gte => 5}).to_sql
# => "...WHERE properties.id >= 5"

Property.filter(:id => {:lt => 5}).to_sql
# => "...WHERE properties.id < 5"

Property.filter(:id => {:lte => 5}).to_sql
# => "...WHERE properties.id <= 5"

Property.filter(:address_id => nil).to_sql
# => "...WHERE properties.address_id IS NULL..."

Property.filter(:address_id => false).to_sql
# => "...WHERE properties.address_id IS NULL..."

Property.filter(:address_id => true).to_sql
# => "...WHERE properties.address_id IS NOT NULL..."
```

It can also work with array columns:

```ruby
Property.filter(:tags => 'Skyscraper').to_sql
# => "...WHERE properties.tags = '{'Skyscraper'}'..."

Property.filter(:tags => ['Skyscraper', 'Brick']).to_sql
# => "...WHERE (properties.tags = '{"Skyscraper", "Brick"}')..."

Property.filter(:tags => {overlaps: ['Skyscraper', 'Brick']}).to_sql
# => "...WHERE properties.tags && '{"Skyscraper", "Brick"}')..."

Property.filter(:tags => {contains: ['Skyscraper', 'Brick']}).to_sql
# => "...WHERE accounts.tags @> '{"Skyscraper", "Brick"}')..."
```

And JSON columns:

```ruby
Property.filter(metadata: { eq: { key: 'value' } }).to_sql
# => "...WHERE "properties"."metadata" = '{\"key\":\"value\"}'..."

Property.filter(metadata: { contains: { key: 'value' } }).to_sql
# => "...WHERE "properties"."metadata" @> '{\"key\":\"value\"}'..."

Property.filter(metadata: { has_key: 'key' }).to_sql
# => "...WHERE "properties"."metadata" ? 'key'..."

Property.filter("metadata.key": { eq: 'value' }).to_sql
# => "...WHERE "properties"."metadata" #> '{key}' = 'value'..."
```

It can also sort on relations:

```ruby
Photo.filter(:property => {name: 'Empire State'}).to_sql
# => "...INNER JOIN properties ON properties.id = photos.property_id
# => "   WHERE properties.name = 'Empire State'"
```
