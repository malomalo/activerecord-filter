module ActiveRecord::Filter::AliasTrackerExtension

  def initialize(*, **)
    super
    @relation_trail = {}
  end
  
  def aliased_table_for_relation(trail, arel_table, &block)
    @relation_trail[trail] ||= aliased_table_for(arel_table, &block)
  end
  
end