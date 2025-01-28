module ActiveRecord::Filter::RelationExtension

  def initialize(*, **)
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
    js.flatten.each do |j|
      if j.is_a?(String)
        joins!(j)
      elsif j.is_a?(Arel::Nodes::Join)
        joins!(j)
      elsif j.present?
        left_outer_joins!(j)
      end
    end
    @filters << filters
    self
  end

  def filter_clause_factory
    @filter_clause_factory ||= ActiveRecord::Filter::FilterClauseFactory.new(klass, predicate_builder)
  end

  def build_arel(connection, aliases = nil)
    arel = super
    my_alias_tracker = ActiveRecord::Associations::AliasTracker.create(model.connection_pool, table.name, [])
    build_filters(arel, my_alias_tracker)
    arel
  end

  def build_filters(manager, alias_tracker)
    @filters.each do |filters|
      manager.where(filter_clause_factory.build(filters, alias_tracker).ast)
    end
  end

end