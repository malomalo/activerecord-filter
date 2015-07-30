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
# => "...WHERE 'Skyscraper' = ANY(properties.tags)..."

Property.filter(:tags => ['Skyscraper', 'Brick']).to_sql
# => "...WHERE (properties.aliases && '{"Skyscraper", "Brick"}')..."
```
It can also sort on relations:

```ruby
Photo.filter(:property => 10).to_sql
# => "...WHERE photos.property_id = 5"

Photo.filter(:property => {name: 'Empire State'}).to_sql
# => "...INNER JOIN properties ON properties.id = photos.property_id
# => "   WHERE properties.name = 'Empire State'"
```
