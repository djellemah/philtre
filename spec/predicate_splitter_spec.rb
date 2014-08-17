require 'rspec'
require 'faker'

require_relative '../lib/philtre/predicate_splitter.rb'

# for blank?
Sequel.extension :blank

describe Philtre::PredicateSplitter do
  describe '#split_key' do
    describe 'successful' do
      let(:splitter){ Philtre::PredicateSplitter.new( 'birth_year_like', 'fifteeen' ) }

      it 'returns true' do
        splitter.split_key( :like ).should be_truthy
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
      let(:splitter){ Philtre::PredicateSplitter.new 'birth_year', 'fifteeen' }
      it 'returns false' do
        splitter.split_key( :like ).should be_falsey
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
      let(:splitter){ Philtre::PredicateSplitter.new( 'custom_predicate', 'fifteeen' ) }
      it 'accepts the whole thing' do
        (splitter === :custom_predicate).should === 0
      end
    end
  end
end

