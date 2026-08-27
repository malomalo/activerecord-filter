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

Relative dates and times
------------------------

Date and time columns (`date`, `datetime`, `time`, `timestamp`) accept values
that are resolved relative to the current time, so a saved filter keeps meaning
the same thing as time passes. Everything is computed in `Time.zone`.

The keywords `now`, `today`, `yesterday` and `tomorrow` can be used anywhere a
time is expected:

```ruby
Property.filter(created_at: {gt: 'now'})
Property.filter(created_at: {gte: 'today'})
```

For anything more, pass a Hash with an `at` anchor — a keyword or any parseable
date/time — alongside the operations to apply to it:

```ruby
Property.filter(created_at: {gt: {at: 'now', add: '7 days'}})
# => "... WHERE properties.created_at > '2026-09-03 14:23:45' ..."

Property.filter(created_at: {lte: {at: '2026-08-02', subtract: '5 months'}})
# => "... WHERE properties.created_at <= '2026-03-02 00:00:00' ..."

Property.filter(created_at: {gt: {at: 'now', start_of: 'day'}})
# => "... WHERE properties.created_at > '2026-08-27 00:00:00' ..."

Property.filter(created_at: {lt: {at: '2027-01-05', end_of: 'month'}})
# => "... WHERE properties.created_at < '2027-01-31 23:59:59.999999' ..."
```

The operations are:

| Operation | Argument | |
| --- | --- | --- |
| `add` | a duration | moves the anchor forward |
| `subtract` | a duration | moves the anchor backward |
| `start_of` | a unit | truncates down to the start of that unit |
| `end_of` | a unit | truncates up to the end of that unit |

A duration is a string of one or more `<amount> <unit>` parts (`'7 days'`,
`'1 year 2 months'`, `'-30 minutes'`), a Hash (`{months: 1, days: 10}`), or a
number of seconds. Units are `second`, `minute`, `hour`, `day`, `week`,
`month`, `quarter` and `year`, singular or plural, and `start_of`/`end_of` take
the same set.

Operations compose, and they are always applied in the order listed above —
shift first, then truncate — regardless of how the Hash is written or
serialized:

```ruby
# The previous calendar month
Property.filter(created_at: {
  gte: {at: 'now', subtract: '1 month', start_of: 'month'},
  lt:  {at: 'now', start_of: 'month'}
})
```

An anchor on its own is just that point in time, which is useful when the
filter is built by a client that always emits the same shape:

```ruby
Property.filter(created_at: {gt: {at: '2026-01-01'}})
```

Relative values work anywhere a literal would, including inside `in` and as a
bare equality:

```ruby
Property.filter(created_at: 'now')
Property.filter(created_at: {in: ['today', {at: 'today', subtract: '1 week'}]})
Property.filter(created_at: {at: 'now', start_of: 'day'})
```

Only date/time columns are inspected, and only a Hash with an `at` key is read
as a relative value, so this cannot change the meaning of any filter that works
today. An anchor that will not parse, an unknown operation, or an unknown unit
raises `ActiveRecord::UnkownFilterError`.

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
