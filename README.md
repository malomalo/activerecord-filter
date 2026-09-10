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
# => "...WHERE "properties"."metadata" #> array['key'] = 'value'..."
```

Range columns
-------------

PostgreSQL range columns (`int4range`, `int8range`, `numrange`, `tsrange`,
`tstzrange`, `daterange`) can be filtered with operators that mirror
Ruby/PostgreSQL range semantics. Given a `career_period` range on `Player`:

```ruby
# @> — does the range contain this instant?
Player.filter(career_period: {contains: '2026-06-15'}).to_sql
# => "... WHERE players.career_period @> CAST('2026-06-15' AS timestamp) ..."

# @> — does the range contain this whole range?
Player.filter(career_period: {contains: {begin: '2026-01-01', end: '2026-12-31'}}).to_sql
# => "... WHERE players.career_period @> '[2026-01-01 00:00:00,2026-12-31 00:00:00]' ..."

# && — do the two ranges overlap?
Player.filter(career_period: {overlaps: {begin: '2026-01-01', end_before: '2026-06-30'}}).to_sql
# => "... WHERE players.career_period && '[2026-01-01 00:00:00,2026-06-30 00:00:00)' ..."

# <@ — is the range contained by this one?
Player.filter(career_period: {contained_by: {begin: '2000-01-01', end: '2030-01-01'}}).to_sql
# => "... WHERE players.career_period <@ '[2000-01-01 00:00:00,2030-01-01 00:00:00]' ..."
```

| Operator | SQL | Operand |
| --- | --- | --- |
| `contains` | `@>` | a single point, or a range |
| `overlaps` | `&&` | a range |
| `contained_by` | `<@` | a range |
| `eq` | `=` | a range |

A **point** is a single value. It is cast to the range's element type, which is
what PostgreSQL requires on the right of `@>`.

A **range** is either a Ruby Range or a Hash naming its bounds. Whether a bound
is inclusive is part of the key: `begin`/`end` include it, `begin_after`/
`end_before` exclude it. That covers all four of PostgreSQL's combinations,
including the two a Ruby Range cannot express:

| Filter value | PostgreSQL | Matches |
| --- | --- | --- |
| `1..3` | `[1,3]` | 1, 2, 3 |
| `1...3` | `[1,3)` | 1, 2 |
| `{begin: 1, end: 3}` | `[1,3]` | 1, 2, 3 |
| `{begin: 1, end_before: 3}` | `[1,3)` | 1, 2 |
| `{begin_after: 1, end: 3}` | `(1,3]` | 2, 3 |
| `{begin_after: 1, end_before: 3}` | `(1,3)` | 2 |

An omitted bound is an unbounded end:

```ruby
Player.filter(career_period: {overlaps: {begin: '2026-01-01'}})   # unbounded upper
Player.filter(career_period: {overlaps: {end_before: '2026-01-01'}})  # unbounded lower
```

Naming the same end twice — `{begin: 1, begin_after: 2}` — raises
`ActiveRecord::UnkownFilterError`.

Range equality is written with `eq`, not as a bare value — a Hash filter value
is always read as predicates:

```ruby
Player.filter(career_period: {eq: {begin: '2026-01-01', end_before: '2026-12-31'}}).to_sql
# => "... WHERE players.career_period = '[2026-01-01 00:00:00,2026-12-31 00:00:00)' ..."
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
