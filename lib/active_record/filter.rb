require 'active_record'
require 'arel/extensions'

class ActiveRecord::UnkownFilterError < NoMethodError
  attr_reader :klass, :filter

  def initialize(klass, filter)
    @klass = klass
    @filter = filter.to_s
    super("unkown filter #{filter.inspect} for #{klass}.")
  end
end

module ActiveRecord::Filter

  def inherited(subclass)
    super
    subclass.instance_variable_set('@filters', HashWithIndifferentAccess.new)
  end
  
  def filter_on(name, lambda)
    @filters[name] = lambda
  end
  
  def filter(filters, options={})
    resource = all
    return resource unless filters

    if filters.is_a?(Hash) || filters.class.name == "ActionController::Parameters".freeze 
      filters.each do |key, value|
        if @filters[key]
          #TODO add test for this... not sure how rails does this lambda call,
          # do they run it in a context for merge?
          resource = resource.merge( @filters[key].call(value) )
        else
          resource = resource.filter_for(key, value, options)
        end
      end
    elsif filters.is_a?(Array) || filters.is_a?(Integer)
      resource = resource.filter_for(:id, filters, options)
    end

    resource
  end

  def filter_for(key, value, options={})
    column = columns_hash[key.to_s]
    if column && column.array
      all.filter_for_array(key, value, options)
    elsif column
      all.send("filter_for_#{column.type}", key, value, options)
    else
      if relation = reflect_on_association(key)
        self.send("filter_for_#{relation.macro}", relation, value)
      else
        # Custome filter, try to guess based on value
        # raise ActiveRecord::UnkownFilterError.new(self, key)
        if value.is_a?(Hash) || value.class.name == "ActionController::Parameters".freeze 
          all.send("filter_for_#{value.values.first.class.to_s.downcase}", key, value, options)
        else
          all.send("filter_for_#{value.class.to_s.downcase}", key, value, options)
        end
      end
    end
  end

  {
    filter_for_geometry: :itself,
    filter_for_datetime: :to_datetime,
    filter_for_integer: :to_i,
    filter_for_text: :itself,
    filter_for_boolean: :itself,
    filter_for_string: :itself,
    filter_for_uuid: :itself,
    filter_for_decimal: :to_f,
    filter_for_float: :to_f
  }.each_pair do |method_name, send_method|
    define_method(method_name) do |column, value, options={}|
      table = options[:table_alias] ? arel_table.alias(options[:table_alias]) : arel_table
      
      if value.is_a?(Hash) || value.class.name == "ActionController::Parameters".freeze 
        resource = all
        value.each_pair do |key, value|
          converted_value = if value.is_a?(Array)
            value.map { |x| x.try(:send, send_method) }
          else
            value.try(:send, send_method)
          end

          resource = case key.to_sym
          when :equal_to, :eq
            resource.where(table[column].eq(converted_value))
          when :greater_than, :gt
            resource.where(table[column].gt(converted_value))
          when :less_than, :lt
            resource.where(table[column].lt(converted_value))
          when :greater_than_or_equal_to, :gteq, :gte
            resource.where(table[column].gteq(converted_value))
          when :less_than_or_equal_to, :lteq, :lte
            resource.where(table[column].lteq(converted_value))
          when :in
            resource.where(table[column].in(converted_value))
          when :not
            resource.where(table[column].not_eq(converted_value))
          when :not_in
            resource.where(table[column].not_in(converted_value).or(table[column].eq(nil)))
          when :like, :ilike
            resource.where(table[column].matches(converted_value))
          when :ts_match
            if converted_value.is_a?(Array)
              resource.where(table[column].ts_query(*converted_value))
            else
              resource.where(table[column].ts_query(converted_value))
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

            resource.where(Arel::Nodes::NamedFunction.new('ST_Intersects', [table[column], geometry_value]))
          else
            raise "Not Supported: #{key.to_sym}"
          end
        end
        resource
      elsif value.is_a?(Array)
        where(table[column].in(value.map { |x| x.send(send_method) }))
      elsif value == true || value == 'true'
        case method_name # columns_hash[column.to_s].try(:type)
        when :filter_for_boolean then where(table[column].eq(value.try(:send, send_method)))
        else where(table[column].not_eq(nil))
        end
      elsif value == false || value == 'false'
        case method_name # columns_hash[column.to_s].try(:type)
        when :filter_for_boolean then where(table[column].eq(value.try(:send, send_method)))
        else where(table[column].eq(nil))
        end
      # when ''
      #   # TODO support nil. Currently rails params encode nil as empty strings,
      #   # and we can't tell which is desired, so do both
      #   where(table[column].eq(value).or(table[column].eq(nil)))
      else
        where(table[column].eq(value.try(:send, send_method)))
      end
    end
  end
    
  def filter_for_jsonb(column, value, options = {})
    table = options[:table_alias] ? arel_table.alias(options[:table_alias]) : arel_table
    column = table[column]
  
    drill_for_json(column, value, all)
  end
  alias :filter_for_json :filter_for_jsonb
  
  def drill_for_json(column, drill, resource)
    if cast = drill.delete(:cast)
      column = column.cast_as(cast)
    end

    drill.each do |key, value|
      if value.is_a?(Hash) || value.class.name == "ActionController::Parameters".freeze
        resource = drill_for_json(column.key(key), value, resource)
      else
        resource = case key.to_sym
        when :equal, :eq
          resource.where(column.eq(value))
        when :greater_than, :gt
          resource.where(column.gt(value))
        when :less_than, :lt
          resource.where(column.lt(value))
        when :greater_than_or_equal_to, :gteq, :gte
          resource.where(column.gteq(value))
        when :less_than_or_equal_to, :lteq, :lte
          resource.where(column.lteq(value))
        when :not
          resource.where(column.not_eq(value))
        when :has_key
          resource.where(column.has_key(value))
        when :not_in
          resource.where(column.not_in(value).or(column.eq(nil)))
        else
          raise 'Not supported'
        end
      end
    end
    resource
  end

  def filter_for_array(column, value, options={})
    table = options[:table_alias] ? arel_table.alias(options[:table_alias]) : arel_table

    if value.is_a?(Hash) || value.class.name == "ActionController::Parameters".freeze
      resource = all
      value.each_pair do |key, value|
        resource = case key.to_sym
        when :contains
          resource.where(table[column].contains(value))
        when :overlaps
          resource.where(table[column].overlaps(value))
        when :excludes
          resource.where.not(table[column].contains(value))
        # when :not_overlaps
        #   resource.where.not(Arel::Nodes::Overlaps.new(table[column], Arel::Attributes::Array.new(Array(value))))
        else
          raise "Not Supported: #{key.to_sym}"
        end
      end
      resource
    else
      where(table[column].contains(value))
    end
  end

  def filter_for_has_and_belongs_to_many(relation, value)
    resource = all
  
    options = {}
    if resource.klass == relation.klass
      options[:table_alias] = "#{relation.name}_#{relation.klass.table_name}"
    end
  
    if value.is_a?(Hash) || value.class.name == "ActionController::Parameters".freeze
      resource = resource.joins(relation.name) #if !resource.references?(relation.name)
      resource = resource.merge(relation.klass.filter(value, options))
    elsif value.is_a?(Integer)
      resource = resource.joins(relation.name) #if !resource.references?(relation.name)
      resource = resource.merge(relation.klass.filter(value, options))
    elsif value.is_a?(Array)
      resource = resource.joins(relation.name) #if !resource.references?(relation.name)
      resource = resource.merge(relation.klass.filter(value, options))
    else
      raise 'Not supported'
    end

    resource
  end

  def filter_for_has_many(relation, value)
    resource = all

    if value.is_a?(Hash) || value.class.name == "ActionController::Parameters".freeze 
      if relation.options[:through] && !relation.options[:source_type]
        resource = resource.joins(relation.options[:through] => relation.source_reflection_name)
      else
        resource = resource.joins(relation.name) # if !resource.joined?(relation.name)
      end
      resource = resource.merge(relation.klass.filter(value))
    elsif value.is_a?(Array) || value.is_a?(Integer)
      resource = filter_for_has_many(relation, {:id => value})
    elsif value == true || value == 'true'
      counter_cache_column_name = relation.counter_cache_column || "#{relation.plural_name}_count"
      if resource.column_names.include?(counter_cache_column_name)
        resource = resource.where(resource.arel_table[counter_cache_column_name.to_sym].gt(0))
      else
        raise 'Not supported'
      end
    elsif value == false || value == 'false'
      # TODO if the has_many relationship has counter_cache true can just use counter_cache_column method
      counter_cache_column_name = relation.counter_cache_column || "#{relation.plural_name}_count"
      if resource.column_names.include?(counter_cache_column_name)
        resource = resource.where(resource.arel_table[counter_cache_column_name.to_sym].eq(0))
      else
        raise 'Not supported'
      end
    else
      raise 'Not supported'
    end

    resource
  end
  alias_method :filter_for_has_one, :filter_for_has_many

  def filter_for_belongs_to(relation, value)
    resource = all

    if value.is_a?(Array) || value.is_a?(Integer) || value.is_a?(NilClass)
      resource = resource.where(:"#{relation.foreign_key}" => value)
    elsif value == true || value == 'true'
      resource = resource.where(resource.arel_table[:"#{relation.foreign_key}"].not_eq(nil))
    elsif value == false || value == 'false'
      resource = resource.where(resource.arel_table[:"#{relation.foreign_key}"].eq(nil))
    elsif value.is_a?(Hash) || value.class.name == "ActionController::Parameters".freeze 
      if relation.polymorphic?
        raise 'no :as' if !value[:as]
        v = value.dup
        klass = v.delete(:as).classify.constantize
        t1 = resource.arel_table
        t2 = klass.arel_table
        resource = resource.joins(t1.join(t2).on(
          t2[:id].eq(t1["#{relation.name}_id"]).and(t1["#{relation.name}_type"].eq(klass.name))
        ).join_sources.first)
        resource = resource.merge(klass.filter(v))
      else
        resource = resource.joins(relation.name) # if !resource.references?(relation.name)
        resource = resource.merge(relation.klass.filter(value))
      end
    else
      if value.is_a?(String) && value =~ /\A\d+\Z/
        resource = resource.where(:"#{relation.foreign_key}" => value.to_i)
      else
        raise 'Not supported'
      end
    end
    resource
  end

end

ActiveRecord::Base.extend(ActiveRecord::Filter)