# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'devise_invitable/version'

Gem::Specification.new do |s|
  s.name         = "devise_invitable"
  s.version      = DeviseInvitable::VERSION
  s.platform     = Gem::Platform::RUBY
  s.authors      = ["Sergio Cambra"]
  s.email        = ["sergio@entrecables.com"]
  s.homepage     = "http://github.com/rymai/devise_invitable"
  s.summary      = "An invitation strategy for Devise"
  s.description  = "It adds support for send invitations by email (it requires to be authenticated) and accept the invitation by setting a password."
  s.files        = Dir["{app,config,lib}/**/*"] + %w[LICENSE README.rdoc]
  s.require_path = "lib"
  s.rdoc_options = ["--main", "README.rdoc", "--charset=UTF-8"]
  
  s.required_ruby_version     = '>= 1.8.6'
  s.required_rubygems_version = '~> 1.3.6'
  
  {
    'bundler'            => '~> 1.0.7',
    'rspec-rails'        => '~> 2.1.0',
    'shoulda'            => '~> 2.11.3',
    'mocha'              => '~> 0.9.9',
    'steak'              => '~> 1.0.0.rc.3',
    'capybara'           => '~> 0.4.0',
    'factory_girl_rails' => '~> 1.0',
    'sqlite3-ruby'       => '~> 1.3.2',
    'mongoid'            => '2.0.0.beta.20',
    'bson_ext'           => '1.1.2'
  }.each do |lib, version|
    s.add_development_dependency(lib, version)
  end
  
  {
    'rails'  => '~> 3.0.0',
    'devise' => '~> 1.2.rc'
  }.each do |lib, version|
    s.add_runtime_dependency(lib, version)
  end
  
end
