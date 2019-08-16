require 'active_record'
require 'arel/extensions'

class ActiveRecord::UnkownFilterError < NoMethodError
end

module ActiveRecord::Filter

  delegate :filter, :filter_for, to: :all
  
  def inherited(subclass)
    super
    subclass.instance_variable_set('@filters', HashWithIndifferentAccess.new)
  end
  
  def filters
    @filters
  end
  
  def filter_on(name, dependent_joins=nil, &block)
    @filters[name.to_s] = {
      joins: dependent_joins,
      block: block
    }
  end
  
end

module ActiveRecord
  class PredicateBuilder # :nodoc:

    def self.filter_joins(klass, filters)
      custom = []
      [build_filter_joins(klass, filters, [], custom), custom]
    end
    
    def self.build_filter_joins(klass, filters, relations=[], custom=[])
      if filters.is_a?(Array)
        filters.each { |f| build_filter_joins(klass, f, relations, custom) }.compact
      elsif filters.is_a?(Hash)
        filters.each do |key, value|
          if klass.filters.has_key?(key.to_sym)
            js = klass.filters.dig(key.to_sym, :joins)
            
            if js.is_a?(Array)
              js.each do |j|
                if j.is_a?(String)
                  custom << j
                else
                  relations << j
                end
              end
            elsif js
              if js.is_a?(String)
                custom << js
              else
                relations << js
              end
            end
          elsif reflection = klass._reflections[key.to_s]
            if value.is_a?(Hash)
              relations << {
                key => build_filter_joins(reflection.klass, value, [], custom)
              }
            elsif value != true && value != false && value != 'true' && value != 'false' && !value.nil?
              relations << key
            end
          elsif !klass.columns_hash.has_key?(key.to_s) && key.to_s.ends_with?('_ids') && reflection = klass._reflections[key.to_s.gsub(/_ids$/, 's')]
            relations << reflection.name
          elsif reflection = klass.reflect_on_all_associations(:has_and_belongs_to_many).find {|r| r.join_table == key.to_s && value.keys.first.to_s == r.association_foreign_key.to_s }
            reflection = klass._reflections[klass._reflections[reflection.name.to_s].send(:delegate_reflection).options[:through].to_s]
            relations << {reflection.name => build_filter_joins(reflection.klass, value)}
          end
        end
      end
      
      relations
    end
    
    def build_from_filter_hash(attributes)
      if attributes.is_a?(Array)
        node = build_from_filter_hash(attributes.shift)

        n = attributes.shift(2)
        while !n.empty?
          n[1] = build_from_filter_hash(n[1])
          if n[0] == 'AND'
            if node.is_a?(Arel::Nodes::And)
              node.children.push(n[1])
            else
              node = node.and(n[1])
            end
          elsif n[0] == 'OR'
            node = Arel::Nodes::Grouping.new(node).or(Arel::Nodes::Grouping.new(n[1]))
          else
            raise 'lll'
          end
          n = attributes.shift(2)
        end
        
        node
      elsif attributes.is_a?(Hash)
        expand_from_filter_hash(attributes)
      else
        expand_from_filter_hash({id: attributes})
      end
    end
    
    def expand_from_filter_hash(attributes)
      klass = table.send(:klass)
      
      children = attributes.flat_map do |key, value|
        if custom_filter = klass.filters[key]
          self.instance_exec(klass, table, key, value, &custom_filter[:block])
        elsif column = klass.columns_hash[key.to_s] || klass.columns_hash[key.to_s.split('.').first]
          expand_filter_for_column(key, column, value)
        elsif relation = klass.reflect_on_association(key)
          expand_filter_for_relationship(relation, value)
        elsif key.to_s.ends_with?('_ids') && relation = klass.reflect_on_association(key.to_s.gsub(/_ids$/, 's'))
          expand_filter_for_relationship(relation, {id: value})
        elsif relation = klass.reflect_on_all_associations(:has_and_belongs_to_many).find {|r| r.join_table == key.to_s && value.keys.first.to_s == r.association_foreign_key.to_s }
          expand_filter_for_join_table(relation, value)
        else
          raise ActiveRecord::UnkownFilterError.new("Unkown filter \"#{key}\" for #{klass}.")
        end
      end
      
      children.compact!
      if children.size > 1
        Arel::Nodes::And.new(children)
      else
        children.first
      end
    end
    
    def expand_filter_for_column(key, column, value)
      # Not sure why
      # activerecord/lib/active_record/table_metadata.rb#arel_attribute
      # doesn't work here, something's not working with a
      # Arel::Nodes::TableAlias, would like to go back to it one day
      attribute = if klass = table.send(:klass)
        if Arel::Nodes::TableAlias === table.send(:arel_table)
          klass.arel_attribute(column.name, table.send(:arel_table).left)
        else
          klass.arel_attribute(column.name, table.send(:arel_table))
        end
      else
        table.send(:arel_table)[column.name]
      end

      if column.type == :json || column.type == :jsonb
        names = key.to_s.split('.')
        names.shift
        attribute = attribute.dig(names)
      end
      
      if value.is_a?(Hash)
        nodes = value.map do |subkey, subvalue|
          expand_filter_for_arel_attribute(column, attribute, subkey, subvalue)
        end
        nodes.inject { |c, n| c.nil? ? n : c.and(n) }
      elsif value == nil
        attribute.eq(nil)
      elsif value == true || value == 'true'
        column.type == :boolean ? attribute.eq(true) : attribute.not_eq(nil)
      elsif value == false || value == 'false'
        column.type == :boolean ? attribute.eq(false) : attribute.eq(nil)
      elsif value.is_a?(Array) && !column.array
        attribute.in(value)
      elsif column.type != :json && column.type != :jsonb
        converted_value = column.array ? Array(value) : value
        attribute.eq(converted_value)
      else
        raise ActiveRecord::UnkownFilterError.new("Unkown type for #{column}. (type #{value.class})")
      end
      
    end
    
    def expand_filter_for_arel_attribute(column, attribute, key, value)
      case key.to_sym
      when :contains
        attribute.contains(column.array ? Array(value) : value)
      when :contained_by
        attribute.contained_by(column.array ? Array(value) : value)
      when :equal_to, :eq
        attribute.eq(value)
      when :excludes
        attribute.excludes(Array(value))
      when :greater_than, :gt
        attribute.gt(value)
      when :greater_than_or_equal_to, :gteq, :gte
        attribute.gteq(value)
      when :has_key
        attribute.has_key(value)
      when :has_keys
        attribute.has_keys(*Array(value).map { |x| Arel::Nodes.build_quoted(x) })
      when :has_any_key
        attribute.has_any_key(*Array(value).map { |x| Arel::Nodes.build_quoted(x) })
      when :in
        attribute.in(value)
      when :intersects
        # geometry_value = if value.is_a?(Hash) # GeoJSON
        #   Arel::Nodes::NamedFunction.new('ST_GeomFromGeoJSON', [JSON.generate(value)])
        # elsif # EWKB
        # elsif # WKB
        # elsif # EWKT
        # elsif # WKT
        # end
    
        # TODO us above if to determin if SRID sent
        geometry_value = if value.is_a?(Hash)
          Arel::Nodes::NamedFunction.new('ST_SetSRID', [Arel::Nodes::NamedFunction.new('ST_GeomFromGeoJSON', [Arel::Nodes.build_quoted(JSON.generate(subvalue))]), 4326])
        elsif value[0,1] == "\x00" || value[0,1] == "\x01" || value[0,4] =~ /[0-9a-fA-F]{4}/
          Arel::Nodes::NamedFunction.new('ST_SetSRID', [Arel::Nodes::NamedFunction.new('ST_GeomFromEWKB', [Arel::Nodes.build_quoted(subvalue)]), 4326])
        else
          Arel::Nodes::NamedFunction.new('ST_SetSRID', [Arel::Nodes::NamedFunction.new('ST_GeomFromText', [Arel::Nodes.build_quoted(subvalue)]), 4326])
        end

        Arel::Nodes::NamedFunction.new('ST_Intersects', [attribute, geometry_value])
      when :less_than, :lt
        attribute.lt(value)
      when :less_than_or_equal_to, :lteq, :lte
        attribute.lteq(value)
      when :like, :ilike
        attribute.matches(value)
      when :not, :not_equal, :neq
        attribute.not_eq(value)
      when :not_in
        attribute.not_in(value)
      when :overlaps
        attribute.overlaps(value)
      when :not_overlaps
        attribute.not_overlaps(value)
      when :ts_match
        if value.is_a?(Array)
          attribute.ts_query(*value)
        else
          attribute.ts_query(value)
        end
      when :within
        if value.is_a?(String)
          if /\A[0-9A-F]*\Z/i.match?(value) && (value.start_with?('00') || value.start_with?('01'))
            attribute.within(Arel::Nodes::HexEncodedBinary.new(value))
          else
            attribute.within(Arel::Nodes.build_quoted(value))
          end
        elsif value.is_a?(Hash)
          attribute.within(Arel::Nodes.build_quoted(value))
        else
          raise "Not Supported value for within: #{value.inspect}"
        end
      else
        raise "Not Supported: #{key.to_sym}"
      end
    end
    
    def expand_filter_for_relationship(relation, value)
      case relation.macro
      when :has_many
        if value == true || value == 'true'
          counter_cache_column_name = relation.counter_cache_column || "#{relation.plural_name}_count"
          if relation.active_record.column_names.include?(counter_cache_column_name.to_s)
            return table.arel_attribute(counter_cache_column_name.to_sym).gt(0)
          else
            raise "Not Supported: #{relation.name}"
          end
        elsif value == false || value == 'false'
          counter_cache_column_name = relation.counter_cache_column || "#{relation.plural_name}_count"
          if relation.active_record.column_names.include?(counter_cache_column_name.to_s)
            return table.arel_attribute(counter_cache_column_name.to_sym).eq(0)
          else
            raise "Not Supported: #{relation.name}"
          end
        end
      when :belongs_to
        if value == true || value == 'true'
          return table.arel_attribute(relation.foreign_key).not_eq(nil)
        elsif value == false || value == 'false' || value.nil?
          return table.arel_attribute(relation.foreign_key).eq(nil)
        end
      end
      
      builder = associated_predicate_builder(relation.name.to_sym)
      builder.build_from_filter_hash(value)
    end
    
    def expand_filter_for_join_table(relation, value)
      relation = relation.active_record._reflections[relation.active_record._reflections[relation.name.to_s].send(:delegate_reflection).options[:through].to_s]

      builder = associated_predicate_builder(relation.name.to_sym)
      builder.build_from_filter_hash(value)
    end

  end
end


module ActiveRecord
  class Relation
    class FilterClauseFactory # :nodoc:
      def initialize(klass, predicate_builder)
        @klass = klass
        @predicate_builder = predicate_builder
      end

      def build(filters)
        if filters.is_a?(Hash) || filters.is_a?(Array)
          # attributes = predicate_builder.resolve_column_aliases(filters)
          # attributes = klass.send(:expand_hash_conditions_for_aggregates, attributes)
          # attributes.stringify_keys!
          #
          # attributes, binds = predicate_builder.create_binds(attributes)
          parts = [predicate_builder.build_from_filter_hash(filters)]
        else
          raise ArgumentError, "Unsupported argument type: #{filters.inspect} (#{filters.class})"
        end
        
        WhereClause.new(parts)
      end

      protected

      attr_reader :klass, :predicate_builder
    end
  end
end

class ActiveRecord::Relation
  module Filter

    def initialize(klass, table: klass.arel_table, predicate_builder: klass.predicate_builder, values: {})
      @filters = []
      super
    end
    
    def initialize_copy(other)
      @filters = @filters.deep_dup
      super
    end
    
    def clean_filters(value)
      if value.class.name == 'ActionController::Parameters'.freeze
        value.to_unsafe_h
      elsif value.is_a?(Array)
        value.map { |v| clean_filters(v) }
      else
        value
      end
    end

    def filter(filters)
      filters = clean_filters(filters)
      
      if filters.nil? || filters.empty?
        self
      else
        spawn.filter!(filters)
      end
    end
    
    def filter!(filters)
      js = ActiveRecord::PredicateBuilder.filter_joins(klass, filters)
      js.each { |j| joins!(j) if j.present? }
      @filters << filters
      self
    end
    
    def filter_clause_factory
      @filter_clause_factory ||= FilterClauseFactory.new(klass, predicate_builder)
    end
    
    def build_arel(aliases)
      arel = super
      build_filters(arel)
      arel
    end
    
    def build_filters(manager)
      @filters.each do |filters|
        manager.where(filter_clause_factory.build(filters).ast)
      end
    end

  end
end

module ActiveRecord::SpawnMethods
  def except(*skips)
    r = relation_with values.except(*skips)
    if !skips.include?(:where)
      r.instance_variable_set(:@filters, instance_variable_get(:@filters))
    end
    r
  end
end

ActiveRecord::Relation.prepend(ActiveRecord::Relation::Filter)
ActiveRecord::Base.extend(ActiveRecord::Filter)
