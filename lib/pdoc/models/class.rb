module PDoc
  module Models
    class Class < Entity
      include Container
      attr_accessor :constructor
      attr_accessor :superclass
      def attach_to_parent(parent)
        parent.classes << self
      end
      
      def subclasses
        @subclasses ||= []
      end
      
      def subclasses?
        @subclasses && !@subclasses.empty?
      end
    end
  end
end
