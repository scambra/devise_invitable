# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'devise_invitable/version'

Gem::Specification.new do |s|
  s.name         = "devise_invitable"
  s.version      = DeviseInvitable::VERSION
  s.platform     = Gem::Platform::RUBY
  s.authors      = ["Sergio Cambra"]
  s.email        = ["sergio@entrecables.com"]
  s.homepage     = "https://github.com/scambra/devise_invitable"
  s.summary      = "An invitation strategy for Devise"
  s.description  = "It adds support for send invitations by email (it requires to be authenticated) and accept the invitation by setting a password."
  s.license      = 'MIT'
  s.files        = `git ls-files {app,config,lib}`.split("\n") + %w[LICENSE README.rdoc CHANGELOG]
  s.require_path = "lib"
  s.rdoc_options = ["--main", "README.rdoc", "--charset=UTF-8"]
  s.test_files = `git ls-files test`.split("\n")

  s.required_ruby_version     = '>= 1.8.6'
  s.required_rubygems_version = '>= 1.3.6'

  s.add_development_dependency('bundler', '>= 1.1.0')

  s.add_runtime_dependency('actionmailer', '>= 4.1.0')
  s.add_runtime_dependency('devise', '>= 4.0.0')
end
