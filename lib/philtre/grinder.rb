require 'ripar'

require 'philtre/filter.rb'
require 'philtre/place_holder.rb'
require 'philtre/empty_expression.rb'

# Using the expressions in the filter, transform a dataset with
# placeholders into a real dataset with expressions, for example:
#
#  ds = Personage.filter( :brief.lieu, :title.lieu ).order( :ordering.lieu )
#  g = Grinder.new( Philtre.new(title: 'Grand High Poobah', :order => :age.desc  ) )
#  nds = g.transform( ds )
#  nds.sql
#
#  => SELECT * FROM "personages" WHERE (("title" = 'Grand High Poobah'))
#
# In a sense, this is a means to defining SQL functions with
# optional keyword arguments.
class Philtre::Grinder < Sequel::ASTTransformer
  # filter must respond to expr_for( key, sql_field = nil ), expr_hash and order_hash
  def initialize( filter = Philtre::Filter.new )
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
        raise "unknown values #{unknown.inspect} for\n#{dataset.sql}"
      end
    else
      t_dataset
    end
  end

  alias [] transform

  # Grouped hash of place holders in the original dataset from the last transform.
  # Only has values after transform has been called.
  def places
    @places || raise("Call transform to find place holders.")
  end

  # collection of values in the filter that were not found as placeholders
  # in the original dataset.
  def unknown
    @unknown || raise("Call transform to find placeholders not provided by the filter.")
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

  # Override the ASTTransformer method, which is where the work
  # is done to transform the dataset containing placeholders into
  # a dataset containing a proper SQL statement.
  # Yes, this is in fact every OO purist's worst nightware - a Giant Switch Statement.
  def v( obj )
    case obj
    when Sequel::Dataset
      # transform empty expressions to false (or nil, but false is more debuggable)
      # can't use nil for all kinds of expressions because nil mean NULL for
      # most of the Sequel::SQL expressions.
      obj.clone Hash[ v(obj.opts).map{|k,val| [k, val.is_a?(Philtre::EmptyExpression) ? false : val]} ]

    # for Sequel::Models
    when ->(obj){obj.respond_to? :dataset}
      v obj.dataset

    # for other things that are convertible to dataset
    when ->(obj){obj.respond_to? :to_dataset}
      v obj.to_dataset

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

    when Philtre::PlaceHolder
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
      expr || Philtre::EmptyExpression.new

    when Array
      # sometimes things are already an empty array, in which
      # case just leave them alone.
      return super if obj.empty?

      # collect expressions, some may be empty.
      exprs = super.reject{|e| e.is_a? Philtre::EmptyExpression}

      # an empty array of expressions must be translated
      # to an empty expression at this point.
      exprs.empty? ? Philtre::EmptyExpression.new : exprs

    when Sequel::SQL::ComplexExpression
      # use the Array case above, otherwise copy the expression itself
      v( obj.args ).empty? ? Philtre::EmptyExpression.new : super

    else
      super
    end
  end
end
