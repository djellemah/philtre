require 'rspec'
require 'faker'

# TODO this should be in philtre-rails
begin
  require 'active_model'

  require_relative '../lib/philtre/filter.rb'
  require_relative '../lib/philtre/philtre_model.rb'

  # spec/support/active_model_lint.rb
  # adapted from rspec-rails:
  # http://github.com/rspec/rspec-rails/blob/master/spec/rspec/rails/mocks/mock_model_spec.rb
  shared_examples_for "ActiveModel" do
    require 'minitest'
    require 'active_model/lint'

    # needed by MiniTest::Assertions
    def assertions; @assertions ||= 0 end
    def assertions=( rhs ); @assertions = rhs end

    include MiniTest::Assertions

    include ActiveModel::Lint::Tests

    ActiveModel::Lint::Tests
      .public_instance_methods
      .grep(/^test/)
      .each do |test_method|
        example test_method.to_s.gsub('_',' ') do
          send test_method
        end
      end

    # needed for MiniTest::Assertions
    def model; subject end
  end

  describe Philtre::Filter do
    describe '#for_form' do
      subject{ Philtre::Filter.new( one: 1, two: 2 ).for_form }
      it_should_behave_like("ActiveModel")

      it 'nil for not present' do
        subject.three.should be_nil
      end

      it 'value for present' do
        subject.two.should == 2
      end
    end
  end
rescue LoadError
  describe 'Philtre::Model' do
    skip 'not testing because active_model not found'
  end
end
