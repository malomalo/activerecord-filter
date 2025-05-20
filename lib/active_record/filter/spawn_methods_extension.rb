# frozen_string_literal: true

module ActiveRecord::Filter::SpawnMethodsExtension

  def except(*skips)
    r = relation_with values.except(*skips)
    if !skips.include?(:where)
      r.instance_variable_set(:@filters, instance_variable_get(:@filters))
    end
    r
  end

end