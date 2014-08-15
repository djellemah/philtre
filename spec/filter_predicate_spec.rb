require 'rspec'
require 'faker'

require Pathname(__dir__) + '../lib/filter-sequel/filter.rb'
require Pathname(__dir__) + '../lib/filter-sequel/predicate_splitter.rb'

# for blank?
Sequel.extension :blank

describe ::PredicateSplitter do
  describe '#split_key' do
    describe 'successful' do
      let(:splitter){ ::PredicateSplitter.new( 'birth_year_like', 'fifteeen' ) }

      it 'returns true' do
        splitter.split_key( :like ).should be_true
      end

      it 'keeps field as symbol' do
        splitter.split_key :like
        splitter.field.should == :birth_year
      end

      it 'keeps op as symbol' do
        splitter.split_key :like
        splitter.op.should == :like
      end
    end

    describe 'unsuccessful' do
      let(:splitter){ ::PredicateSplitter.new 'birth_year', 'fifteeen' }
      it 'returns false' do
        splitter.split_key( :like ).should be_false
      end

      it 'keeps key as symbol' do
        splitter.split_key :like
        splitter.field.should == :birth_year
      end

      it 'op is nil' do
        splitter.split_key :like
        splitter.op.should be_nil
      end
    end

    describe 'custom predicate' do
      let(:splitter){ ::PredicateSplitter.new( 'custom_predicate', 'fifteeen' ) }
      it 'accepts the whole thing' do
        (splitter === :custom_predicate).should === 0
      end
    end
  end

  describe '#fv' do
    it 'returns field as symbol and value' do
      splitter = ::PredicateSplitter.new 'birth_year', 'fifteeen'
      field, value = splitter.fv
      field.should == :birth_year
      value.should == 'fifteeen'
    end
  end

  describe '#ev' do
    it 'returns expression and value' do
      splitter = ::PredicateSplitter.new 'birth_year', 'fifteeen'
      expr, value = splitter.ev

      expr.should be_a(Sequel::SQL::Identifier)
      expr.value.should == 'birth_year'

      value.should == 'fifteeen'
    end

    it 'returns qualified expression and value' do
      splitter = ::PredicateSplitter.new 'departments__birth_year', 'fifteeen'
      expr, value = splitter.ev

      expr.should be_a(Sequel::SQL::QualifiedIdentifier)
      expr.table.should == 'departments'
      expr.column.should == 'birth_year'

      value.should == 'fifteeen'
    end
  end
end

