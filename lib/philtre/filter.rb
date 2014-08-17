require 'sequel'

Sequel.extension :blank

require 'philtre/predicate_splitter'
require 'philtre/predicate_dsl'
require 'philtre/predicates'

module Philtre
  # Parse the predicates on the end of field names, and round-trip the search fields
  # between incoming params, controller and views.
  # So,
  #
  #   filter_parameters = {
  #     birth_year: ['2012', '2011'],
  #     title_like: 'sir',
  #     order: ['title', 'name_asc', 'birth_year_desc'],
  #   }
  #
  #   Philtre.new( filter_parameters ).apply( Personage.dataset ).sql
  #
  # should result in
  #
  #   SELECT * FROM "personages" WHERE (("birth_year" IN ('2012', '2011')) AND ("title" ~* 'bar')) ORDER BY ("title" ASC, "name" ASC, "date" DESC)
  #
  # TODO pass a predicates: parameter in here to specify a predicates object.
  class Filter
    def initialize( filter_parameters = nil, &custom_predicate_block )
      # This must be a new instance of Hash, because sometimes
      # HashWithIndifferentAccess is passed in, which breaks things in here.
      # Don't use symbolize_keys because that creates a dependency on ActiveSupport
      @filter_parameters =
      if filter_parameters
        # preserve 2.0 compatibility
        filter_parameters.inject({}){|ha,(k,v)| ha[k.to_sym] = v; ha}
      else
        {}
      end

      if block_given?
        predicates.extend_with &custom_predicate_block
      end
    end

    attr_reader :filter_parameters

    def empty?; filter_parameters.empty? end

    # return a modified dataset containing all the predicates
    def call( dataset )
      # mainly for Sequel::Model
      dataset = dataset.dataset if dataset.respond_to? :dataset

      # clone here so later order! calls don't mess with a Model's default dataset
      dataset = expressions.inject(dataset.clone) do |dataset, filter_expr|
        dataset.filter( filter_expr )
      end

      # preserve existing order if we don't have one.
      if order_clause.empty?
        dataset
      else
        # There might be multiple orderings in the order_clause
        dataset.order *order_clause
      end
    end

    alias apply call

    # Values in the parameter list which are not blank, and not
    # an ordering. That is, parameters which will be used to generate
    # the filter expression.
    def valued_parameters
      filter_parameters.select do |key,value|
        key.to_sym != :order && (value.is_a?(Array) || !value.blank?)
      end
    end

    # The set of expressions from the filter_parameters with values.
    def expressions
      valued_parameters.map do |key, value|
        to_expr(key, value)
      end
    end

    def self.predicates
      @predicates ||= Predicates.new
    end

    # Hash of predicate names to blocks. One way to get custom predicates is
    # to subclass filter and override this.
    def predicates
      # don't mess with the class' minimal set
      @predicates ||= self.class.predicates.clone
    end

    attr_writer :predicates

    def order_expr( order_predicate )
      return if order_predicate.blank?

      splitter = PredicateSplitter.new( order_predicate, nil )
      case
      when splitter === :asc
        Sequel.asc splitter.field
      when splitter === :desc
        Sequel.desc splitter.field
      else
        Sequel.asc splitter.field
      end
    end

    def order_for( order_field )
      order_hash[order_field]
    end

    # return a possibly empty array of Sequel order expressions
    def order_clause
      @order_clause ||= order_expressions.map{|e| e.last}
    end

    # Associative array (not a Hash) of names to order expressions
    # TODO this should just be a hash
    def order_expressions
      @order_expressions ||=
      [filter_parameters[:order]].flatten.map do |order_predicate|
        next if order_predicate.blank?
        expr = order_expr order_predicate
        [expr.expression, expr]
      end.compact
    end

    def order_hash
      @order_hash ||= Hash[ order_expressions ]
    end

    # turn a filter_parameter key => value into a Sequel::SQL::Expression subclass
    # field will be the field name ultimately used in the expression. Defaults to key.
    def to_expr( key, value, field = nil )
      Sequel.expr( predicates[key, value, field] )
    end

    # turn the expression at predicate into a Sequel expression with
    # field, having the value for predicate. Will be nil if the
    # predicate has no value in valued_parameters.
    # Will always be a Sequel::SQL::Expression.
    def expr_for( predicate, field = nil )
      unless (value = valued_parameters[predicate]).blank?
        to_expr( predicate, value, field )
      end
    end

    # for use in forms
    def to_h(all=false)
      filter_parameters.select{|k,v| all || !v.blank?}
    end

    attr_writer :filter_parameters
    protected :filter_parameters=

    # deallocate any cached lazies
    def initialize_copy( *args )
      super
      @order_expressions = nil
      @order_hash = nil
      @order_clause = nil
    end

    def clone( extra_parameters = {} )
      new_filter = super()

      # and explicitly clone these because they may well be modified
      new_filter.filter_parameters = filter_parameters.clone
      new_filter.predicates = predicates.clone

      extra_parameters.each do |key,value|
        new_filter[key] = value
      end

      new_filter
    end

    # return a new filter including only the specified filter parameters/predicates.
    # NOTE predicates are not the same as field names.
    # args to select_block are the same as to filter_parameters, ie it's a Hash
    # TODO should use clone
    def subset( *keys, &select_block )
      subset_params =
      if block_given?
        filter_parameters.select &select_block
      else
        filter_parameters.slice( *keys )
      end
      subset = self.class.new( subset_params )
      subset.predicates = predicates.clone
      subset
    end

    # return a subset of filter parameters/predicates,
    # but leave this object without the matching keys.
    # NOTE does not operate on field names.
    def extract!( *keys, &select_block )
      rv = subset( *keys, &select_block )
      rv.to_h.keys.each do |key|
        filter_parameters.delete( key )
      end
      rv
    end

    # hash of keys to expressions, but only where
    # there are values.
    def expr_hash
      vary = valued_parameters.map do |key, value|
        [ key, to_expr(key, value) ]
      end

      Hash[ vary ]
    end

    # easier access for filter_parameters
    # return nil for nil and '' and []
    def []( key )
      rv = filter_parameters[key]
      rv unless rv.blank?
    end

    # easier access for filter_parameters
    def []=(key, value)
      filter_parameters[key] = value
    end
  end
end
