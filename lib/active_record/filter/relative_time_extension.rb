# frozen_string_literal: true

module ActiveRecord::Filter

  # Resolves "relative" date/time filter values into concrete `Time`s before
  # they are handed to Arel.
  #
  # A relative value is either a keyword:
  #
  #   Property.filter(created_at: {gt: 'now'})
  #
  # or a Hash with an `at` anchor — a keyword or a parseable date/time —
  # alongside any of the operations to apply to it:
  #
  #   Property.filter(created_at: {gt: {at: 'now', add: '7 days'}})
  #   Property.filter(created_at: {lte: {at: '2026-08-02', subtract: '5 months'}})
  #   Property.filter(created_at: {lt: {at: '2027-01-05', end_of: 'month'}})
  #
  # `at` is what marks the Hash as relative, so a predicate Hash can never be
  # mistaken for one. Operations are applied in a fixed order (see OPERATIONS)
  # rather than the order they were written, so the result does not depend on
  # Hash ordering.
  #
  # Only columns of a date/time type are inspected, so nothing here can change
  # the meaning of a filter on any other column.
  module RelativeTimeExtension

    # Column types whose values may be relative.
    COLUMN_TYPES = %i[date datetime time timestamp timestamptz].freeze

    # The key that marks a Hash as a relative date/time.
    ANCHOR_KEY = 'at'

    # The operations that may accompany an anchor, in the order they are
    # applied. Shifting before truncating is what almost every filter wants
    # ("the start of last month"), and fixing the order keeps the result
    # independent of how the Hash was written or serialized.
    OPERATIONS = %i[add subtract start_of end_of].freeze

    KEYWORDS = %w[now today yesterday tomorrow].freeze

    # Units accepted by `add`/`subtract`, mapped to their `ActiveSupport::Duration`
    # constructor. `quarter` has no constructor of its own and is handled as
    # three months.
    DURATION_UNITS = {
      'second'  => :seconds, 'sec' => :seconds, 's' => :seconds,
      'minute'  => :minutes, 'min' => :minutes,
      'hour'    => :hours,   'hr'  => :hours,   'h' => :hours,
      'day'     => :days,    'd'   => :days,
      'week'    => :weeks,   'wk'  => :weeks,   'w' => :weeks,
      'month'   => :months,  'mon' => :months,
      'quarter' => :quarters, 'qtr' => :quarters,
      'year'    => :years,   'yr'  => :years,   'y' => :years
    }.freeze

    # Units accepted by `start_of`/`end_of`.
    TRUNCATION_UNITS = %w[second minute hour day week month quarter year].freeze

    DURATION_PART = /-?\d+(?:\.\d+)?\s*[a-zA-Z]+/
    DURATION_FORMAT = /\A\s*#{DURATION_PART}(?:\s*,?\s*#{DURATION_PART})*\s*\z/

    class << self

      def applies_to?(column)
        COLUMN_TYPES.include?(column.type)
      end

      # Entry point for a filter value on a date/time column. The value is
      # either relative itself (`created_at: 'now'`), a Hash of predicates
      # whose values may be relative (`created_at: {gt: 'now'}`), or an Array
      # of values (`created_at: {in: ['now', ...]}`).
      def resolve_filter_value(value)
        if relative?(value)
          resolve(value)
        elsif value.is_a?(Hash)
          value.transform_values { |subvalue| resolve(subvalue) }
        else
          resolve(value)
        end
      end

      def relative?(value)
        keyword?(value) || relative_hash?(value)
      end

      private

      def resolve(value)
        if value.is_a?(Array)
          value.map { |subvalue| resolve(subvalue) }
        elsif keyword?(value)
          resolve_anchor(value)
        elsif relative_hash?(value)
          operations = value.reject { |key, _| key.to_s == ANCHOR_KEY }
          apply(resolve_anchor(anchor_of(value)), operations)
        else
          value
        end
      end

      def keyword?(value)
        (value.is_a?(String) || value.is_a?(Symbol)) &&
          KEYWORDS.include?(value.to_s.strip.downcase)
      end

      # The `at` key is what identifies the form, so a predicate Hash
      # (`{gt: ...}`) can never be mistaken for a relative one and there is no
      # shape to guess at. Anything else in the Hash must be an operation, and
      # an anchor that will not resolve is an error rather than a value quietly
      # passed through to the adapter.
      def relative_hash?(value)
        value.is_a?(Hash) && value.any? { |key, _| key.to_s == ANCHOR_KEY }
      end

      def anchor_of(value)
        value.find { |key, _| key.to_s == ANCHOR_KEY }.last
      end

      def resolve_anchor(value)
        case value
        when Time, DateTime
          value
        when Date
          value.respond_to?(:in_time_zone) && Time.zone ? value.in_time_zone : value.to_time
        when String, Symbol
          resolve_anchor_string(value.to_s.strip)
        else
          raise ActiveRecord::UnkownFilterError.new("Unknown date/time anchor: #{value.inspect}")
        end
      end

      def resolve_anchor_string(value)
        case value.downcase
        when 'now'       then Time.current
        when 'today'     then Time.current.beginning_of_day
        when 'yesterday' then Time.current.yesterday.beginning_of_day
        when 'tomorrow'  then Time.current.tomorrow.beginning_of_day
        else
          parsed = begin
            Time.zone ? Time.zone.parse(value) : Time.parse(value)
          rescue ArgumentError, TypeError
            nil
          end

          if parsed.nil?
            raise ActiveRecord::UnkownFilterError.new("Unknown date/time anchor: #{value.inspect}")
          end

          parsed
        end
      end

      # Operations are applied in OPERATIONS order, not the order they appear
      # in the Hash, so `{subtract: '1 month', start_of: 'month'}` and
      # `{start_of: 'month', subtract: '1 month'}` mean the same thing.
      def apply(time, operations)
        operations = operations.transform_keys { |key| key.to_s.to_sym }

        unknown = operations.keys - OPERATIONS
        if unknown.any?
          raise ActiveRecord::UnkownFilterError.new("Unknown date/time operation: #{unknown.first.inspect}")
        end

        OPERATIONS.inject(time) do |result, operation|
          next result unless operations.key?(operation)
          argument = operations[operation]

          case operation
          when :add      then result + parse_duration(argument)
          when :subtract then result - parse_duration(argument)
          when :start_of then truncate(result, argument, :beginning)
          when :end_of   then truncate(result, argument, :end)
          end
        end
      end

      def parse_duration(value)
        case value
        when ActiveSupport::Duration
          value
        when Numeric
          value.seconds
        when Hash
          value.inject(0.seconds) { |sum, (unit, amount)| sum + duration_for(amount, unit) }
        when String, Symbol
          parse_duration_string(value.to_s)
        else
          raise ActiveRecord::UnkownFilterError.new("Unknown duration: #{value.inspect}")
        end
      end

      def parse_duration_string(value)
        unless value.match?(DURATION_FORMAT)
          raise ActiveRecord::UnkownFilterError.new("Unknown duration: #{value.inspect}")
        end

        value.scan(/(-?\d+(?:\.\d+)?)\s*([a-zA-Z]+)/).inject(0.seconds) do |sum, (amount, unit)|
          sum + duration_for(amount, unit)
        end
      end

      def duration_for(amount, unit)
        key = unit.to_s.strip.downcase.sub(/s\z/, '')
        method = DURATION_UNITS[key] || DURATION_UNITS[unit.to_s.strip.downcase]

        unless method
          raise ActiveRecord::UnkownFilterError.new("Unknown duration unit: #{unit.inspect}")
        end

        amount = amount.is_a?(String) ? (amount.include?('.') ? amount.to_f : amount.to_i) : amount

        # ActiveSupport has no `quarters`; a quarter is three months.
        method == :quarters ? (amount * 3).months : amount.public_send(method)
      end

      def truncate(time, unit, boundary)
        key = unit.to_s.strip.downcase.sub(/s\z/, '')

        unless TRUNCATION_UNITS.include?(key)
          raise ActiveRecord::UnkownFilterError.new("Unknown date/time unit: #{unit.inspect}")
        end

        # `beginning_of_second`/`end_of_second` do not exist.
        if key == 'second'
          return boundary == :beginning ? time.change(usec: 0) : time.change(usec: 999999)
        end

        time.public_send("#{boundary == :beginning ? 'beginning' : 'end'}_of_#{key}")
      end

    end

  end

end
