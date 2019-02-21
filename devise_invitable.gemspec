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
  s.files        = `git ls-files {app,config,lib}`.split("\n") + %w[LICENSE README.rdoc CHANGELOG.md]
  s.require_path = "lib"
  s.rdoc_options = ["--main", "README.rdoc", "--charset=UTF-8"]
  s.test_files = `git ls-files test`.split("\n")

  s.required_ruby_version     = '>= 2.2.2'
  s.required_rubygems_version = '>= 2.5.0'

  s.add_development_dependency('bundler', '~> 2.0.1')

  s.add_runtime_dependency('actionmailer', '>= 5.0')
  s.add_runtime_dependency('devise', '~> 4.6')
end
