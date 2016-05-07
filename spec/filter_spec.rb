require_relative 'spec_helper.rb'
require_relative '../lib/philtre/filter.rb'

# for blank?
Sequel.extension :blank

describe Philtre::Filter do
  # must be in before otherwise it's unpleasant to hook the
  # class in to the dataset.
  before :all do
    @dataset = Sequel.mock[:planks]
    class Plank < Sequel::Model; end
    # just stop whining and generate the bleedin' sql, k?
    def @dataset.supports_regexp?; true end
  end

  attr_reader :dataset

  describe '#initialize' do
    it 'keeps parameters' do
      filter = described_class.new one: 1, two: 2
      filter.filter_parameters.keys.should == %i[one two]
    end

    it 'defaults parameters' do
      described_class.new.filter_parameters.should == {}
    end

    it 'keeps empty parameters' do
      described_class.new({}).filter_parameters.should == {}
    end

    it 'converts non-symbol keys' do
      filter = described_class.new 'name' => Faker::Lorem.word, 'title' => Faker::Lorem.word, 'order' => 'owner'
      filter.filter_parameters.keys.should == %i[name title order]
    end

    it 'treats nil as empty parameters' do
      filter = described_class.new(nil)
      filter.filter_parameters.should == {}
    end

    describe 'custom predicates' do
      it 'from yield' do
        outside = 'Outside Value'
        filter = described_class.new custom_predicate: 'Special Value' do |predicates|
          # yip, you really do have to use the define_method hack here
          # to get outside values into the predicates module.
          predicates.send :define_method, :custom_predicate do | val |
            {special_field: val, other_special_field: outside}
          end
        end
        filter.apply(dataset).sql.should == %q{SELECT * FROM planks WHERE ((special_field = 'Special Value') AND (other_special_field = 'Outside Value'))}
      end

      it 'from module_eval' do
        filter = described_class.new custom_predicate: 'Special Value' do
          # this is just a normal module block.
          def custom_predicate( val )
            {special_field: val}
          end
        end
        filter.apply(dataset).sql.should == %q{SELECT * FROM planks WHERE (special_field = 'Special Value')}
      end
    end
  end

  describe '#order_expressions' do
    it 'defaults to asc' do
      filter = described_class.new one: 1, two: 2, order: 'things'
      @dataset.order( *filter.order_clause ).sql.should =~ /order by things asc$/i
    end
  end

  describe '#order_expr' do
    filter = described_class.new one: 1, two: 2, order: 'things'

    it 'nil for nil' do
      filter.order_expr(nil).should be_nil
    end

    it 'nil for blank' do
      filter.order_expr('').should be_nil
    end

    it 'defaults to asc' do
      filter = described_class.new one: 1, two: 2, order: 'things'
      sqlfrag = filter.order_expr(:things).sql_literal(dataset)
      sqlfrag.should == 'things ASC'
    end
  end

  describe '#order_clause' do
    it '[] for nil order parameter' do
      filter = described_class.new one: 1, two: 2
      filter.order_clause.should be_empty
    end

    it '[] for blank order parameter' do
      filter = described_class.new one: 1, two: 2, order: ''
      filter.order_clause.should be_empty
    end

    # These should really be part of describe '#order_expr'
    it 'defaults to asc' do
      filter = described_class.new one: 1, two: 2, order: 'things'
      @dataset.order( *filter.order_clause ).sql.should =~ /order by things asc$/i
    end

    it 'respects desc' do
      filter = described_class.new one: 1, two: 2, order: 'things_desc'
      @dataset.order( *filter.order_clause ).sql.should =~ /order by things desc$/i
    end

    it 'respects asc' do
      filter = described_class.new one: 1, two: 2, order: 'things_desc'
      @dataset.order( *filter.order_clause ).sql.should =~ /order by things desc$/i
    end

    it 'handles array' do
      filter = described_class.new one: 1, two: 2, order: ['things_desc', 'stuff', 'orgle_asc']
      @dataset.order( *filter.order_clause ).sql.should =~ /order by things desc, stuff asc, orgle asc$/i
    end

    it 'handles array with blanks' do
      filter = described_class.new one: 1, two: 2, order: ['things_desc', nil, 'stuff', '', 'orgle_asc']
      @dataset.order( *filter.order_clause ).sql.should =~ /order by things desc, stuff asc, orgle asc$/i
    end
  end

  describe '#predicates' do
    EASY_PREDICATES = %i[gt gte gteq lt lte lteq eq not_eq matches like not_like not_null null cont not_cont in not_in start not_start end not_end]
    TRICKY_PREDICATES = %i[like_all like_any not_blank blank]

    it 'creates predicates' do
      predicates = EASY_PREDICATES + TRICKY_PREDICATES
      predicates += predicates.map { |predicate| "hstore_#{predicate}".to_sym }
      described_class.predicates.predicate_names.sort.should == (predicates).sort
    end

    EASY_PREDICATES.each do |predicate|
      it "_#{predicate} becomes expression" do
        field = Faker::Lorem.word.to_sym
        value = Faker::Lorem.word
        expr = described_class.predicates.call "#{field}_#{predicate}", value

        expr.should be_a(Sequel::SQL::BooleanExpression)

        expr.args.first.should be_a(Sequel::SQL::Identifier)
        expr.args.first.should == Sequel.expr(field)

        expected_value =
        case predicate
        when :start, :not_start
         "^#{value}"
        when :end, :not_end
          "#{value}$"
        else
          value
        end

        expr.args.last.should == expected_value

        expr.sql_literal(@dataset).should be_a(String)
      end

      it "_#{predicate} for hstore becomes expression" do
        column = Faker::Lorem.word
        field = Faker::Lorem.word
        column_field = "#{column}[#{field}]".to_sym
        value = Faker::Lorem.word

        expr = described_class.predicates.call "#{column_field}_#{predicate}", value

        expr.should be_a(Sequel::SQL::BooleanExpression)

        expected_value =
        case predicate
        when :start, :not_start
         "^#{value}"
        when :end, :not_end
          "#{value}$"
        else
          value
        end

        case predicate
        when :eq, :not_eq
          expr.args.first.should be_a(Sequel::SQL::PlaceholderLiteralString)
          expr.args.first.args.should == [column.to_sym, {field => expected_value}]
        else
          expr.args.first.should be_a(Sequel::SQL::StringExpression)
          expr.args.last.should == expected_value
          expr.args.first.args.first.args.should == [column.to_sym, field.to_s]
        end

        expr.sql_literal(@dataset).should be_a(String)
      end
    end

    describe 'like_all' do
      it 'takes one' do
        field = Faker::Lorem.word
        value = Faker::Lorem.word
        expr = described_class.predicates.call :"#{field}_like_all", value
        expr.args.size.should == 1
        expr.op.should == :NOOP

        expr.args.first.op.should == :'~*'
        ident, val = expr.args.first.args
        ident.value.should == field
        val.should == value
      end

      it 'takes many' do
        field = Faker::Lorem.word
        value = 3.times.map{ Faker::Lorem.word }
        expr = described_class.predicates.call :"#{field}_like_all", value
        expr.args.size.should == 3
        expr.op.should == :AND
      end

      describe 'hstore' do
        it 'takes one' do
          column = Faker::Lorem.word
          field = Faker::Lorem.word
          column_field = "#{column}[#{field}]".to_sym
          value = Faker::Lorem.word

          expr = described_class.predicates.call :"#{column_field}_like_all", value
          expr.args.size.should == 1
          expr.op.should == :NOOP

          expr.args.first.op.should == :'~*'
          ident, value = expr.args.first.args
          ident.args.first.args.should == [column.to_sym, field.to_s]
          value.should == value
        end

        it 'takes many' do
          column = Faker::Lorem.word
          field = Faker::Lorem.word
          column_field = "#{column}[#{field}]".to_sym
          value = 3.times.map { Faker::Lorem.word }

          expr = described_class.predicates.call :"#{column_field}_like_all", value
          expr.args.size.should == 3
          expr.op.should == :AND
        end
      end
    end

    describe 'like_any' do
      it 'takes one' do
        field = Faker::Lorem.word
        value = Faker::Lorem.word
        expr = described_class.predicates.call :"#{field}_like_any", value
        expr.args.size.should == 1
        expr.op.should == :NOOP

        expr.args.first.op.should == :'~*'
        ident, value = expr.args.first.args
        ident.value.should == field
        value.should == value
      end

      it 'takes many' do
        field = Faker::Lorem.word
        value = 3.times.map{ Faker::Lorem.word }
        expr = described_class.predicates.call :"#{field}_like_any", value
        expr.args.size.should == 3
        expr.op.should == :OR
      end

      describe 'hstore' do
        it 'takes one' do
          column = Faker::Lorem.word
          field = Faker::Lorem.word
          column_field = "#{column}[#{field}]".to_sym
          value = Faker::Lorem.word

          expr = described_class.predicates.call :"#{column_field}_like_any", value
          expr.args.size.should == 1
          expr.op.should == :NOOP

          expr.args.first.op.should == :'~*'
          ident, value = expr.args.first.args
          ident.args.first.args.should == [column.to_sym, field.to_s]
          value.should == value
        end

        it 'takes many' do
          column = Faker::Lorem.word
          field = Faker::Lorem.word
          column_field = "#{column}[#{field}]".to_sym
          value = 3.times.map { Faker::Lorem.word }

          expr = described_class.predicates.call :"#{column_field}_like_any", value
          expr.args.size.should == 3
          expr.op.should == :OR
        end
      end
    end

    it 'not_blank' do
      field = Faker::Lorem.word
      expr = described_class.predicates.call :"#{field}_not_blank", Faker::Lorem.word

      expr.op.should == :AND
      is_not_null, not_equals_empty = expr.args

      # the not-nil part
      is_not_null.op.should == :'IS NOT'

      # the not empty string part
      not_equals_empty.op.should == :'!='
      not_equals_empty.args.last.should == ''
    end

    it 'blank' do
      field = Faker::Lorem.word
      expr = described_class.predicates.call :"#{field}_blank", Faker::Lorem.word

      expr.op.should == :OR

      is_null, equals_empty = expr.args

      # the null part
      is_null.op.should == :'IS'

      # the empty string part
      equals_empty.op.should == :'='
      equals_empty.args.last.should == ''
    end
  end

  describe '#to_expr' do
    let(:filter){ described_class.new name: Faker::Lorem.word, title: Faker::Lorem.word }
    it 'is == for name only' do
      expr = Sequel.expr( filter.to_expr( :name, 'hallelujah' ) )
      expr.op.should == :'='
      expr.args.first.should be_a(Sequel::SQL::Identifier)
      expr.args.first.value.should == 'name'
      expr.args.last.should == 'hallelujah'
    end

    it 'like' do
      expr = Sequel.expr( filter.to_expr( :owner_like, 'hallelujah' ) )
      expr.op.should == :'~*'
      expr.args.first.should be_a(Sequel::SQL::Identifier)
      expr.args.first.value.should == 'owner'
      expr.args.last.should == 'hallelujah'
    end

    it 'keeps blank values' do
      filter.to_expr( :owner, '' ).should_not be_nil
      filter.to_expr( :owner, nil ).should_not be_nil
      filter.to_expr( :owner, [] ).should_not be_nil
    end

    it 'substitutes a field name' do
      expr = Sequel.expr( filter.to_expr( :owner_like, 'hallelujah', :heavens__salutation ) )
      expr.op.should == :'~*'
      expr.args.first.should be_kind_of(Sequel::SQL::QualifiedIdentifier)
      expr.args.first.column.should == 'salutation'
      expr.args.first.table.should == 'heavens'
      expr.args.last.should == 'hallelujah'
    end

    it 'must always be a Sequel::SQL::Expression' do
      filter.predicates.extend_with do
        def year_range(jumbled_years)
          first, last = jumbled_years.sort.instance_eval{|ry| [ry.first, ry.last]}
          { year: first..last }
        end
      end

      expr = filter.to_expr( :year_range, [1984, 1970, 2012] )
      expr.should be_a(Sequel::SQL::Expression)
      expr.sql_literal(dataset).should == '((year >= 1970) AND (year <= 2012))'
    end

    describe 'hstore' do
      it 'is == for store[name] only' do
        expr = Sequel.expr(filter.to_expr(:'store[name]', 'hallelujah'))
        expr.op.should == :NOOP
        expr.args.first.should be_a(Sequel::SQL::PlaceholderLiteralString)
        expr.args.first.args.first.should == :store
        expr.args.first.args.last.should == {'name' => 'hallelujah'}
      end

      it 'like' do
        expr = Sequel.expr(filter.to_expr(:'store[owner]_like', 'hallelujah'))
        expr.op.should == :'~*'
        expr.args.first.args.first.should be_a(Sequel::SQL::PlaceholderLiteralString)
        expr.args.first.args.first.args.should == [:store, 'owner']
        expr.args.last.should == 'hallelujah'
      end

      it 'keeps blank values' do
        filter.to_expr(:'store[owner]', '').should_not be_nil
        filter.to_expr(:'store[owner]', nil).should_not be_nil
        filter.to_expr(:'store[owner]', []).should_not be_nil
      end

      it 'substitutes a field name' do
        expr = Sequel.expr(filter.to_expr(:'store[owner]_like', 'hallelujah', :'heavens__store[owner]'))
        expr.op.should == :'~*'
        expr.args.first.args.first.should be_a(Sequel::SQL::PlaceholderLiteralString)
        expr.args.first.args.first.args.should == [:store, 'owner']
        expr.args.last.should == 'hallelujah'
      end

      it 'must always be a Sequel::SQL::Expression' do
        filter.predicates.extend_with do
          define_method 'store[year]_range' do |jumbled_years|
            first, last = jumbled_years.sort.instance_eval { |ry| [ry.first, ry.last] }
            {year: first..last}
          end
        end

        expr = filter.to_expr(:'store[year]_range', [1984, 1970, 2012])
        expr.should be_a(Sequel::SQL::Expression)
        expr.sql_literal(dataset).should == '((year >= 1970) AND (year <= 2012))'
      end
    end
  end

  describe '#expr_for' do
    let(:filter){ described_class.new name: Faker::Lorem.word, title: Faker::Lorem.word, interstellar: '' }

    it 'nil for no value' do
      filter.expr_for(:bleh).should be_nil
    end

    it 'nil for no value' do
      filter.expr_for(:interstellar).should be_nil
    end

    it 'expression for existing value' do
      filter.expr_for(:name).should_not be_nil
      filter.expr_for(:name).should be_a(Sequel::SQL::BooleanExpression)
    end

    it 'alternate name' do
      expr = filter.expr_for(:name, :things__name)
      expr.should_not be_nil
      expr.should be_a(Sequel::SQL::BooleanExpression)

      expr.args.first.tap do |field_expr|
        field_expr.column.should == 'name'
        field_expr.table.should == 'things'
      end
    end

    describe 'hstore' do
      let(:word) { Faker::Lorem.word }
      let(:filter) { described_class.new :'store[name]' => word, :'store[title]' => Faker::Lorem.word }

      it 'expression for existing value' do
        filter.expr_for(:'store[name]').should_not be_nil
        filter.expr_for(:'store[name]').should be_a(Sequel::SQL::BooleanExpression)
      end

      it 'alternate name' do
        expr = filter.expr_for(:'store[name]', :'things__store[name]')
        expr.should_not be_nil
        expr.should be_a(Sequel::SQL::BooleanExpression)

        expr.args.first.args.should == [:store, {'name' => word}]
      end
    end
  end

  describe '#order_for' do
    let(:filter){ described_class.new name: Faker::Lorem.word, title: Faker::Lorem.word, order:[:name, :title, :year] }
    let(:dataset){ Sequel.mock[:things] }

    it 'nil for no parameter' do
      filter.order_for( :icecream_count ).should be_nil
    end

    it 'ascending' do
      filter.order_for(:year).sql_literal(dataset).should == 'year ASC'
    end

    it 'name clash' do
      filter.order_for(:title).sql_literal(dataset).should == 'title ASC'
    end
  end

  describe '#expressions' do
    it 'generates expressions' do
      expressions = described_class.new( trailer: 'large' ).expressions
      expressions.size.should == 1
      expressions.first.should be_a(Sequel::SQL::BooleanExpression)
      expr, value = expressions.first.args
      expr.should be_a(Sequel::SQL::Identifier)
      expr.value.should == 'trailer'
      value.should == 'large'
    end

    it 'handles stringified operators' do
      expressions = described_class.new( trailer_gte: 'large' ).expressions
      expressions.size.should == 1
      expressions.first.should be_a(Sequel::SQL::BooleanExpression)
      expr, value = expressions.first.args
      expr.should be_a(Sequel::SQL::Identifier)
      expr.value.should == 'trailer'
      value.should == 'large'
    end

    it 'ignores order:' do
      described_class.new(order: %w[one two tre]).expressions.should be_empty
    end

    it "ignores '' value" do
      described_class.new( address: '' ).expressions.should be_empty
    end

    it 'ignores nil value' do
      described_class.new( address: nil ).expressions.should be_empty
    end

    it 'accepts []' do
      expressions = described_class.new( flavour: [] ).expressions
      expressions.size.should == 1
      expressions.first.should be_a(Sequel::SQL::BooleanExpression)
      expr, value = expressions.first.args
      expr.should be_a(Sequel::SQL::Identifier)
      expr.value.should == 'flavour'
      value.should == []
    end
  end

  describe '#apply' do
    let(:filter){ described_class.new name: Faker::Lorem.word, title: Faker::Lorem.word }

    # make sure the Model dataset isn't impacted by setting the ordering
    # on the filtered dataset.
    it 'clones' do
      orig_dataset = Plank.dataset
      filter.filter_parameters[:order] = :title
      filter.apply(Plank.dataset)
      Plank.dataset.should == orig_dataset
    end

    it 'accepts Sequel::Model subclasses' do
      ds = filter.apply(Plank)
      ds.should be_a(Sequel::Dataset)
      ds.sql.should =~ /planks/
    end

    it 'filter parameters' do
      sql = filter.apply(@dataset).sql
      sql.should =~ /select \* from planks where \(\(name = '\w+'\) and \(title = '\w+'\)\)$/i
    end

    it 'single order clause' do
      filter.filter_parameters[:order] = :title
      filter.apply(@dataset).sql.should =~ /order by.*title/i
    end

    it 'multiple order clause' do
      filter.filter_parameters[:order] = [:title, :owner]
      filter.apply(@dataset).sql.should =~ /order by.*title.*owner/i
    end

    it 'empty filter parameters' do
      filter = described_class.new
      filter.filter_parameters.should be_empty
      filter.apply(@dataset).sql.should =~ /select \* from planks$/i
    end

    it 'no order clause' do
      sql = filter.apply(@dataset).sql
      sql.should_not =~ /order by/i
    end

    it 'no order clause keeps previous order clause' do
      sql = filter.apply(@dataset.order(:watookal)).sql
      sql.should =~ /order by/i
    end

    it 'excludes blank values' do
      filter.filter_parameters[:name] = ''
      sql = filter.apply(@dataset).sql
      sql.should =~ /select \* from planks where \(title = '\w+'\)$/i
    end

    it 'excludes nil values by default' do
      filter.filter_parameters[:name] = nil
      sql = filter.apply(@dataset).sql
      sql.should =~ /select \* from planks where \(title = '\w+'\)$/i
    end

    it 'can customise value exclusion' do
      def filter.valued_parameter?(key,value)
        key != :order
      end

      filter.filter_parameters[:name] = nil
      sql = filter.apply(@dataset).sql
      sql.should =~ /SELECT \* FROM planks WHERE \(\(name IS NULL\) AND \(title = '\w+'\)\)/
    end
  end

  describe '#empty?' do
    it 'true on no parameters' do
      described_class.new.should be_empty
    end

    it 'false with parameters' do
      described_class.new(one: 1, two: 2).should_not be_empty
    end
  end

  describe '#subset' do
    it 'has specified subset of parameter values' do
      filter = described_class.new done_with: 'Hammers', fixed_by: 'Thor'
      filter.subset( :done_with ).filter_parameters.keys.should == [:done_with]
    end

    it 'has block specified subset of parameter values' do
      filter = described_class.new done_with: 'Hammers', fixed_by: 'Thor'
      filter.subset{|k,v| k == :done_with}.filter_parameters.keys.should == [:done_with]
    end

    it 'keeps custom predicates' do
      filter = described_class.new done_with: 'Hammers' do
        def done_with( things )
          Sequel.expr done: things
        end
      end

      filter.subset( :done_with ).predicates.should respond_to(:done_with)
    end
  end

  describe '#extract!' do
    it 'gives back subset' do
      filter = described_class.new first: 'James', second: 'McDonald', third: 'Fraser'
      extracted = filter.extract!(:first)
      extracted.to_h.size.should == 1
      extracted.to_h.should have_key(:first)
    end

    it 'removes specified keys' do
      filter = described_class.new first: 'James', second: 'McDonald', third: 'Fraser'
      extracted = filter.extract!(:first, :third)
      filter.to_h.size.should == 1
      filter.to_h.should have_key(:second)
    end
  end

  describe '#to_h' do
    def filter
      @filter ||= described_class.new first: 'James', second: 'McDonald', third: 'Fraser', fourth: '', fifth: nil
    end

    it 'all values' do
      filter.to_h(true).size.should == filter.filter_parameters.size
    end

    it 'only non-blank values' do
      filter.to_h.size.should == 3
    end
  end

  describe '#clone' do
    it 'plain clone' do
      filter = described_class.new first: 'James', second: 'McDonald', third: 'Fraser'
      cloned = filter.clone
      cloned.filter_parameters.should == filter.filter_parameters
    end

    it 'clone with extras leaves original' do
      value_hash = {first: 'James', second: 'McDonald', third: 'Fraser'}.freeze
      filter = described_class.new value_hash
      cloned = filter.clone( extra: 'Magoodies')

      filter.filter_parameters.should == value_hash
    end

    it 'clone with extras adds values' do
      value_hash = {first: 'James', second: 'McDonald', third: 'Fraser'}.freeze
      filter = described_class.new value_hash
      cloned = filter.clone( extra: 'Magoodies')

      (cloned.filter_parameters.keys & filter.filter_parameters.keys).should == filter.filter_parameters.keys
      (cloned.filter_parameters.keys - filter.filter_parameters.keys).should == [:extra]
    end
  end
end
