# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'devise_invitable/version'

Gem::Specification.new do |s|
  s.name         = "devise_invitable"
  s.version      = DeviseInvitable::VERSION
  s.platform     = Gem::Platform::RUBY
  s.authors      = ["R\303\251my Coutable"]
  s.email        = ["rymai@rymai.com"]
  s.homepage     = "http://github.com/rymai/devise_invitable"
  s.summary      = "An invitation strategy for devise"
  s.description  = "It adds a module to Devise that allow authenticated resources to send invitations by email to others. Invited resources accept an invitation by setting their password."
  s.files        = Dir["{app,config,lib}/**/*"] + %w[LICENSE README.rdoc]
  s.require_path = "lib"
  s.rdoc_options = ["--main", "README.rdoc", "--charset=UTF-8"]
  
  s.required_ruby_version     = '>= 1.8.6'
  s.required_rubygems_version = '~> 1.3.6'
  
  {
    'bundler'            => '~> 1.0.0',
    'spork'              => '~> 0.8.4',
    'rspactor'           => '~> 0.7.beta.6',
    'rspec-rails'        => '~> 2.0.0.beta.20',
    'shoulda'            => '~> 2.11.3',
    'mocha'              => '~> 0.9.8',
    'steak'              => '~> 0.4.0.beta.1',
    'capybara'           => '~> 0.3.9',
    'launchy'            => '~> 0.3.7',
    'factory_girl_rails' => '~> 1.0',
    'sqlite3-ruby'       => '~> 1.3.1',
    'mongoid'            => '2.0.0.beta.17',
    'bson_ext'           => '1.0.4'
  }.each do |lib, version|
    s.add_development_dependency(lib, version)
  end
  
  {
    'rails'  => '~> 3.0.0',
    'devise' => '~> 1.1.2'
  }.each do |lib, version|
    s.add_runtime_dependency(lib, version)
  end
  
end