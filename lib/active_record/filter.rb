# frozen_string_literal: true

require 'active_record'
require 'arel/extensions'
require 'active_record/filter/unkown_filter_error'

module ActiveRecord::Filter

  autoload :QueryMethodsExtension, 'active_record/filter/query_methods_extension'
  autoload :AliasTrackerExtension, 'active_record/filter/alias_tracker_extension'
  autoload :FilterClauseFactory, 'active_record/filter/filter_clause_factory'
  autoload :RelationExtension, 'active_record/filter/relation_extension'
  autoload :PredicateBuilderExtension, 'active_record/filter/predicate_builder_extension'
  autoload :SpawnMethodsExtension, 'active_record/filter/spawn_methods_extension'
  
  delegate :filter, :filter_for, to: :all

  def inherited(subclass)
    super
    subclass.instance_variable_set('@filters', HashWithIndifferentAccess.new)
  end

  def filters
    @filters
  end

  def filter_on(name, dependent_joins=nil, &block)
    @filters[name.to_s] = { joins: dependent_joins, block: block }
  end

end


ActiveRecord::QueryMethods.prepend(ActiveRecord::Filter::QueryMethodsExtension)
ActiveRecord::Base.extend(ActiveRecord::Filter)
ActiveRecord::Relation.prepend(ActiveRecord::Filter::RelationExtension)
ActiveRecord::SpawnMethods.extend(ActiveRecord::Filter::SpawnMethodsExtension)
ActiveRecord::PredicateBuilder.include(ActiveRecord::Filter::PredicateBuilderExtension)
ActiveRecord::Associations::AliasTracker.prepend(ActiveRecord::Filter::AliasTrackerExtension)