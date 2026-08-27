# frozen_string_literal: true

module ActiveRecord::Filter

  # Resolves "relative" date/time filter values into concrete `Time`s before
  # they are handed to Arel.
  #
  # A relative value is either a keyword:
  #
  #   Property.filter(created_at: {gt: 'now'})
  #
  # or a single-pair Hash of `{anchor => operations}`, where the anchor is a
  # keyword or a parseable date/time and the operations are applied in order:
  #
  #   Property.filter(created_at: {gt: {'now' => {add: '7 days'}}})
  #   Property.filter(created_at: {lte: {'2026-08-02' => {subtract: '5 months'}}})
  #   Property.filter(created_at: {lt: {'2027-01-05' => {end_of: 'month'}}})
  #
  # Only columns of a date/time type are inspected, so nothing here can change
  # the meaning of a filter on any other column.
  module RelativeTime

    # Column types whose values may be relative.
    COLUMN_TYPES = %i[date datetime time timestamp timestamptz].freeze

    # The operations that may appear in the operations Hash of an anchor.
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
          anchor, operations = value.first
          apply(resolve_anchor(anchor), operations)
        else
          value
        end
      end

      def keyword?(value)
        (value.is_a?(String) || value.is_a?(Symbol)) &&
          KEYWORDS.include?(value.to_s.strip.downcase)
      end

      # `{anchor => operations}`. The operations are what identify the form, so
      # that a predicate Hash (`{gt: ...}`) can never be mistaken for an anchor.
      # With operations present the anchor must resolve — an unparseable one is
      # an error rather than a value quietly passed through to the adapter.
      # With no operations there is nothing to go on, so the anchor itself has
      # to look like a date/time.
      def relative_hash?(value)
        return false unless value.is_a?(Hash) && value.size == 1

        operations = value.values.first
        return false unless operations.is_a?(Hash)
        return false unless operations.keys.all? { |key| OPERATIONS.include?(key.to_s.to_sym) }

        operations.any? || anchor?(value.keys.first)
      end

      def anchor?(value)
        !resolve_anchor(value, raise_on_error: false).nil?
      end

      def resolve_anchor(value, raise_on_error: true)
        case value
        when Time, DateTime
          value
        when Date
          value.respond_to?(:in_time_zone) && Time.zone ? value.in_time_zone : value.to_time
        when String, Symbol
          resolve_anchor_string(value.to_s.strip, raise_on_error)
        else
          return nil unless raise_on_error
          raise ActiveRecord::UnkownFilterError.new("Unknown date/time anchor: #{value.inspect}")
        end
      end

      def resolve_anchor_string(value, raise_on_error)
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

          if parsed.nil? && raise_on_error
            raise ActiveRecord::UnkownFilterError.new("Unknown date/time anchor: #{value.inspect}")
          end

          parsed
        end
      end

      def apply(time, operations)
        operations.inject(time) do |result, (operation, argument)|
          case operation.to_s.to_sym
          when :add       then result + parse_duration(argument)
          when :subtract  then result - parse_duration(argument)
          when :start_of  then truncate(result, argument, :beginning)
          when :end_of    then truncate(result, argument, :end)
          else
            raise ActiveRecord::UnkownFilterError.new("Unknown date/time operation: #{operation.inspect}")
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
