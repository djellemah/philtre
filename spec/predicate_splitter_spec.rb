require_relative 'spec_helper.rb'
require_relative '../lib/philtre/predicate_splitter.rb'
require_relative '../lib/philtre/predicates.rb'

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
      it 'accepts the whole thing, undeterred by _' do
        splitter = Philtre::PredicateSplitter.new 'custom_predicate', 'fifteeen'
        (splitter === :custom_predicate).should === 0
      end
    end

    describe "'ware the false matches, laddie" do
      Philtre::Predicates::DefaultPredicates.instance_methods.each do |suffix|
        word = Faker::Lorem.words(rand(1..3)) * '_'

        let(:suffix){suffix}
        let(:word){word}

        it "#{word}#{suffix} unsplit" do
          splitter = Philtre::PredicateSplitter.new "#{word}#{suffix}", 'blabla'
          splitter.split_key(suffix).should be_falsey
        end

        it "#{word}_#{suffix} split" do
          splitter = Philtre::PredicateSplitter.new "#{word}_#{suffix}", 'unbla'
          splitter.split_key suffix
          splitter.field.should == word.to_sym
        end
      end
    end
  end
end

