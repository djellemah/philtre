require 'rspec'
require 'faker'
require 'sequel'

# turn off the "old syntax" warnings
RSpec.configure do |config|
  config.mock_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end
