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
  s.files        = Dir["{app,config,lib}/**/*"] + %w[LICENSE README.rdoc]
  s.require_path = "lib"
  s.rdoc_options = ["--main", "README.rdoc", "--charset=UTF-8"]
  
  s.required_ruby_version     = '>= 1.8.6'
  s.required_rubygems_version = '>= 1.3.6'

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<mocha>, [">= 0.9.8"])
      s.add_development_dependency(%q<capybara>, [">= 0.3.9"])
      s.add_development_dependency(%q<rails>, ["~> 3.0.0"])
      s.add_development_dependency(%q<sqlite3-ruby>, [">= 0"])
      s.add_runtime_dependency(%q<devise>, ["~> 1.1.0"])
    else
      s.add_dependency(%q<mocha>, [">= 0.9.8"])
      s.add_dependency(%q<capybara>, [">= 0.3.9"])
      s.add_dependency(%q<rails>, ["~> 3.0.0"])
      s.add_dependency(%q<sqlite3-ruby>, [">= 0"])
      s.add_dependency(%q<devise>, ["~> 1.1.0"])
    end
  else
    s.add_dependency(%q<mocha>, [">= 0.9.8"])
    s.add_dependency(%q<capybara>, [">= 0.3.9"])
    s.add_dependency(%q<rails>, ["~> 3.0.0"])
    s.add_dependency(%q<sqlite3-ruby>, [">= 0"])
    s.add_dependency(%q<devise>, ["~> 1.1.0"])
  end
end

