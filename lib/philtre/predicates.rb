module Philtre
  # Container for methods which return Sequel::SQL::Expression or something
  # that can become one through Sequel.expr, eg {year: 2013}
  #
  # Reminder: they're defined as methods so we can benefit from
  # using them inside this class to define other predicates.
  #
  # This can be extended in all the usual ruby ways: by including a module,
  # reopening the class. Also using extend_with which takes a PredicateDsl block.
  class Predicates
    def initialize( &bloc )
      extend_with &bloc
    end

    # pass a block that can contain a combination of def meth_name() or the
    # DSL defined by PredicateDsl.
    def extend_with( &bloc )
      extend PredicateDsl.new(&bloc)
    end

    # Convert a field_predicate (field_op format), a value and a SQL field
    # name using the set of predicates, to something convertible to a Sequel
    # expression.
    #
    # field_predicate:: is a key from the parameter hash. Usually name_pred, eg birth_year_gt
    # value:: is the value from the parameter hash. Could be a collection.
    # field:: is the name of the SQL field to use, or nil where it would default to key without its predicate.
    def define_name_predicate( field_predicate, value, field = nil )
      splitter = PredicateSplitter.new field_predicate, value

      # the default / else / fall-through is just an equality
      default_proc = ->{:eq}

      # find a better predicate, if there is one
      suffix = predicate_names.find default_proc do |suffix|
        splitter =~ suffix
      end

      # wrap the field name first, to infect the expressions so all the
      # operators work.
      field_name = Sequel.expr(field || splitter.field)

      define_singleton_method field_predicate do |value|
        send suffix, field_name, value
      end
    end

    protected :define_name_predicate

    # TODO this should probably also be method_missing?
    # field is only used once for any given field_predicate
    def call( field_predicate, value, field = nil )
      unless respond_to? field_predicate
        define_name_predicate field_predicate, value, field
      end
      send field_predicate, value
    end

    # The main interface from Filter#to_expr
    alias [] call

    def predicate_names
      # ruby-2.3 no longer stores methods in order of definition. So sort by
      # longest so that we don't get false positives from shorter predicates
      # that are substrings of longer predicates, eg blank matching
      # thing_not_blank.
      DefaultPredicates.instance_methods.sort_by{|name| -name.length}
    end

    # Define the set of default predicates.
    DefaultPredicates = PredicateDsl.new do
      not_eq           {|expr, val| ~Sequel.expr( expr => val)       }

      def not_like( expr, val )
        Sequel.~(like expr, val)
      end

      matches( :like ) {|expr, val|  Sequel.expr( expr => /#{val}/i) }

      def not_blank(expr, val)
        Sequel.~(blank expr, val)
      end

      def blank(expr, _)
        is_nil = Sequel.expr(expr => nil)
        is_empty = Sequel.expr(expr => '')
        Sequel.| is_nil, is_empty
      end

      eq               {|expr, val|  Sequel.expr( expr => val)       }
      gt               {|expr, val|    expr >  val                   }
      gte( :gteq )     {|expr, val|    expr >= val                   }
      lt               {|expr, val|    expr <  val                   }
      lte( :lteq )     {|expr, val|    expr <= val                   }

      # more complex predicates
      def like_all( expr, arg )
        exprs = Array(arg).map {|value| like expr, value }
        Sequel.& *exprs
      end

      def like_any( expr, arg )
        exprs = Array(arg).map {|value| like expr, value }
        Sequel.| *exprs
      end
    end

    # make them available to Predicate instances.
    include DefaultPredicates
  end
end
