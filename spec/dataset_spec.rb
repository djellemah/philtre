require_relative 'spec_helper.rb'

require_relative '../lib/philtre/grinder.rb'
require_relative '../lib/philtre/sequel_extensions.rb'
require_relative '../lib/philtre/core_extensions.rb'

Sequel.extension :blank
Sequel.extension :core_extensions

describe Sequel::Dataset do
  subject do
    Sequel.mock[:t].filter( :name.lieu, :title.lieu ).order( :birth_year.lieu )
  end

  describe '#grind' do
    it 'generates sql' do
      subject.grind.sql.should == 'SELECT * FROM t'
    end

    it 'yields grinder' do
      # predeclare so it survives the lambda
      outer_grr = nil
      subject.grind{|grr| outer_grr = grr }.sql.should == 'SELECT * FROM t'
      outer_grr.should be_a(Philtre::Grinder)
    end
  end

  it 'passes apply_unknown'

  describe '#roller' do
    it 'result has to_dataset' do
      rlr = subject.roller do
        where title: 'Exalted Fromaginess'
      end

      # This depends on Ripar, so it's a bit fragile
      rlr.should respond_to(:__class__)
      rlr.__class__.should == Ripar::Roller

      rlr.should_not respond_to(:datset)
      rlr.should respond_to(:to_dataset)
    end
  end

  describe '#rolled' do
    it 'gives back a rolled dataset' do
      rlr = subject.rolled do
        where title: 'Exalted Fromaginess'
      end
      rlr.should be_a(Sequel::Dataset)
      rlr.should_not respond_to(:datset)
      rlr.should_not respond_to(:to_dataset)
    end
  end
end
