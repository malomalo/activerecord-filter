require "active_support/concern"

module ActiveRecord::Filter::PredicateBuilderExtension

  extend ActiveSupport::Concern
  
  class_methods do
    def filter_joins(klass, filters)
      custom = []
      [build_filter_joins(klass, filters, [], custom), custom]
    end

    def build_filter_joins(klass, filters, relations=[], custom=[])
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
           elsif reflection = klass._reflections[key.to_sym]
            if value.is_a?(Hash)
              relations << if reflection.polymorphic?
                value = value.dup
                join_klass = value.delete(:as).safe_constantize
                right_table = join_klass.arel_table
                left_table = reflection.active_record.arel_table

                on = right_table[join_klass.primary_key].
                  eq(left_table[reflection.foreign_key]).
                  and(left_table[reflection.foreign_type].eq(join_klass.name))

                cross_boundry_joins = join_klass.left_outer_joins(ActiveRecord::PredicateBuilder.filter_joins(join_klass, value).flatten).send(:build_joins, [])

                [
                  left_table.join(right_table, Arel::Nodes::OuterJoin).on(on).join_sources,
                  cross_boundry_joins
                ]
              else
                {
                  key => build_filter_joins(reflection.klass, value, [], custom)
                }
              end
            elsif value.is_a?(Array)
              value.each do |v|
                relations << {
                  key => build_filter_joins(reflection.klass, v, [], custom)
                }
              end
            elsif value != true && value != false && value != 'true' && value != 'false' && !value.nil?
              relations << key
            end
          elsif !klass.columns_hash.has_key?(key.to_s) && key.to_s.end_with?('_ids') && reflection = klass._reflections[key.to_s.gsub(/_ids$/, 's').to_sym]
            relations << reflection.name
          elsif reflection = klass.reflect_on_all_associations(:has_and_belongs_to_many).find {|r| r.join_table == key.to_s && value.keys.first.to_s == r.association_foreign_key.to_s }
            reflection = klass._reflections[klass._reflections[reflection.name].send(:delegate_reflection).options[:through]]
            relations << { reflection.name => build_filter_joins(reflection.klass, value) }
          else
            {key => value}
          end
        end
      end

      relations
    end
  end
  
  def build_from_filter_hash(attributes, relation_trail, alias_tracker)
    if attributes.is_a?(Array)
      node = build_from_filter_hash(attributes.shift, relation_trail, alias_tracker)

      n = attributes.shift(2)
      while !n.empty?
        n[1] = build_from_filter_hash(n[1], relation_trail, alias_tracker)
        if n[0] == 'AND'
          if node.is_a?(Arel::Nodes::And)
            node.children.push(n[1])
          else
            node = node.and(n[1])
          end
        elsif n[0] == 'OR'
          node = Arel::Nodes::Grouping.new(node).or(Arel::Nodes::Grouping.new(n[1]))
        elsif !n[0].is_a?(String)
          n[0] = build_from_filter_hash(n[0], relation_trail, alias_tracker)
          if node.is_a?(Arel::Nodes::And)
            node.children.push(n[0])
          else
            node = node.and(n[0])
          end
        else
          raise 'lll'
        end
        n = attributes.shift(2)
      end

      node
    elsif attributes.is_a?(Hash)
      expand_from_filter_hash(attributes, relation_trail, alias_tracker)
    else
      expand_from_filter_hash({id: attributes}, relation_trail, alias_tracker)
    end
  end

  def expand_from_filter_hash(attributes, relation_trail, alias_tracker)
    klass = table.send(:klass)

    children = attributes.flat_map do |key, value|
      if custom_filter = klass.filters[key]
        self.instance_exec(klass, table, key, value, relation_trail, alias_tracker, &custom_filter[:block])
      elsif column = klass.columns_hash[key.to_s] || klass.columns_hash[key.to_s.split('.').first]
        expand_filter_for_column(key, column, value, relation_trail)
      elsif relation = klass.reflect_on_association(key)
        expand_filter_for_relationship(relation, value, relation_trail, alias_tracker)
      elsif key.to_s.end_with?('_ids') && relation = klass.reflect_on_association(key.to_s.gsub(/_ids$/, 's'))
        expand_filter_for_relationship(relation, {id: value}, relation_trail, alias_tracker)
      elsif relation = klass.reflect_on_all_associations(:has_and_belongs_to_many).find {|r| r.join_table == key.to_s && value.keys.first.to_s == r.association_foreign_key.to_s }
        expand_filter_for_join_table(relation, value, relation_trail, alias_tracker)
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

  def expand_filter_for_column(key, column, value, relation_trail)
    attribute = table.arel_table[column.name]
    relation_trail.each do |rt|
      attribute = Arel::Attributes::Relation.new(attribute, rt)
    end

    if column.type == :json || column.type == :jsonb
      names = key.to_s.split('.')
      names.shift
      attribute = attribute.dig(names)
    elsif column.type == :geometry
      value = if value.is_a?(Hash)
        value.transform_values { |v| geometry_from_value(v) }
      else
        geometry_from_value(value)
      end
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

  # TODO determine if SRID sent and cast to correct SRID
  def geometry_from_value(value)
    if value.is_a?(Array)
      value.map { |g| geometry_from_value(g) }
    elsif value.is_a?(Hash)
      Arel::Nodes::NamedFunction.new('ST_SetSRID', [Arel::Nodes::NamedFunction.new('ST_GeomFromGeoJSON', [Arel::Nodes.build_quoted(JSON.generate(value))]), 4326])
    elsif value[0,1] == "\x00" || value[0,1] == "\x01"
      Arel::Nodes::NamedFunction.new('ST_SetSRID', [Arel::Nodes::NamedFunction.new('ST_GeomFromEWKB', [Arel::Nodes::BinaryValue.new(value)]), 4326])
    elsif value[0,4] =~ /[0-9a-fA-F]{4}/
      Arel::Nodes::NamedFunction.new('ST_SetSRID', [Arel::Nodes::NamedFunction.new('ST_GeomFromEWKB', [Arel::Nodes::HexEncodedBinaryValue.new(value)]), 4326])
    else
      Arel::Nodes::NamedFunction.new('ST_SetSRID', [Arel::Nodes::NamedFunction.new('ST_GeomFromText', [Arel::Nodes.build_quoted(value)]), 4326])
    end
  end
  
  def expand_filter_for_arel_attribute(column, attribute, key, value)
    case key.to_sym
    when :contains
      case column.type
      when :geometry
        Arel::Nodes::NamedFunction.new('ST_Contains', [attribute, value])
      else
        attribute.contains(Arel::Nodes::Casted.new(column.array ? Array(value) : value, attribute))
      end
    when :contained_by
      attribute.contained_by(Arel::Nodes::Casted.new(column.array ? Array(value) : value, attribute))
    when :equal_to, :eq
      case column.type
      when :geometry
        Arel::Nodes::NamedFunction.new('ST_Equals', [attribute, value])
      else
        attribute.eq(value)
      end
    when :excludes
      attribute.excludes(Arel::Nodes::Casted.new(column.array ? Array(value) : value, attribute))
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
      attribute.intersects(value)
    when :less_than, :lt
      attribute.lt(value)
    when :less_than_or_equal_to, :lteq, :lte
      attribute.lteq(value)
    when :like
      attribute.matches(value, nil, true)
    when :ilike
      attribute.matches(value, nil, false)
    when :not, :not_equal, :neq
      attribute.not_eq(value)
    when :not_in
      attribute.not_in(value)
    when :overlaps
      case column.type
      in :geometry
        attribute.overlaps(value)
      else
        attribute.overlaps(Arel::Nodes::Casted.new(column.array ? Array(value) : value, attribute))
      end
    when :not_overlaps
      attribute.not_overlaps(value)
    when :ts_match
      if value.is_a?(Array)
        attribute.ts_query(*value)
      else
        attribute.ts_query(value)
      end
    when :within
      attribute.within(Arel::Nodes.build_quoted(value))
    else
      raise "Not Supported: #{key.to_sym} on column \"#{column.name}\" of type #{column.type}"
    end
  end

  def expand_filter_for_relationship(relation, value, relation_trail, alias_tracker)
    case relation.macro
    when :has_many
      if value == true || value == 'true'
        counter_cache_column_name = relation.counter_cache_column || "#{relation.plural_name}_count"
        if relation.active_record.column_names.include?(counter_cache_column_name.to_s)
          return table.arel_table[counter_cache_column_name.to_sym].gt(0)
        else
          raise "Not Supported: #{relation.name}"
        end
      elsif value == false || value == 'false'
        counter_cache_column_name = relation.counter_cache_column || "#{relation.plural_name}_count"
        if relation.active_record.column_names.include?(counter_cache_column_name.to_s)
          return table.arel_table[counter_cache_column_name.to_sym].eq(0)
        else
          raise "Not Supported: #{relation.name}"
        end
      end

    when :belongs_to
      if value == true || value == 'true'
        return table.arel_table[relation.foreign_key].not_eq(nil)
      elsif value == false || value == 'false' || value.nil?
        return table.arel_table[relation.foreign_key].eq(nil)
      end
    end

    if relation.polymorphic?
      value = value.dup
      klass = value.delete(:as).safe_constantize

      builder = self.class.new(ActiveRecord::TableMetadata.new(
        klass,          
        alias_tracker.aliased_table_for_relation(relation_trail + ["#{klass.table_name}_as_#{relation.name}"], klass.arel_table) { klass.arel_table.name },
        relation
      ))
      builder.build_from_filter_hash(value, relation_trail + ["#{klass.table_name}_as_#{relation.name}"], alias_tracker)
    else
      builder = self.class.new(ActiveRecord::TableMetadata.new(
        relation.klass,
        alias_tracker.aliased_table_for_relation(relation_trail + [relation.name], relation.klass.arel_table) { relation.alias_candidate(table.arel_table.name || relation.klass.arel_table) },
        relation
      ))
      builder.build_from_filter_hash(value, relation_trail + [relation.name], alias_tracker)
    end

  end


  def expand_filter_for_join_table(relation, value, relation_trail, alias_tracker)
    relation = relation.active_record._reflections[relation.active_record._reflections[relation.name].send(:delegate_reflection).options[:through]]
    builder = self.class.new(ActiveRecord::TableMetadata.new(
      relation.klass,
      alias_tracker.aliased_table_for_relation(relation_trail + [relation.name], relation.klass.arel_table) { relation.alias_candidate(table.arel_table.name || relation.klass.arel_table) },
      relation
    ))
    builder.build_from_filter_hash(value, relation_trail + [relation.name], alias_tracker)
  end

end