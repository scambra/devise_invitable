require 'rubygems'
require 'spork'
require 'rspec'

Spork.prefork do
  ENV["RAILS_ENV"] ||= 'test'
  DEVISE_ORM = (ENV["DEVISE_ORM"] || :active_record).to_sym
  
  $:.unshift File.dirname(__FILE__)
  puts "\n==> Devise.orm = #{DEVISE_ORM}"
  
  require File.dirname(__FILE__) + "/rails_app/config/environment" unless defined?(Rails)
  require File.dirname(__FILE__) + "/factories"
  require "rails/test_help"
  require 'rspec/rails'
  require 'shoulda'
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
    config.run_all_when_everything_filtered = true
    
    config.mock_with :rspec
    
    if DEVISE_ORM == :active_record
      config.use_transactional_fixtures = true
      config.use_instantiated_fixtures  = false
    end
    
    config.before(:each) do
      if DEVISE_ORM == :mongoid
        User.delete_all
        Admin.delete_all
      end
    end
    
    config.after(:all) do
    end
    
  end
  
end