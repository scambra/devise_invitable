$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'spork'
require 'rspec'

Spork.prefork do
  ENV["RAILS_ENV"] ||= 'test'
  DEVISE_ORM = (ENV["DEVISE_ORM"] || :active_record).to_sym
  
  puts "\n==> Devise.orm = #{DEVISE_ORM}"
  
  require "rails_app/config/environment"
  require "factories"
  require "rails/test_help"
  require "rspec/rails"
  require "shoulda"
  require "orm/#{DEVISE_ORM}"
  I18n.load_path << File.expand_path("../support/locale/en.yml", __FILE__) if DEVISE_ORM == :mongoid
end

Spork.each_run do
  # Requires supporting files with custom matchers and macros, etc, in ./support/ and its subdirectories.
  Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each { |f| require f }
  
  RSpec.configure do |config|
    config.color_enabled = true
    config.include Shoulda::ActionController::Matchers
    
    config.filter_run :focus => true
    config.filter_run_excluding :slow => true
    config.run_all_when_everything_filtered = true
    
    config.mock_with :rspec
    
    if DEVISE_ORM == :active_record
      config.use_transactional_fixtures = true
      config.use_instantiated_fixtures  = false
    end
    
    config.before(:each) do
      [User, Admin].map(&:delete_all) if DEVISE_ORM == :mongoid
    end
  end
end