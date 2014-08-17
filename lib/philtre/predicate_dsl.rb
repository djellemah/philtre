module Philtre
  # This is a specialised module that also understands a simple
  # DSL for creating predicates as methods.
  #
  # This is how the DSL works:
  # each meth is a predicate, args is a set of alternatives
  # and the block must return something convertible to a Sequel.expr
  # to create the expression for that predicate.
  class PredicateDsl < Module
    def initialize( &bloc )
      if bloc
        if bloc.arity == 0
          module_eval &bloc
        else
          bloc.call self
        end
      end
    end

    def method_missing(meth, *args, &bloc)
      define_method meth, &bloc
      args.each{|arg| send :alias_method, arg, meth }
    end
  end
end
