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
    def initialize(&bloc)
      extend_with &bloc
    end

    # pass a block that can contain a combination of def meth_name() or the
    # DSL defined by PredicateDsl.
    def extend_with(&bloc)
      extend PredicateDsl.new(&bloc)
    end

    # Convert a field_predicate (field_op format), a value and a SQL field
    # name using the set of predicates, to something convertible to a Sequel
    # expression.
    #
    # field_predicate:: is a key from the parameter hash. Usually name_pred, eg birth_year_gt
    # value:: is the value from the parameter hash. Could be a collection.
    # field:: is the name of the SQL field to use, or nil where it would default to key without its predicate.
    def define_name_predicate(field_predicate, value, field = nil)
      splitter = PredicateSplitter.new field_predicate, value

      # the default / else / fall-through is just an equality
      default_proc = -> { :eq }

      # find a better predicate, if there is one
      suffix = predicate_names.find default_proc do |suffix|
        splitter =~ suffix
      end

      # wrap the field name first, to infect the expressions so all the
      # operators work.
      field_name = Sequel.expr(field || splitter.field)

      define_singleton_method field_predicate do |value|
        # The full HStore column (the table column and the column inside the HStore)
        raw_column = raw_column_from_identifier(field_name)

        if hstore_column?(raw_column)
          hstore_name, column_name = parse_hstore_column(raw_column)
          send "hstore_#{suffix}", hstore_name.to_sym.hstore, column_name, value
        else
          send suffix, field_name, value
        end
      end
    end

    def raw_column_from_identifier(identifier)
      case identifier
        when Sequel::SQL::QualifiedIdentifier
          identifier.column
        else
          identifier.value
      end
    end

    def parse_hstore_column(name)
      not_square_brackets = '([^\[\]]*)'
      match_data = name.match(/#{not_square_brackets}\[#{not_square_brackets}\]/)
      if match_data && match_data.size == 3
        matched = match_data[1..2]
        if matched.all? { |elem| !elem.nil? }
          matched
        end
      end
    end

    alias_method :hstore_column?, :parse_hstore_column

    protected :define_name_predicate, :hstore_column?, :parse_hstore_column

    # TODO this should probably also be method_missing?
    # field is only used once for any given field_predicate
    def call(field_predicate, value, field = nil)
      unless respond_to? field_predicate
        define_name_predicate field_predicate, value, field
      end
      send field_predicate, value
    end

    # The main interface from Filter#to_expr
    alias [] call

    def predicate_names
      DefaultPredicates.instance_methods + HStorePredicates.instance_methods
    end

    # Define the set of default predicates.
    DefaultPredicates = PredicateDsl.new do
      # longer suffixes first, so they match first in define_name_predicate
      not_eq { |expr, val| ~Sequel.expr(expr => val) }

      def not_like(expr, val)
        Sequel.~(like expr, val)
      end

      alias_method :not_cont, :not_like

      matches(:like, :cont) { |expr, val| Sequel.expr(expr => /#{val}/i) }

      def not_blank(expr, val)
        Sequel.~(blank expr, val)
      end

      def blank(expr, _)
        is_nil = Sequel.expr(expr => nil)
        is_empty = Sequel.expr(expr => '')
        Sequel.| is_nil, is_empty
      end

      # and now the shorter suffixes
      gte(:gteq) { |expr, val| expr >= val }
      gt { |expr, val| expr > val }
      lte(:lteq) { |expr, val| expr <= val }
      lt { |expr, val| expr < val }
      eq { |expr, val| Sequel.expr(expr => val) }

      not_in(:not_cont) { |expr, val| ~Sequel.expr(expr => val) }

      def in(expr, arg)
        Sequel.expr(expr => arg)
      end

      # more complex predicates
      def like_all(expr, arg)
        exprs = Array(arg).map { |value| like expr, value }
        Sequel.& *exprs
      end

      def like_any(expr, arg)
        exprs = Array(arg).map { |value| like expr, value }
        Sequel.| *exprs
      end

      not_start { |expr, val| Sequel.~(start expr, val) }
      start { |expr, val| Sequel.expr(expr => /^#{val}/i) }

      not_end { |expr, val| Sequel.~(send 'end', expr, val) }

      define_method 'end' do |expr, val|
        Sequel.expr(expr => /#{val}$/i)
      end
    end

    HStorePredicates = PredicateDsl.new do

      hstore_not_eq { |column, key, val| Sequel.~(hstore_eq column, key, val) }

      def hstore_eq(column, key, val)
        if val.is_a?(Array)
          Sequel.expr(column[key] => val)
        else
          Sequel.expr(column.contains(Sequel.hstore({key => val})))
        end
      end

      hstore_not_blank { |column, key, val| Sequel.~(hstore_blank column, key, val) }

      def hstore_blank(column, key, _)
        is_nil = Sequel.expr(column[key] => nil)
        is_empty = Sequel.expr(column[key] => '')
        Sequel.| is_nil, is_empty
      end

      hstore_not_like(:hstore_not_cont) { |column, key, val| Sequel.~(hstore_like column, key, val) }

      hstore_matches(:hstore_like, :hstore_cont) { |column, key, val| Sequel.expr(column[key] => /#{val}/i) }

      hstore_not_in { |column, key, val| Sequel.~(hstore_in column, key, val) }

      hstore_in { |column, key, val| Sequel.expr(column[key] => val) }

      hstore_gt { |column, key, val| column[key] > val }
      hstore_gte(:hstore_gteq) { |column, key, val| column[key] >= val }
      hstore_lt { |column, key, val| column[key] < val }
      hstore_lte(:hstore_lteq) { |column, key, val| column[key] <= val }


      hstore_not_start { |column, key, val| Sequel.~(hstore_start column, key, val) }
      hstore_start { |column, key, val| Sequel.expr(column[key] => /^#{val}/i) }

      hstore_not_end { |column, key, val| Sequel.~(hstore_end column, key, val) }
      hstore_end { |column, key, val| Sequel.expr(column[key] => /#{val}$/i) }

      def hstore_like_all(column, key, val)
        exprs = Array(val).map { |value| hstore_like column, key, value }
        Sequel.& *exprs
      end

      def hstore_like_any(column, key, val)
        exprs = Array(val).map { |value| hstore_like column, key, value }
        Sequel.| *exprs
      end

    end

    # make the available to Predicates instances.
    include DefaultPredicates
    include HStorePredicates
  end
end
