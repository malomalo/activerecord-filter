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
  
  def filter_on(name, lambda)
    @filters[name] = lambda
  end

end

module ActiveRecord::Filter
  module Relation

    def filter(filters, options={})
      if filters.nil? || filters.empty?
        self
      else
        spawn.filter!(@klass, filters, options)
      end
    end
    
    def filter!(klass, filters, options={})
      @filter_join_tables = {}
      options[:join_trail] = []
      nodes = filter_nodes(klass, filters, options)
      if nodes
        where!(nodes)
      end
      self
    end
    
    def filter_nodes(klass, filters, options={})
      case filters
      when Hash, ActionController::Parameters
        node = nil
        filters.each do |key, value|
          if klass.filters[key]
            #TODO add test for this... not sure how rails does this lambda call,
            # do they run it in a context for merge?
            merge!( klass.filters[key].call(value) )
            nil
          else
            x = filter_for(klass, key, value, options)
            node = (node.nil? ? x : node.and(x))
          end
        end
        node
      when Array
        node = filter_nodes(klass, filters.shift, options)
        
        n = filters.shift(2)
        while !n.empty?
          if n[0] == 'AND'
            if node.is_a?(Arel::Nodes::And)
              node.children.push(filter_nodes(klass, n[1], options))
            else
              node = node.and(filter_nodes(klass, n[1], options))
            end
          elsif n[0] == 'OR'
            node = Arel::Nodes::Grouping.new(node).or(Arel::Nodes::Grouping.new(filter_nodes(klass, n[1], options)))
          else
            raise 'lll'
          end
          n = filters.shift(2)
        end
        node
      when Integer
        filter_for(klass, klass.primary_key, filters, options)
      end
    end

    def filter_for(klass, key, value, options={})
      column = klass.columns_hash[key.to_s]

      if column && column.array
        filter_for_array(klass, key, value, options)
      elsif column
        self.send("filter_for_#{column.type}", klass, key, value, options)
      elsif relation = klass.reflect_on_association(key)
        self.send("filter_for_#{relation.macro}", klass, relation, value, options)
      else
        raise ActiveRecord::UnkownFilterError.new("Unkown filter \"#{key}\" for #{self}.")
      end
    end

    {
      filter_for_geometry: :itself,
      filter_for_datetime: :to_datetime,
      filter_for_integer: :to_i,
      filter_for_fixnum: :to_i,
      filter_for_text: :itself,
      filter_for_boolean: :itself,
      filter_for_string: :itself,
      filter_for_uuid: :itself,
      filter_for_decimal: :to_f,
      filter_for_float: :to_f
    }.each_pair do |method_name, send_method|
      define_method(method_name) do |klass, column, value, options={}|
        table = filter_table(klass, options)

        if value.is_a?(Hash) || value.class.name == "ActionController::Parameters".freeze
          nodes = []
          value.each_pair do |key, value|
            converted_value = if value.is_a?(Array)
              value.map { |x| x.try(:send, send_method) }
            else
              value.try(:send, send_method)
            end

            nodes << case key.to_sym
            when :equal_to, :eq
              table[column].eq(converted_value)
            when :greater_than, :gt
              table[column].gt(converted_value)
            when :less_than, :lt
              table[column].lt(converted_value)
            when :greater_than_or_equal_to, :gteq, :gte
              table[column].gteq(converted_value)
            when :less_than_or_equal_to, :lteq, :lte
              table[column].lteq(converted_value)
            when :in
              table[column].in(converted_value)
            when :not
              table[column].not_eq(converted_value)
            when :not_in
              table[column].not_in(converted_value)
            when :like, :ilike
              table[column].matches(converted_value)
            when :ts_match
              if converted_value.is_a?(Array)
                table[column].ts_query(*converted_value)
              else
                table[column].ts_query(converted_value)
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
              geometry_value = if value.is_a?(Hash) || value.class.name == "ActionController::Parameters".freeze
                Arel::Nodes::NamedFunction.new('ST_SetSRID', [Arel::Nodes::NamedFunction.new('ST_GeomFromGeoJSON', [Arel::Nodes.build_quoted(JSON.generate(value))]), 4326])
              elsif value[0,1] == "\x00" || value[0,1] == "\x01" || value[0,4] =~ /[0-9a-fA-F]{4}/
                Arel::Nodes::NamedFunction.new('ST_SetSRID', [Arel::Nodes::NamedFunction.new('ST_GeomFromEWKB', [Arel::Nodes.build_quoted(value)]), 4326])
              else
                Arel::Nodes::NamedFunction.new('ST_SetSRID', [Arel::Nodes::NamedFunction.new('ST_GeomFromText', [Arel::Nodes.build_quoted(value)]), 4326])
              end

              Arel::Nodes::NamedFunction.new('ST_Intersects', [table[column], geometry_value])
            else
              raise "Not Supported: #{key.to_sym}"
            end
          end
          nodes.inject {|c, n| c.nil? ? n : c.and(n) }
        elsif value.is_a?(Array)
          table[column].in(value.map { |x| x.send(send_method) })
        elsif value == true || value == 'true'
          case method_name # columns_hash[column.to_s].try(:type)
          when :filter_for_boolean
            table[column].eq(value.try(:send, send_method))
          else
            table[column].not_eq(nil)
          end
        elsif value == false || value == 'false'
          case method_name # columns_hash[column.to_s].try(:type)
          when :filter_for_boolean
            table[column].eq(value.try(:send, send_method))
          else
            table[column].eq(nil)
          end
        elsif value == nil
          table[column].eq(nil)
        # when ''
        #   # TODO support nil. Currently rails params encode nil as empty strings,
        #   # and we can't tell which is desired, so do both
        #   where(table[column].eq(value).or(table[column].eq(nil)))
        elsif value.respond_to?(send_method)
          table[column].eq(value.try(:send, send_method))
        else
          raise ActiveRecord::UnkownFilterError.new("Unkown type for #{column}. (type #{value.class})")
        end
      end
    end
    
    def filter_for_jsonb(klass, column, value, options = {})
      table = options[:table_alias] ? klass.arel_table.alias(options[:table_alias]) : klass.arel_table
  
      drill_for_json(klass, table[column], value, all, 'jsonb')
    end
  
    def filter_for_json(klass, column, value, options = {})
      table = options[:table_alias] ? klass.arel_table.alias(options[:table_alias]) : klass.arel_table
  
      drill_for_json(klass, table[column], value, 'json')
    end
  
    def drill_for_json(klass, column, drill, cast)
      nodes = []
    
      drill.each do |key, value|
        if value.is_a?(Hash) || value.class.name == "ActionController::Parameters".freeze
          nodes << drill_for_json(klass, column.key(key), value, cast)
        else
          value = Arel::Attributes::Cast.new(Arel::Nodes::Quoted.new(value.to_s), cast)
        
          nodes << case key.to_sym
          when :equal, :eq
            column.eq(value)
          when :greater_than, :gt
            column.gt(value)
          when :less_than, :lt
            column.lt(value)
          when :greater_than_or_equal_to, :gteq, :gte
            column.gteq(value)
          when :less_than_or_equal_to, :lteq, :lte
            column.lteq(value)
          when :not
            column.not_eq(value)
          when :has_key
            column.has_key(value)
          when :not_in
            column.not_in(value)
          else
            raise 'Not supported'
          end
        end
      end
      nodes.inject {|c, n| c.nil? ? n : c.and(n) }
    end

    def filter_for_array(klass, column, value, options={})
      table = options[:table_alias] ? klass.arel_table.alias(options[:table_alias]) : klass.arel_table

      if value.is_a?(Hash) || value.class.name == "ActionController::Parameters".freeze
        nodes = []
        value.each_pair do |key, value|
          nodes << case key.to_sym
          when :contains
            table[column].contains(value)
          when :overlaps
            table[column].overlaps(value)
          when :excludes
            raise 'todo'
            # resource.where.not(table[column].contains(value))
          # when :not_overlaps
          #   resource.where.not(Arel::Nodes::Overlaps.new(table[column], Arel::Attributes::Array.new(Array(value))))
          else
            raise "Not Supported: #{key.to_sym}"
          end
        end
        nodes.inject {|c, n| c.nil? ? n : c.and(n) }
      else
        table[column].contains(value)
      end
    end
    
    def filter_joins!(klass, relation, value, options)
      puts relation.name, value.inspect
      table_a = if options[:join_trail].empty?
        klass.arel_table
      else
        @filter_join_tables[options[:join_trail].join('-')]
      end
      
      options[:join_trail] << relation.name
      
      b_key = options[:join_trail].join('-')
      return @filter_join_tables[b_key] if @filter_join_tables.has_key?(b_key)
      
      table_b = if relation.macro == :belongs_to && relation.polymorphic?
        value[:type].arel_table
      else
        relation.klass.arel_table
      end
      
      table_b = table_b.alias(b_key) unless table_b.name == b_key
      @filter_join_tables[b_key] = table_b
      
      join = case relation.macro
      when :has_many
        Arel::Nodes::InnerJoin.new(table_b, Arel::Nodes::On.new(table_b[relation.foreign_key].eq(table_a[relation.active_record_primary_key])))
      when :belongs_to
        if relation.polymorphic?
          on = table_b[relation.active_record_primary_key].eq(table_a[relation.foreign_key])
          on = on.and(table_a[relation.foreign_type].eq(value[:type]))
          Arel::Nodes::InnerJoin.new(table_b, Arel::Nodes::On.new(on))
        else
          Arel::Nodes::InnerJoin.new(table_b, Arel::Nodes::On.new(table_b[relation.active_record_primary_key].eq(table_a[relation.foreign_key])))
        end
      when :has_and_belongs_to_many
        Arel::Nodes::InnerJoin.new(table_b, Arel::Nodes::On.new(table_b[relation.active_record_primary_key].eq(table_a[relation.association_foreign_key])))
      end
      joins!(join)
      
      table_b
    end
    
    def filter_table(klass, options)
      if options[:join_trail].nil? || options[:join_trail].empty?
        klass.arel_table
      else
        @filter_join_tables[options[:join_trail].join('-')]
      end
    end
    
    def filter_for_has_and_belongs_to_many(klass, relation, value, options={})

      join_relation_name = klass.model_name.plural.gsub("::".freeze, "_".freeze) + "_" + relation.name.to_s
      if value.is_a?(Integer)
        join_table = filter_joins!(klass, klass._reflections[join_relation_name], value, options)
        join_table[relation.association_foreign_key].eq(value)
      elsif value == true || value == 'true'
        join_table = filter_joins!(klass, klass._reflections[join_relation_name], value, options)
        join_table[relation.association_foreign_key].not_eq(nil)
      elsif value == false || value == 'false'
        join_table = filter_joins!(klass, klass._reflections[join_relation_name], value, options)
        join_table[relation.association_foreign_key].eq(nil)
      elsif value.is_a?(Hash) || value.class.name == "ActionController::Parameters".freeze

        filter_joins!(klass, klass._reflections[join_relation_name], value, options)
        filter_joins!(klass, relation, value, options)
        filter_nodes(relation.klass, value, options)
      else
        raise 'Not supported'
      end
    end

    def filter_for_has_many(klass, relation, value, options=nil)
      if value.is_a?(Hash) || value.class.name == "ActionController::Parameters".freeze
        filter_joins!(klass, relation, value, options)
        filter_nodes(relation.klass, value, options)
      elsif value == true || value == 'true'
        counter_cache_column_name = relation.counter_cache_column || "#{relation.plural_name}_count"
        if klass.column_names.include?(counter_cache_column_name)
          table[counter_cache_column_name.to_sym].gt(0)
        else
          raise 'Not supported'
        end
      elsif value == false || value == 'false'
        # TODO if the has_many relationship has counter_cache true can just use counter_cache_column method
        counter_cache_column_name = relation.counter_cache_column || "#{relation.plural_name}_count"
        if klass.column_names.include?(counter_cache_column_name)
          table[counter_cache_column_name.to_sym].eq(0)
        else
          raise 'Not supported'
        end
      else
        raise 'Not supported'
      end
    end
    alias_method :filter_for_has_one, :filter_for_has_many

    def filter_for_belongs_to(klass, relation, value, options={})
      if connection.class.name == 'ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter'
        options[:table_alias] = klass.relation.name
      end
      table = filter_table(klass, options)

      if value.is_a?(Array) || value.is_a?(Integer) || value.is_a?(NilClass)
        table[relation.foreign_key].eq(value)
      elsif value == true || value == 'true'
        table[relation.foreign_key].not_eq(nil)
      elsif value == false || value == 'false'
        table[relation.foreign_key].eq(nil)
      elsif value.is_a?(Hash) || value.class.name == "ActionController::Parameters".freeze
        if relation.polymorphic?
          raise 'no :type for polymorphic filter' if !value[:type]
          value[:type] = value[:type].classify.constantize
          filter_joins!(klass, relation, value, options)
          filter_nodes(value.delete(:type), value, options)
        else
          filter_joins!(klass, relation, value, options)
          filter_nodes(relation.klass, value, options)
        end

      else
        if value.is_a?(String) && value =~ /\A\d+\Z/
          table[:"#{relation.foreign_key}"].eq(value)
        else
          raise 'Not supported'
        end
      end
    end

  end
end

ActiveRecord::Relation.include(ActiveRecord::Filter::Relation)
ActiveRecord::Base.extend(ActiveRecord::Filter)
