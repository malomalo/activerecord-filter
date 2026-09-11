# frozen_string_literal: true

module ActiveRecord::Filter

  # Operand building for PostgreSQL range columns, mixed into
  # PredicateBuilderExtension. These are only reached from the range branches
  # of `expand_filter_for_arel_attribute`, so a column's type is consulted just
  # for filters that actually name a range operator.
  module RangeHelper

    # Keys that identify a range Hash, mapped to whether the bound they name is
    # exclusive. Putting the exclusivity in the key means every one of
    # PostgreSQL's four bound combinations can be written, which a `bounds`
    # string paired with a Ruby Range could not do.
    #
    #   {begin: 1,       end: 3}         =>  [1,3]
    #   {begin: 1,       end_before: 3}  =>  [1,3)
    #   {begin_after: 1, end: 3}         =>  (1,3]
    #   {begin_after: 1, end_before: 3}  =>  (1,3)
    RANGE_BEGIN_KEYS = {
      'begin'        => false, 'begins'       => false,
      'begin_after'  => true,  'begins_after' => true
    }.freeze
    RANGE_END_KEYS = {
      'end'          => false, 'ends'         => false,
      'end_before'   => true,  'ends_before'  => true
    }.freeze
    RANGE_KEYS = (RANGE_BEGIN_KEYS.keys + RANGE_END_KEYS.keys).freeze

    # PostgreSQL's positional range operators, as filter key => the
    # arel-extensions predication it calls.
    #
    # The two vocabularies differ on purpose. arel-extensions names the SQL
    # operator — `strictly_left_of` is what `<<` is called. A filter key names
    # the question being asked of the column, and every one of these compares a
    # single edge of the column's range against a single edge of the operand:
    #
    #   ends_before   <<   upper(column) <= lower(operand)
    #   ends_by       &<   upper(column) <= upper(operand)
    #   starts_after  >>   lower(column) >= upper(operand)
    #   starts_by     &>   lower(column) >= lower(operand)
    #
    # So the first pair forbid overlap entirely and the second pair constrain
    # one edge and permit it.
    RANGE_POSITION_PREDICATES = {
      ends_before:  :strictly_left_of,
      ends_by:      :not_extend_right_of,
      starts_after: :strictly_right_of,
      starts_by:    :not_extend_left_of,
      adjacent_to:  :adjacent_to
    }.freeze

    # ActiveRecord models every PostgreSQL range column with OID::Range, so ask it
    # rather than keeping a list of range type names. This also covers range types
    # declared with `CREATE TYPE ... AS RANGE`, which a hardcoded list would miss.
    def range_column?(column)
      !!range_type(column)
    end

    def range_type(column)
      return nil unless defined?(ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Range)

      type = table.send(:klass).type_for_attribute(column.name)
      type.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Range) ? type : nil
    end

    # The right-hand operand for a range predicate. ActiveRecord types a range
    # column as OID::Range, so a Ruby Range serializes itself to a PostgreSQL
    # range literal and needs nothing from us.
    #
    # A single point does need help: `career_period @> '2026-06-15'` makes
    # PostgreSQL read the literal as a range and fail with "malformed range
    # literal", so it is cast to the range's element type.
    def range_from_value(column, value)
      return value if value.is_a?(::Range)
      return range_from_hash(column, value) if value.is_a?(Hash)

      range_point(column, value)
    end

    # A single point, cast to the range's element type.
    #
    # The value is serialized through that element type first, so it is read the
    # way the rest of ActiveRecord reads it rather than however the server's
    # DateStyle happens to be set — `'01/02/2005'` is February 1st to Ruby and
    # January 2nd to PostgreSQL. Serializing also catches input the type cannot
    # read, which would otherwise reach the database as NULL and quietly match
    # nothing.
    #
    # The cast itself has to stay in the SQL: PostgreSQL resolves `@>` against an
    # unknown-typed literal as `anyrange @> anyrange` and fails with "malformed
    # range literal", and no amount of Ruby-side formatting changes that.
    def range_point(column, value)
      type = range_type(column).subtype
      serialized = type.serialize(value)

      if serialized.nil? && !value.nil?
        raise ActiveRecord::UnkownFilterError.new(
          "Could not read #{value.inspect} as #{column.name}'s element type (#{type.type})."
        )
      end

      table.arel_table.cast(
        Arel::Nodes.build_quoted(serialized),
        Arel::Nodes::SqlLiteral.new(table.send(:klass).lease_connection.type_to_sql(type.type))
      )
    end

    # A `{begin:, end:}` Hash becomes a Ruby Range, which ActiveRecord serializes
    # through the column's own range type. An absent bound is an unbounded end.
    #
    # Ruby has no exclusive *lower* bound, so `begin_after` is the one shape a
    # Range cannot carry; those fall back to PostgreSQL's own
    # `*range(lower, upper, bounds)` constructor, which quotes each bound
    # separately rather than interpolating them into a range literal.
    def range_from_hash(column, value)
      hash = value.transform_keys(&:to_s)

      unknown = hash.keys - RANGE_KEYS
      if unknown.any? || hash.empty?
        raise ActiveRecord::UnkownFilterError.new(
          "Unknown range bound #{unknown.first.inspect} for #{column.name}. " \
          "Expected one or two of #{RANGE_KEYS.map(&:inspect).join(', ')}."
        )
      end

      begin_key = range_bound_key(hash, RANGE_BEGIN_KEYS, column)
      end_key   = range_bound_key(hash, RANGE_END_KEYS, column)

      lower = begin_key && hash[begin_key]
      upper = end_key && hash[end_key]

      exclude_begin = begin_key ? RANGE_BEGIN_KEYS[begin_key] : false
      exclude_end   = end_key   ? RANGE_END_KEYS[end_key]     : false

      if exclude_begin
        Arel::Nodes::NamedFunction.new(column.type.to_s, [
          Arel::Nodes.build_quoted(lower),
          Arel::Nodes.build_quoted(upper),
          Arel::Nodes.build_quoted(exclude_end ? '()' : '(]')
        ])
      else
        exclude_end ? (lower...upper) : (lower..upper)
      end
    end

    # Each end may be named only once — `{begin: 1, begin_after: 2}` is a
    # contradiction rather than a precedence question.
    def range_bound_key(hash, keys, column)
      present = keys.keys.select { |key| hash.key?(key) }
      return present.first if present.size <= 1

      raise ActiveRecord::UnkownFilterError.new(
        "Conflicting range bounds #{present.map(&:inspect).join(' and ')} for #{column.name}."
      )
    end

  end

end
