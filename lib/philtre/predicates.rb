module Philtre
  # constructs a Hash from predicate (ie eq, gt, gte) => block
  # which returns Sequel::SQL::Expression or something that can
  # become one through Sequel.expr, eg {year: 2013}
  class Predicates < Module
    module BasePredicates
      def simple_pred( expr, value )
        puts __method__
      end
    end

    def initialize( &bloc )
      # module_eval &bloc if bloc
      super
      extend BasePredicates
    end

    # each meth is a predicate, args is a set of alternatives
    # and the block is to create the expression for that predicate.
    def method_missing(meth, *args, &bloc)
      puts "method_missing #{meth}"
      # store them in the module, just for fun
      define_method meth, &bloc
      args.each{|arg| send :alias_method, arg, meth }
    end

    def self.construct_named_predicate( meth, *args, &bloc )
      puts "#{meth} with #{args.inspect}"
      # and this is where the whole splitter predicate thing is done
    end

    def self.default_predicates
      defining_module_self = self
      new do
        define_method :method_missing do |meth, *args, &block|
          defining_module_self.construct_named_predicate meth, *args, &block
        end

        gt               {|expr, val|    expr >  val          }
        gte( :gteq )     {|expr, val|    expr >= val          }
        lt               {|expr, val|    expr <  val          }
        lte( :lteq )     {|expr, val|    expr <= val          }
        eq               {|expr, val| Sequel.expr( expr => val) }
        not_eq           {|expr, val| ~Sequel.expr( expr => val) }
        matches( :like ) {|expr, val| Sequel.expr( expr => /#{val}/i) }

        not_blank do |expr, _|
          not_nil = ~Sequel.expr(expr => nil)
          not_empty = ~Sequel.expr(expr => '')
          Sequel.& not_nil, not_empty
        end

        def not_like( expr, val )
          Sequel.~(like expr, val)
        end

        # def like_all( expr,arg )
        #   if arg.is_a?( Array )
        #     exprs = arg.map do |value|
        #       Sequel.expr expr => /#{value}/
        #     end
        #     Sequel.& *exprs
        #   else
        #     Sequel.expr expr => /#{arg}/
        #   end
        # end
        like_all do |expr,arg|
          if arg.is_a?( Array )
            exprs = arg.map do |value|
              Sequel.expr expr => /#{value}/
            end
            Sequel.& *exprs
          else
            Sequel.expr expr => /#{arg}/
          end
        end

        like_any do |expr,arg|
          if arg.is_a?( Array )
            exprs = arg.map do |value|
              Sequel.expr expr => /#{value}/
            end
            Sequel.| *exprs
          else
            Sequel.expr expr => /#{arg}/
          end
        end
      end
    end
  end
end
