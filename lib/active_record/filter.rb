require 'active_record'
require 'arel/extensions'
require 'action_controller/metal/strong_parameters'

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
    
    def self.filter_references(klass, filters)
      if filters.is_a?(Array)
        filters.map { |f| filter_references(klass, f) }.compact
      elsif filters.is_a?(Hash)
        filters.map do |key, value|
          if klass.filters.has_key?(key.to_sym)
            klass.filters.dig(key.to_sym, :joins)
          elsif reflection = klass._reflections[key.to_s]
            if value.is_a?(Hash)
              {key => filter_references(reflection.klass, value)}
            elsif value != true && value != false && value != 'true' && value != 'false' && !value.nil?
              key
            end
          elsif reflection = klass.reflect_on_all_associations(:has_and_belongs_to_many).find {|r| r.join_table == key.to_s && value.keys.first.to_s == r.association_foreign_key.to_s }
            reflection = klass._reflections[klass._reflections[reflection.name.to_s].delegate_reflection.options[:through].to_s]
            {reflection.name => filter_references(reflection.klass, value)}
          end
        end.compact
      end
      
    end
    
    def build_from_filter_hash(attributes, join_dependency)
      if attributes.is_a?(Array)
        node = build_from_filter_hash(attributes.shift, join_dependency)

        n = attributes.shift(2)
        while !n.empty?
          n[1] = build_from_filter_hash(n[1], join_dependency)
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
        expand_from_filter_hash(attributes, join_dependency)
      else
        expand_from_filter_hash({id: attributes}, join_dependency)
      end
    end
    
    def expand_from_filter_hash(attributes, join_dependency)
      klass = table.send(:klass)
      
      children = attributes.flat_map do |key, value|
        if custom_filter = klass.filters[key]
          self.instance_exec(klass, table, key, value, join_dependency, &custom_filter[:block])
        elsif column = klass.columns_hash[key.to_s]
          expand_filter_for_column(column, value)
        elsif relation = klass.reflect_on_association(key)
          expand_filter_for_relationship(relation, value, join_dependency)
        elsif relation = klass.reflect_on_all_associations(:has_and_belongs_to_many).find {|r| r.join_table == key.to_s && value.keys.first.to_s == r.association_foreign_key.to_s }
          expand_filter_for_join_table(relation, value, join_dependency)
        else
          raise ActiveRecord::UnkownFilterError.new("Unkown filter \"#{key}\" for #{klass}.")
        end
      end
      
      if children.size > 1
        Arel::Nodes::And.new(children)
      else
        children.first
      end
    end
    
    def convert_filter_value(column, value)
      caster = table.send(:klass).attribute_types[column.name]
      if value.is_a?(Array) && !column.array
        value.map {|v| caster.cast(v) }
      else
        caster.cast(value)
      end
    end
    
    def expand_filter_for_column(column, value)
      if column.array
        if value.is_a?(Hash)
          nodes = value.map do |key, subvalue|
            converted_value = convert_filter_value(column, subvalue)
            
            case key.to_sym
            when :contains
              table.arel_attribute(column.name).contains(converted_value)
            when :excludes
              table.arel_attribute(column.name).contains(converted_value).not
            when :overlaps
              table.arel_attribute(column.name).overlaps(converted_value)
            else
              raise "Not Supported: #{key.to_sym}"
            end
          end
          nodes.inject { |c, n| c.nil? ? n : c.and(n) }
        else
          table.arel_attribute(column.name).contains(convert_filter_value(column, Array(value)))
        end
        
      else
        if value.is_a?(Hash)
          nodes = value.map do |key, subvalue|
            converted_value = convert_filter_value(column, subvalue)

            case key.to_sym
            when :equal_to, :eq
              table.arel_attribute(column.name).eq(converted_value)
            when :greater_than, :gt
              table.arel_attribute(column.name).gt(converted_value)
            when :less_than, :lt
              table.arel_attribute(column.name).lt(converted_value)
            when :greater_than_or_equal_to, :gteq, :gte
              table.arel_attribute(column.name).gteq(converted_value)
            when :less_than_or_equal_to, :lteq, :lte
              table.arel_attribute(column.name).lteq(converted_value)
            when :in
              table.arel_attribute(column.name).in(converted_value)
            when :not, :not_equal, :neq
              table.arel_attribute(column.name).not_eq(converted_value)
            when :not_in
              table.arel_attribute(column.name).not_in(converted_value)
            when :like, :ilike
              table.arel_attribute(column.name).matches(converted_value)
            when :ts_match
              if converted_value.is_a?(Array)
                table.arel_attribute(column.name).ts_query(*converted_value)
              else
                table.arel_attribute(column.name).ts_query(converted_value)
              end
            when :intersects
              # geometry_value = if value.is_a?(Hash) # GeoJSON
              #   Arel::Nodes::NamedFunction.new('ST_GeomFromGeoJSON', [JSON.generate(value)])
              # elsif # EWKB
              # elsif # WKB
              # elsif # EWKT
              # elsif # WKT
              # end
          
              # TODO us above if to determin if SRID sent
              geometry_value = if subvalue.is_a?(Hash)
                Arel::Nodes::NamedFunction.new('ST_SetSRID', [Arel::Nodes::NamedFunction.new('ST_GeomFromGeoJSON', [Arel::Nodes.build_quoted(JSON.generate(subvalue))]), 4326])
              elsif subvalue[0,1] == "\x00" || subvalue[0,1] == "\x01" || subvalue[0,4] =~ /[0-9a-fA-F]{4}/
                Arel::Nodes::NamedFunction.new('ST_SetSRID', [Arel::Nodes::NamedFunction.new('ST_GeomFromEWKB', [Arel::Nodes.build_quoted(subvalue)]), 4326])
              else
                Arel::Nodes::NamedFunction.new('ST_SetSRID', [Arel::Nodes::NamedFunction.new('ST_GeomFromText', [Arel::Nodes.build_quoted(subvalue)]), 4326])
              end

              Arel::Nodes::NamedFunction.new('ST_Intersects', [table.arel_attribute(column.name), geometry_value])
            else
              raise "Not Supported: #{key.to_sym}"
            end
          end
          nodes.inject {|c, n| c.nil? ? n : c.and(n) }
        elsif value.is_a?(Array)
          table.arel_attribute(column.name).in(convert_filter_value(column, value))
        elsif value == true || value == 'true'
          if column.type == :boolean
            table.arel_attribute(column.name).eq(true)
          else
            table.arel_attribute(column.name).not_eq(nil)
          end
        elsif value == false || value == 'false'
          if column.type == :boolean
            table.arel_attribute(column.name).eq(false)
          else
            table.arel_attribute(column.name).eq(nil)
          end
        elsif value == nil
          table.arel_attribute(column.name).eq(nil)
        # when ''
        #   # TODO support nil. Currently rails params encode nil as empty strings,
        #   # and we can't tell which is desired, so do both
        #   where(table[column].eq(value).or(table[column].eq(nil)))
        elsif table.send(:klass).column_names.include?(column.name.to_s)
          table.arel_attribute(column.name).eq(convert_filter_value(column, value))
        else
          raise ActiveRecord::UnkownFilterError.new("Unkown type for #{column}. (type #{value.class})")
        end
        
      end
    end
    
    def expand_filter_for_relationship(relation, value, join_dependency)
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
      
      if join_dependency
        join_dependency = join_dependency.children.find { |c| c.reflection.name == relation.name }
        builder.table.instance_variable_set(:@arel_table, join_dependency.tables.first)
      end
      
      builder.build_from_filter_hash(value, join_dependency)
    end
    
    def expand_filter_for_join_table(relation, value, join_dependency)
      relation = relation.klass._reflections[relation.klass._reflections[relation.name.to_s].delegate_reflection.options[:through].to_s]

      builder = associated_predicate_builder(relation.name.to_sym)
      if join_dependency
        join_dependency = join_dependency.children.find { |c| c.reflection.name == relation.name }
        builder.table.instance_variable_set(:@arel_table, join_dependency.tables.first)
      end
      builder.build_from_filter_hash(value, join_dependency)
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

      def build(filters, join_dependency)
        binds = []

        if filters.is_a?(Hash) || filters.is_a?(Array)
          # attributes = predicate_builder.resolve_column_aliases(filters)
          # attributes = klass.send(:expand_hash_conditions_for_aggregates, attributes)
          # attributes.stringify_keys!
          #
          # attributes, binds = predicate_builder.create_binds(attributes)
          parts = [predicate_builder.build_from_filter_hash(filters, join_dependency)]
        else
          raise ArgumentError, "Unsupported argument type: #{filters.inspect} (#{filters.class})"
        end
        
        WhereClause.new(parts, binds)
      end

      protected

      attr_reader :klass, :predicate_builder
    end
  end
end

class ActiveRecord::Relation
  module Filter

    def initialize(klass, table, predicate_builder, values = {})
      @filters = []
      super
    end
    
    def filter(filters)
      if filters.is_a?(ActionController::Parameters)
        filters = filters.to_unsafe_h 
      elsif filters.is_a?(Array)
        filters.map! do |f|
          f.is_a?(ActionController::Parameters) ? f.to_unsafe_h : f
        end
      end
      
      if filters.nil? || filters.empty?
        self
      else
        spawn.filter!(filters)
      end
    end
    
    def filter!(filters)
      joins!(ActiveRecord::PredicateBuilder.filter_references(klass, filters))
      @filters << filters
      self
    end
    
    def filter_clause_factory
      @filter_clause_factory ||= FilterClauseFactory.new(klass, predicate_builder)
    end
    
    # filter_clause_factory.build(filters)
    def build_arel
      @join_dependency = nil
      
      arel = super
      build_filters(arel)
      arel
    end

    def build_join_query(manager, buckets, join_type)
      buckets.default = []

      association_joins         = buckets[:association_join]
      stashed_association_joins = buckets[:stashed_join]
      join_nodes                = buckets[:join_node].uniq
      string_joins              = buckets[:string_join].map(&:strip).uniq

      join_list = join_nodes + convert_join_strings_to_ast(manager, string_joins)

      join_dependency = ActiveRecord::Associations::JoinDependency.new(
        @klass,
        association_joins,
        join_list
      )
      
      join_infos = join_dependency.join_constraints stashed_association_joins, join_type

      join_infos.each do |info|
        info.joins.each { |join| manager.from(join) }
        manager.bind_values.concat info.binds
      end

      manager.join_sources.concat(join_list)

      if @klass.connection.class.name != 'ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter'
        @join_dependency = join_dependency
      end
      
      manager
    end
    
    def build_filters(manager)
      @filters.each do |filters|
        manager.where(filter_clause_factory.build(filters, @join_dependency&.join_root).ast)
      end
    end

  end
end

ActiveRecord::Relation.prepend(ActiveRecord::Relation::Filter)
ActiveRecord::Base.extend(ActiveRecord::Filter)