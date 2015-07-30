class ActiveRecord::UnkownFilterError < NoMethodError
  attr_reader :klass, :filter

  def initialize(klass, filter)
    @klass = klass
    @filter = filter.to_s
    super("unkown filter #{filter.inspect} for #{klass}.")
  end
end