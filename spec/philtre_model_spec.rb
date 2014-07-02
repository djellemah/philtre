require 'rspec'
require 'faker'
begin
  require 'active_model'

  require Pathname(__dir__).parent.parent + 'lib/philtre/filter_model.rb'

  # spec/support/active_model_lint.rb
  # adapted from rspec-rails:
  # http://github.com/rspec/rspec-rails/blob/master/spec/rspec/rails/mocks/mock_model_spec.rb

  shared_examples_for "ActiveModel" do
    require 'test/unit/assertions'
    # require 'active_model/lint'

    include Test::Unit::Assertions
    include ActiveModel::Lint::Tests

    # to_s is to support ruby-1.9
    ActiveModel::Lint::Tests.public_instance_methods.map{|m| m.to_s}.grep(/^test/).each do |m|
      example m.gsub('_',' ') do
        send m
      end
    end

    def model
      subject
    end
  end

  describe Philtre do
    describe '#for_form' do
      subject{ Philtre.new( one: 1, two: 2 ).for_form }
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
  puts 'not testing ActiveModel'
end
