require 'rspec'
require 'faker'
require 'sequel'
require_relative '../lib/philtre/predicate_splitter.rb'

# for blank?
Sequel.extension :blank

describe Philtre::PredicateSplitter do
  describe '#split_key' do
    describe 'successful' do
      let(:splitter) { Philtre::PredicateSplitter.new('birth_year_like', 'fifteeen') }

      it 'returns true' do
        splitter.split_key(:like).should be_truthy
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
      let(:splitter) { Philtre::PredicateSplitter.new 'birth_year', 'fifteeen' }
      it 'returns false' do
        splitter.split_key(:like).should be_falsey
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
      let(:splitter) { Philtre::PredicateSplitter.new('custom_predicate', 'fifteeen') }
      it "doesn't accept the whole thing" do
        (splitter === :custom_predicate).should be_falsey
      end
    end

    describe 'hstore' do
      describe 'successful' do
        let(:splitter) { Philtre::PredicateSplitter.new('store[column]_like', 'fifteeen') }

        it 'returns true' do
          splitter.split_key(:like).should be_truthy
        end

        it 'keeps field as symbol' do
          splitter.split_key :like
          splitter.field.should == 'store[column]'.to_sym
        end

        it 'keeps op as symbol' do
          splitter.split_key :like
          splitter.op.should == :like
        end
      end

      describe 'unsuccessful' do
        let(:splitter) { Philtre::PredicateSplitter.new 'store[column]', 'fifteeen' }
        it 'returns false' do
          splitter.split_key(:like).should be_falsey
        end

        it 'keeps key as symbol' do
          splitter.split_key :like
          splitter.field.should == 'store[column]'.to_sym
        end

        it 'op is nil' do
          splitter.split_key :like
          splitter.op.should be_nil
        end
      end
    end

    describe 'corner cases' do
      it "doesn't take gt extension by mistake" do
        splitter = Philtre::PredicateSplitter.new('blagt', 'foo')
        splitter.split_key(:gt).should be_falsey
      end

      it "doesn't take eq extension by mistake" do
        splitter = Philtre::PredicateSplitter.new('blaeq', 'foo')
        splitter.split_key(:eq).should be_falsey
      end
    end
  end
end

