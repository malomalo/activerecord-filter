# frozen_string_literal: true

module ActiveRecord::Filter

  # Builds Arel operands for PostgreSQL date/time range columns (`tsrange`,
  # `tstzrange`, `daterange`) so they can be filtered with the range operators
  # that mirror Ruby/PostgreSQL range semantics:
  #
  #   Player.filter(career_period: {contains: '2026-06-15'})
  #   Player.filter(career_period: {contains: {from: '2026-01-01', to: '2026-12-31'}})
  #   Player.filter(career_period: {overlaps: {from: '2026-01-01', to: '2026-06-30'}})
  #   Player.filter(career_period: {contained_by: {from: '2000-01-01', to: '2030-01-01'}})
  #
  # A value is either a single point — a date/time literal — or a range Hash
  # `{from:, to:, bounds:}` whose `from`/`to` bounds are date/time literals. A
  # missing or `nil` bound is unbounded (SQL `NULL`).
  #
  # `contains` (`@>`) accepts either a point (does the range contain this
  # instant?) or a range (does it contain this whole range?). `overlaps` (`&&`)
  # and `contained_by` (`<@`) compare two ranges, so their operand is a range
  # Hash. Bare equality compares two ranges as well.
  #
  # Bounds and points are quoted literals; PostgreSQL casts them via the range
  # constructor's argument types (a bound) or the explicit element cast (a
  # point).
  module RangeExtension

    # Range column types this module handles, mapped to the element type each
    # range is over. Only date/time ranges are supported for now.
    RANGE_TYPES = {
      tsrange:    'timestamp',
      tstzrange:  'timestamptz',
      daterange:  'date'
    }.freeze

    # Keys that identify a range Hash. `bounds` is the optional inclusivity
    # string PostgreSQL accepts as the third `*range()` argument (`'[)'`,
    # `'[]'`, `'()'`, `'(]'`); when omitted PostgreSQL's default `'[)'` stands.
    LOWER_KEYS  = %w[from lower begin start].freeze
    UPPER_KEYS  = %w[to upper end finish].freeze
    BOUNDS_KEY  = 'bounds'
    RANGE_KEYS  = (LOWER_KEYS + UPPER_KEYS + [BOUNDS_KEY]).freeze

    class << self

      def applies_to?(column)
        RANGE_TYPES.key?(column.type)
      end

      # True when the Hash describes a range literal (`{from:, to:}`) rather
      # than a Hash of predicates (`{overlaps: ...}`). Every key must be a
      # recognised range key and at least one bound must be present, so a
      # predicate Hash can never be mistaken for a range.
      def range_hash?(value)
        return false unless value.is_a?(Hash) && !value.empty?

        keys = value.keys.map { |key| key.to_s }
        (keys - RANGE_KEYS).empty? && keys.any? { |key| bound_key?(key) }
      end

      # The right-hand operand for a range predicate. A range Hash becomes a
      # `*range(lower, upper[, bounds])` constructor; anything else is treated
      # as a single point, cast to the range's element type so
      # `career_period @> '2026-06-15'::timestamp` is well typed (PostgreSQL
      # rejects a bare unknown-typed literal here as a malformed range).
      def build_operand(column, value)
        if range_hash?(value)
          build_range(column, value)
        else
          build_point(column, value)
        end
      end

      # A `*range(lower, upper[, bounds])` constructor node for a range Hash.
      def build_range(column, value)
        hash = value.transform_keys { |key| key.to_s }

        arguments = [
          bound_node(fetch_bound(hash, LOWER_KEYS)),
          bound_node(fetch_bound(hash, UPPER_KEYS))
        ]
        if hash.key?(BOUNDS_KEY)
          arguments << Arel::Nodes.build_quoted(hash[BOUNDS_KEY])
        end

        Arel::Nodes::NamedFunction.new(function_for(column), arguments)
      end

      private

      def build_point(column, value)
        Arel::Nodes::NamedFunction.new(
          'CAST',
          [Arel::Nodes::As.new(Arel::Nodes.build_quoted(value), Arel::Nodes::SqlLiteral.new(element_type(column)))]
        )
      end

      # A single bound inside a `*range()` constructor. `nil`/absent is an
      # unbounded end (`NULL`); everything else is quoted — the constructor's
      # own argument types cast the literal, so no explicit cast is needed here.
      def bound_node(value)
        Arel::Nodes.build_quoted(value)
      end

      def fetch_bound(hash, keys)
        key = keys.find { |candidate| hash.key?(candidate) }
        key && hash[key]
      end

      def bound_key?(key)
        LOWER_KEYS.include?(key) || UPPER_KEYS.include?(key)
      end

      def function_for(column)
        column.type.to_s
      end

      def element_type(column)
        RANGE_TYPES.fetch(column.type)
      end

    end

  end

end
