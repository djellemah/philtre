module Philtre
  # constructs a Hash from predicate (ie eq, gt, gte) => block
  # which returns Sequel::SQL::Expression or something that can
  # become one through Sequel.expr, eg {year: 2013}
  class PredicateDsl < Module
    def initialize( &bloc )
      @predicates = {}
      module_eval &bloc if bloc
    end

    # each meth is a predicate, args is a set of alternatives
    # and the block is to create the expression for that predicate.
    def method_missing(meth, *args, &bloc)
      predicates[meth] = bloc
      # and set up alternatives
      args.each{|arg| predicates[arg] = bloc }

      # store them in the module, just for fun
      send :define_method, meth, &bloc
      args.each{|arg| send :alias_method, arg, meth }
    end

    def self.predicalize( &bloc )
      rv = new( &bloc )
      rv.predicates
    end

    def method_added( meth )
      # puts meth
    end

    attr_reader :predicates
  end
end
