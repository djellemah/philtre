require 'rspec'
require 'faker'

require_relative '../lib/philtre/filter.rb'

# for blank?
Sequel.extension :blank

describe Philtre do
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
      filter = Philtre::Filter.new one: 1, two: 2
      filter.filter_parameters.keys.should == %i[one two]
    end

    it 'defaults parameters' do
      Philtre::Filter.new.filter_parameters.should == {}
    end

    it 'keeps empty parameters' do
      Philtre::Filter.new({}).filter_parameters.should == {}
    end

    it 'converts non-symbol keys' do
      filter = Philtre::Filter.new 'name' => Faker::Lorem.word, 'title' => Faker::Lorem.word, 'order' => 'owner'
      filter.filter_parameters.keys.should == %i[name title order]
    end

    it 'treats nil as empty parameters' do
      filter = Philtre::Filter.new(nil)
      filter.filter_parameters.should == {}
    end
  end

  describe '#order_expressions' do
    it 'defaults to asc' do
      filter = Philtre::Filter.new one: 1, two: 2, order: 'things'
      @dataset.order( *filter.order_clause ).sql.should =~ /order by things asc$/i
    end
  end

  describe '#order_expr' do
    filter = Philtre::Filter.new one: 1, two: 2, order: 'things'

    it 'nil for nil' do
      filter.order_expr(nil).should be_nil
    end

    it 'nil for blank' do
      filter.order_expr('').should be_nil
    end

    it 'defaults to asc' do
      filter = Philtre::Filter.new one: 1, two: 2, order: 'things'
      sqlfrag = filter.order_expr(:things).sql_literal(dataset)
      sqlfrag.should == 'things ASC'
    end
  end

  describe '#order_clause' do
    it '[] for nil order parameter' do
      filter = Philtre::Filter.new one: 1, two: 2
      filter.order_clause.should be_empty
    end

    it '[] for blank order parameter' do
      filter = Philtre::Filter.new one: 1, two: 2, order: ''
      filter.order_clause.should be_empty
    end

    # These should really be part of describe '#order_expr'
    it 'defaults to asc' do
      filter = Philtre::Filter.new one: 1, two: 2, order: 'things'
      @dataset.order( *filter.order_clause ).sql.should =~ /order by things asc$/i
    end

    it 'respects desc' do
      filter = Philtre::Filter.new one: 1, two: 2, order: 'things_desc'
      @dataset.order( *filter.order_clause ).sql.should =~ /order by things desc$/i
    end

    it 'respecs asc' do
      filter = Philtre::Filter.new one: 1, two: 2, order: 'things_desc'
      @dataset.order( *filter.order_clause ).sql.should =~ /order by things desc$/i
    end

    it 'handles array' do
      filter = Philtre::Filter.new one: 1, two: 2, order: ['things_desc', 'stuff', 'orgle_asc']
      @dataset.order( *filter.order_clause ).sql.should =~ /order by things desc, stuff asc, orgle asc$/i
    end

    it 'handles array with blanks' do
      filter = Philtre::Filter.new one: 1, two: 2, order: ['things_desc', nil, 'stuff', '', 'orgle_asc']
      @dataset.order( *filter.order_clause ).sql.should =~ /order by things desc, stuff asc, orgle asc$/i
    end
  end

  describe '#predicates' do
    EASY_PREDICATES = %i[gt gte gteq lt lte lteq eq not_eq matches like]
    TRICKY_PREDICATES = %i[like_all like_any not_blank]

    it 'creates predicates' do
      Philtre::Filter.predicates.keys.sort.should == (EASY_PREDICATES + TRICKY_PREDICATES).sort
    end

    EASY_PREDICATES.each do |predicate|
      it "_#{predicate} becomes expression" do
        field = Sequel.expr Faker::Lorem.word.to_sym
        value = Faker::Lorem.word
        expr_generator = Philtre::Filter.predicates[predicate]
        expr = expr_generator.call field, value

        expr.should be_a(Sequel::SQL::BooleanExpression)

        expr.args.first.should be_a(Sequel::SQL::Identifier)
        expr.args.first.should == field
        expr.args.last.should == value

        expr.sql_literal(@dataset).should be_a(String)
      end
    end

    it 'like_all takes many' do
      expr_generator = Philtre::Filter.predicates[:like_all]
      field = Sequel.expr Faker::Lorem.word.to_sym
      value = 3.times.map{ Faker::Lorem.word }
      expr = expr_generator.call field, value
      expr.args.size.should == 3
      expr.op.should == :AND
    end

    it 'like_any takes many' do
      expr_generator = Philtre::Filter.predicates[:like_any]
      field = Sequel.expr Faker::Lorem.word.to_sym
      value = 3.times.map{ Faker::Lorem.word }
      expr = expr_generator.call field, value
      expr.args.size.should == 3
      expr.op.should == :OR
    end

    it 'not_blank' do
      expr_generator = Philtre::Filter.predicates[:not_blank]
      field = Sequel.expr Faker::Lorem.word.to_sym
      expr = expr_generator.call field, Faker::Lorem.word

      expr.op.should == :AND

      # the not-nil part
      expr.args.first.op.should == :'IS NOT'

      # the not empty string part
      expr.args.last.op.should == :'!='
      expr.args.last.args.last.should == ''
    end
  end

  describe '#to_expr' do
    let(:filter){ Philtre::Filter.new name: Faker::Lorem.word, title: Faker::Lorem.word }
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
      filter.add_predicate :year_range do |jumbled_years|
        first, last = jumbled_years.sort.instance_eval{|ry| [ry.first, ry.last]}
        { year: first..last }
      end

      expr = filter.to_expr( :year_range, [1984, 1970, 2012] )
      expr.should be_a(Sequel::SQL::Expression)
      expr.sql_literal(dataset).should == '((year >= 1970) AND (year <= 2012))'
    end
  end

  describe '#expr_for' do
    let(:filter){ Philtre::Filter.new name: Faker::Lorem.word, title: Faker::Lorem.word, interstellar: '' }

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
  end

  describe '#order_for' do
    let(:filter){ Philtre::Filter.new name: Faker::Lorem.word, title: Faker::Lorem.word, order:[:name, :title, :year] }
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
      expressions = Philtre::Filter.new( trailer: 'large' ).expressions
      expressions.size.should == 1
      expressions.first.should be_a(Sequel::SQL::BooleanExpression)
      expr, value = expressions.first.args
      expr.should be_a(Sequel::SQL::Identifier)
      expr.value.should == 'trailer'
      value.should == 'large'
    end

    it 'handles stringified operators' do
      expressions = Philtre::Filter.new( trailer_gte: 'large' ).expressions
      expressions.size.should == 1
      expressions.first.should be_a(Sequel::SQL::BooleanExpression)
      expr, value = expressions.first.args
      expr.should be_a(Sequel::SQL::Identifier)
      expr.value.should == 'trailer'
      value.should == 'large'
    end

    it 'ignores order:' do
      Philtre::Filter.new(order: %w[one two tre]).expressions.should be_empty
    end

    it "ignores '' value" do
      Philtre::Filter.new( address: '' ).expressions.should be_empty
    end

    it 'ignores nil value' do
      Philtre::Filter.new( address: nil ).expressions.should be_empty
    end

    it 'accepts []' do
      expressions = Philtre::Filter.new( flavour: [] ).expressions
      expressions.size.should == 1
      expressions.first.should be_a(Sequel::SQL::BooleanExpression)
      expr, value = expressions.first.args
      expr.should be_a(Sequel::SQL::Identifier)
      expr.value.should == 'flavour'
      value.should == []
    end
  end

  describe '#apply' do
    let(:filter){ Philtre::Filter.new name: Faker::Lorem.word, title: Faker::Lorem.word }

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
      filter = Philtre::Filter.new
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

    it 'excludes nil values' do
      filter.filter_parameters[:name] = nil
      sql = filter.apply(@dataset).sql
      sql.should =~ /select \* from planks where \(title = '\w+'\)$/i
    end
  end

  describe '#add_predicate' do
    let(:filter){ Philtre::Filter.new name: Faker::Lorem.word, title: Faker::Lorem.word }

    it 'adds a predicate' do
      filter.add_predicate :tagged_by do |value|
        Sequel.expr( Tag.filter(name: value).exists )
      end
      filter.predicates[:tagged_by].should be_a(Proc)
    end

    it 'does not modify class instance variable' do
      filter.add_predicate :tagged_by do |value|
        Sequel.expr( Tag.filter(name: value).exists )
      end
      Philtre::Filter.predicates.keys.should_not include(:tagged_by)
    end

    it 'modifies arity of 1' do
      filter.add_predicate :tagged_by do |value|
        value
      end
      filter.predicates[:tagged_by].call(:key, :value).should == :value
    end

    it 'handles arity of 2' do
      filter.add_predicate :tagged_by do |key, value|
        [key, value]
      end
      filter.predicates[:tagged_by].call(:key, :value).should == [:key, :value]
    end

    it 'handles arity of *' do
      filter.add_predicate :tagged_by do |*args|
        args
      end
      filter.predicates[:tagged_by].call(:key, :value).should == [:key, :value]
    end
  end

  describe '#empty?' do
    it 'true on no parameters' do
      Philtre::Filter.new.should be_empty
    end

    it 'false with parameters' do
      Philtre::Filter.new(one: 1, two: 2).should_not be_empty
    end
  end

  describe '#subset' do
    it 'has specified subset of parameter values' do
      filter = Philtre::Filter.new done_with: 'Hammers', fixed_by: 'Thor'
      filter.subset( :done_with ).filter_parameters.keys.should == [:done_with]
    end

    it 'has block specified subset of parameter values' do
      filter = Philtre::Filter.new done_with: 'Hammers', fixed_by: 'Thor'
      filter.subset{|k,v| k == :done_with}.filter_parameters.keys.should == [:done_with]
    end

    it 'keeps custom predicates' do
      filter = Philtre::Filter.new( done_with: 'Hammers').tap do |filter|
        filter.add_predicate :done_with do |things|
          Sequel.expr done: things
        end
      end

      filter.subset( :done_with ).predicates.keys.should include( :done_with )
    end
  end

  describe '#extract!' do
    it 'gives back subset' do
      filter = Philtre::Filter.new first: 'James', second: 'McDonald', third: 'Fraser'
      extracted = filter.extract!(:first)
      extracted.to_h.size.should == 1
      extracted.to_h.should have_key(:first)
    end

    it 'removes specified keys' do
      filter = Philtre::Filter.new first: 'James', second: 'McDonald', third: 'Fraser'
      extracted = filter.extract!(:first, :third)
      filter.to_h.size.should == 1
      filter.to_h.should have_key(:second)
    end
  end

  describe '#to_h' do
    def filter
      @filter ||= Philtre::Filter.new first: 'James', second: 'McDonald', third: 'Fraser', fourth: '', fifth: nil
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
      filter = Philtre::Filter.new first: 'James', second: 'McDonald', third: 'Fraser'
      cloned = filter.clone
      cloned.filter_parameters.should == filter.filter_parameters
    end

    it 'clone with extras leaves original' do
      value_hash = {first: 'James', second: 'McDonald', third: 'Fraser'}.freeze
      filter = Philtre::Filter.new value_hash
      cloned = filter.clone( extra: 'Magoodies')

      filter.filter_parameters.should == value_hash
    end

    it 'clone with extras adds values' do
      value_hash = {first: 'James', second: 'McDonald', third: 'Fraser'}.freeze
      filter = Philtre::Filter.new value_hash
      cloned = filter.clone( extra: 'Magoodies')

      (cloned.filter_parameters.keys & filter.filter_parameters.keys).should == filter.filter_parameters.keys
      (cloned.filter_parameters.keys - filter.filter_parameters.keys).should == [:extra]
    end
  end
end
