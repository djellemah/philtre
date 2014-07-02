module Philtre
  # used when transforming to unaltered or partially
  # altered datasets
  class EmptyExpression < Sequel::SQL::Expression
    # sometimes this is returned in place of an empty array
    def empty?; true; end
    def to_s_append( ds, s ); end
  end
end
