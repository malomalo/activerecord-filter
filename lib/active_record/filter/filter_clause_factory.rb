class ActiveRecord::Filter::FilterClauseFactory

  def initialize(klass, predicate_builder)
    @klass = klass
    @predicate_builder = predicate_builder
  end

  def build(filters, alias_tracker)
    if filters.is_a?(Hash) || filters.is_a?(Array)
      parts = [predicate_builder.build_from_filter_hash(filters, [], alias_tracker)]
    else
      raise ArgumentError, "Unsupported argument type: #{filters.inspect} (#{filters.class})"
    end

    ActiveRecord::Relation::WhereClause.new(parts)
  end

  protected

  attr_reader :klass, :predicate_builder

end
