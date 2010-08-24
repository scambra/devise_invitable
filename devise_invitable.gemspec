# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

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
  
  s.required_rubygems_version = '~> 1.3.6'
  
  s.add_runtime_dependency 'rails',  '~> 3.0.0.rc2'
  s.add_runtime_dependency 'devise', '~> 1.1.1'
end