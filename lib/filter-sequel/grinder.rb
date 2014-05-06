require 'filter-sequel/filter.rb'
require 'dataset_roller'

# Using the expressions in the filter, transform a dataset with
# placeholders into a real dataset with expressions, for example:
#
#  ds = Personage.filter( :brief.lieu, :title.lieu ).order( :ordering.lieu )
#  g = Grinder.new( Filter.new(title: 'Grand High Poobah', :order => :age.desc  ) )
#  nds = g.transform( ds )
#  nds.sql
#
#  => SELECT * FROM "personages" WHERE (("title" = 'Grand High Poobah'))
#
# In a sense, this is a means to defining SQL functions with
# optional keyword arguments.
class Grinder < Sequel::ASTTransformer
  # filter must respond to expr_for( key, sql_field = nil ), expr_hash and order_hash
  def initialize( filter = Filter.new )
    @filter = filter
  end

  attr_reader :filter

  # pass in a dataset containing PlaceHolder expressions.
  # you'll get back a modified dataset with the filter values
  # filled in.
  def transform( dataset, apply_unknown: true )
    @unknown = []
    @places = {}
    @subsets = []

    # handy for debugging
    @original_dataset = dataset

    # the transformed dataset with placeholders that
    # exist in filter replaced. unknown might have values
    # after this.
    t_dataset = super(dataset)
    unknown_placeholders

    if unknown.any?
      if apply_unknown
        # now filter by whatever predicates are left over
        # ie those not in the incoming dataset. Leftover
        # order parameters will overwrite existing ones
        # that are not protected by an outer select.
        filter.subset( *unknown ).apply t_dataset
      else
        raise "unknown placeholders #{unknown.inspect} in #{filter.predicates.keys}\n#{dataset.sql}"
      end
    else
      t_dataset
    end
  end

  # get a grouped hash of place holders
  def places
    @places
  end

  def unknown
    @unknown ||= []
  end

protected

  # Set of all keys that are not in the placeholders
  def extra_keys( keys )
    incoming = keys
    existing = places.flat_map{|subset, placeholders| placeholders.keys}

    # find the elements in incoming that are not in existing
    incoming - existing & incoming
  end

  def unknown_placeholders
    unknown.concat extra_keys( filter.expr_hash.keys )
    unknown.concat extra_keys( filter.order_hash.keys )
  end

  def context_places
    @places ||= {}
    @places[subset] ||= {}
  end

  # TODO rename subset to clause
  def subset
    @subsets.last || :none
  end

  def subset_stack
    @subsets ||= []
  end

  def push_subset( latest_subset, &block )
    subset_stack.push latest_subset
    rv = yield
    subset_stack.pop
    rv
  end

  # override the ASTTransformer method
  def v( obj )
    case obj
    when Sequel::Dataset
      # transform empty expressions to false (or nil, but false is more debuggable)
      # can't use nil for all kinds of expressions because nil mean NULL for
      # most of the Sequel::SQL expressions.
      obj.clone Hash[ v(obj.opts).map{|k,val| [k, val.is_a?(EmptyExpression) ? false : val]} ]

    when DatasetRoller
      v obj.dataset

    # Keep the context for place holders,
    # so we know what kind of expression to insert later.
    # Each of :where, :order, :having, :select etc will come as a hash.
    # There are some other top-level options too.
    when Hash
      rv = {}
      obj.each do |key, val|
        push_subset key do
          rv[v(key)] = v(val)
        end
      end
      rv

    when PlaceHolder
      # get the expression for the placeholder.
      # use the placeholder's field name if given
      expr =
      case subset
      # substitute a comparison or some other predicate
      when :where, :having
        filter.expr_for obj.name, obj.sql_field

      # substitute an order by expression
      when :order
        filter.order_for obj.name

      # Substitute the field name only if it has a value.
      # nil when the name doesn't have a value. This way,
      #  select :some_field.lieu
      # is left out when some_field does not have a value.
      when :select
        if filter[obj.name]
          obj.sql_field || obj.name
        end

      else
        raise "don't understand subset #{subset}"
      end

      # keep it, just in case
      context_places[obj.name] = expr

      # transform
      expr || EmptyExpression.new

    when Array
      # sometimes things are already an empty array, in which
      # case just leave them alone.
      return super if obj.empty?

      # collect expressions, some may be empty.
      exprs = super.reject{|e| e.is_a? EmptyExpression}

      # an empty array of expressions must be translated
      # to an empty expression at this point.
      exprs.empty? ? EmptyExpression.new : exprs

    when Sequel::SQL::ComplexExpression
      # use the Array case above, otherwise copy the expression itself
      v( obj.args ).empty? ? EmptyExpression.new : super

    else
      super
    end
  end

  class PlaceHolder < Sequel::SQL::Expression
    # name is what gets replaced by the operation and correspondingly named value in the filter
    # sql_field is the name of the field that the operation will compare the named value to.
    def initialize( name, sql_field = nil, bt = caller )
      # backtrace
      @bt = bt

      @name = name
      @sql_field = sql_field
    end

    attr_reader :bt
    attr_reader :name
    attr_reader :sql_field

    # this is inserted into the generated SQL from a dataset that
    # contains PlaceHolder instances.
    def to_s_append( ds, s )
      s << '$' << name.to_s
      s << ':' << sql_field.to_s if sql_field
      s << '/*' << small_source  << '*/'
    end

    def source
      bt[1]
    end

    def small_source
      source.split('/').last(2).join('/').split(':')[0..1].join(':')
    end

    def inspect
      "#<#{self.class} #{name}:#{sql_field} @#{source}>"
    end

    def to_s
      "#{name}:#{sql_field} @#{small_source}"
    end
  end

  # used when transforming to unaltered or partially
  # altered datasets
  class EmptyExpression < Sequel::SQL::Expression
    # sometimes this is returned in place of an empty array
    def empty?; true; end
    def to_s_append( ds, s ); end
  end
end

module Kernel
private
  def PlaceHolder( name, sql_field = nil, bt = caller )
    Grinder::PlaceHolder.new name, sql_field, bt = caller
  end

  alias_method :Lieu, :PlaceHolder
end

class Symbol
  def lieu( sql_field = nil )
    Lieu self, sql_field, caller
  end

  def place_holder( sql_field = nil )
    PlaceHolder self, sql_field, caller
  end
end

class Sequel::Dataset
  # filter must respond_to expr_hash and order_hash
  # will optionally yield a Grinder instance to the block
  def grind( filter = Filter.new, apply_unknown: true )
    grinder = Grinder.new filter
    t_dataset = grinder.transform self, apply_unknown: apply_unknown
    # only yield after the transform, so the grinder has the place holders
    yield grinder if block_given?
    t_dataset
  end
end
