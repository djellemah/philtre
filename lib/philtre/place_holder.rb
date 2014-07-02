module Philtre
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
end
