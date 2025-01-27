module ActiveRecord::Filter::QueryMethodsExtension
private
  def build_join_buckets
    buckets = Hash.new { |h, k| h[k] = [] }

    unless left_outer_joins_values.empty?
      stashed_left_joins = []
      left_joins = select_named_joins(left_outer_joins_values, stashed_left_joins) do |left_join|
        if left_join.is_a?(ActiveRecord::QueryMethods::CTEJoin)
          buckets[:join_node] << build_with_join_node(left_join.name, Arel::Nodes::OuterJoin)
# Add this elsif becasuse PR https://github.com/rails/rails/pull/46843
# Changed a line https://github.com/rails/rails/blob/ae2983a75ca658d84afa414dea8eaf1cca87aa23/activerecord/lib/active_record/relation/query_methods.rb#L1769
# that was probably a bug beforehand but allowed nodes to be joined
# which I think was and still is supported?
        elsif left_join.is_a?(Arel::Nodes::OuterJoin)
          buckets[:join_node] << left_join
        else
          raise ArgumentError, "only Hash, Symbol and Array are allowed"
        end
      end

      if joins_values.empty?
        buckets[:named_join] = left_joins
        buckets[:stashed_join] = stashed_left_joins
        return buckets, Arel::Nodes::OuterJoin
      else
        stashed_left_joins.unshift construct_join_dependency(left_joins, Arel::Nodes::OuterJoin)
      end
    end

    joins = joins_values.dup
    if joins.last.is_a?(ActiveRecord::Associations::JoinDependency)
      stashed_eager_load = joins.pop if joins.last.base_klass == model
    end

    joins.each_with_index do |join, i|
      joins[i] = Arel::Nodes::StringJoin.new(Arel.sql(join.strip)) if join.is_a?(String)
    end

    while joins.first.is_a?(Arel::Nodes::Join)
      join_node = joins.shift
      if !join_node.is_a?(Arel::Nodes::LeadingJoin) && (stashed_eager_load || stashed_left_joins)
        buckets[:join_node] << join_node
      else
        buckets[:leading_join] << join_node
      end
    end

    buckets[:named_join] = select_named_joins(joins, buckets[:stashed_join]) do |join|
      if join.is_a?(Arel::Nodes::Join)
        buckets[:join_node] << join
      elsif join.is_a?(CTEJoin)
        buckets[:join_node] << build_with_join_node(join.name)
      else
        raise "unknown class: %s" % join.class.name
      end
    end

    buckets[:stashed_join].concat stashed_left_joins if stashed_left_joins
    buckets[:stashed_join] << stashed_eager_load if stashed_eager_load

    return buckets, Arel::Nodes::InnerJoin
  end
  
end