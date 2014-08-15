require 'rspec'
require 'faker'
require 'sequel'

require Pathname(__dir__).parent + 'lib/philtre/grinder.rb'
require Pathname(__dir__).parent + 'lib/philtre/sequel_extensions.rb'

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
      rlr.should_not respond_to(:dataset)
      rlr.should respond_to(:to_dataset)
    end

    it 'handles roller syntax'
  end

  describe '#rolled' do
    it 'gives back a rolled dataset'
  end
end
