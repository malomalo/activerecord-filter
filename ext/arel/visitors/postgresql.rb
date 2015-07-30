module Arel
  module Visitors
    class PostgreSQL
      private
      
      def visit_Arel_Nodes_Contains o, collector
        visit o.left, collector
        collector << ' @> '
        visit o.right, collector
      end

      def visit_Arel_Nodes_Overlaps o, collector
        visit o.left, collector
        collector << ' && '
        visit o.right, collector
      end
      
      def visit_Arel_Attributes_Array o, collector
        type = if !o.relation[0]
          ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array.new(nil)
        else
          ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array.new("ActiveRecord::Type::#{o.relation[0].class}".constantize.new)
        end

        collector << quote(type.type_cast_for_database(o.relation))
      end
      
    end
  end
end
