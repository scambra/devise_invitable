require 'spec_helper'
require 'steak'
require 'capybara/rails'

Rspec.configure do |config|
  config.include Capybara
  
  config.before(:each) do
  end
  
  config.after(:each) do
    Capybara.reset_sessions!
  end
end

# Put your acceptance spec helpers inside /spec/acceptance/support
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}