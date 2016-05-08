require 'fastandand'

module Philtre
  # This is to split things like birth_year_gt into
  #  - birth_year (the field)
  #  - gt (the predicate)
  # Yes, there are side effects.
  # === is provided so it can be used in case statements
  # (which doesn't really work cos they're backwards).
  class PredicateSplitter
    def initialize( key, value )
      @key, @value = key, value
    end

    attr_reader :key, :value

    # split suffix from the key and store the two values as name and op
    # return truthy if successful
    def split_key( suffix )
      rv = @key =~ /\A(?:(.*?)_)?(#{suffix})\z/
      @field, @op = $1, $2
      rv
    end

    alias_method :===, :split_key
    alias_method :=~, :split_key

    # return name if the split was successful, or fall back to key
    # which is handy when none of the predicates match and so key
    # is probably just a field name.
    def field
      (@field || @key).andand.to_sym
    end

    # the operator, or predicate
    def op
      @op.andand.to_sym
    end
  end
end
