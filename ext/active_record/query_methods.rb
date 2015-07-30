module ActiveRecord::QueryMethods
  
  # # TODO: testme and rename to joins?
  # def joined?(assoc)
  #   joined_assocs = joins_values.map{ |i| i.is_a?(Hash) ? i.keys : i.to_sym }.flatten
  #   joined_assocs.include?(assoc)
  # end
  #
  # # TODO: testme and rename to includes?
  # def included?(assoc)
  #   included_assocs = includes_values.map{ |i| i.is_a?(Hash) ? i.keys : i.to_sym }.flatten
  #   included_assocs.include?(assoc)
  # end
  
  # TODO: testme and rename to 
  def references?(assoc)
    references_assocs = references_values.map{ |i| i.is_a?(Hash) ? i.keys : i.to_sym }.flatten
    references_assocs.include?(assoc)
  end
  
end

module ActiveRecord::Querying
  # delegate :joined?, :to => :all
  # delegate :included?, :to => :all
  delegate :references?, :to => :all
end
