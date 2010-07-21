# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{devise_invitable}
  s.version = "0.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Sergio Cambra"]
  s.date = %q{2010-07-13}
  s.description = %q{It adds support for send invitations by email (it requires to be authenticated) and accept the invitation setting the password}
  s.email = %q{sergio@entrecables.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "Gemfile",
     "Gemfile.lock",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "app/controllers/devise/invitations_controller.rb",
     "app/views/devise/invitations/edit.html.erb",
     "app/views/devise/invitations/new.html.erb",
     "app/views/devise/mailer/invitation.html.erb",
     "config/locales/en.yml",
     "devise_invitable.gemspec",
     "lib/devise_invitable.rb",
     "lib/devise_invitable/controllers/helpers.rb",
     "lib/devise_invitable/controllers/url_helpers.rb",
     "lib/devise_invitable/mailer.rb",
     "lib/devise_invitable/model.rb",
     "lib/devise_invitable/rails.rb",
     "lib/devise_invitable/routes.rb",
     "lib/devise_invitable/schema.rb",
     "test/integration/invitable_test.rb",
     "test/mailers/invitation_test.rb",
     "test/models/invitable_test.rb",
     "test/models_test.rb",
     "test/orm/active_record.rb",
     "test/orm/mongoid.rb",
     "test/rails_app/Rakefile",
     "test/rails_app/app/active_record/admin.rb",
     "test/rails_app/app/active_record/shim.rb",
     "test/rails_app/app/active_record/user.rb",
     "test/rails_app/app/controllers/application_controller.rb",
     "test/rails_app/app/controllers/home_controller.rb",
     "test/rails_app/app/helpers/application_helper.rb",
     "test/rails_app/app/mongoid/admin.rb",
     "test/rails_app/app/mongoid/shim.rb",
     "test/rails_app/app/mongoid/user.rb",
     "test/rails_app/app/views/home/index.html.erb",
     "test/rails_app/config.ru",
     "test/rails_app/config/application.rb",
     "test/rails_app/config/boot.rb",
     "test/rails_app/config/database.yml",
     "test/rails_app/config/environment.rb",
     "test/rails_app/config/environments/development.rb",
     "test/rails_app/config/environments/production.rb",
     "test/rails_app/config/environments/test.rb",
     "test/rails_app/config/initializers/backtrace_silencers.rb",
     "test/rails_app/config/initializers/devise.rb",
     "test/rails_app/config/initializers/inflections.rb",
     "test/rails_app/config/initializers/secret_token.rb",
     "test/rails_app/config/routes.rb",
     "test/rails_app/db/migrate/20100401102949_create_tables.rb",
     "test/rails_app/db/schema.rb",
     "test/rails_app/public/404.html",
     "test/rails_app/public/422.html",
     "test/rails_app/public/500.html",
     "test/rails_app/public/favicon.ico",
     "test/rails_app/script/rails",
     "test/routes_test.rb",
     "test/support/assertions.rb",
     "test/support/helpers.rb",
     "test/support/integration.rb",
     "test/support/test_silencer.rb",
     "test/support/webrat/integrations/rails.rb",
     "test/test_helper.rb"
  ]
  s.homepage = %q{http://github.com/scambra/devise_invitable}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{An invitation strategy for devise}
  s.test_files = [
    "test/integration/invitable_test.rb",
     "test/mailers/invitation_test.rb",
     "test/models/invitable_test.rb",
     "test/models_test.rb",
     "test/orm/active_record.rb",
     "test/orm/mongoid.rb",
     "test/rails_app/app/active_record/admin.rb",
     "test/rails_app/app/active_record/shim.rb",
     "test/rails_app/app/active_record/user.rb",
     "test/rails_app/app/controllers/application_controller.rb",
     "test/rails_app/app/controllers/home_controller.rb",
     "test/rails_app/app/helpers/application_helper.rb",
     "test/rails_app/app/mongoid/admin.rb",
     "test/rails_app/app/mongoid/shim.rb",
     "test/rails_app/app/mongoid/user.rb",
     "test/rails_app/config/application.rb",
     "test/rails_app/config/boot.rb",
     "test/rails_app/config/environment.rb",
     "test/rails_app/config/environments/development.rb",
     "test/rails_app/config/environments/production.rb",
     "test/rails_app/config/environments/test.rb",
     "test/rails_app/config/initializers/backtrace_silencers.rb",
     "test/rails_app/config/initializers/devise.rb",
     "test/rails_app/config/initializers/inflections.rb",
     "test/rails_app/config/initializers/secret_token.rb",
     "test/rails_app/config/routes.rb",
     "test/rails_app/db/migrate/20100401102949_create_tables.rb",
     "test/rails_app/db/schema.rb",
     "test/routes_test.rb",
     "test/support/assertions.rb",
     "test/support/helpers.rb",
     "test/support/integration.rb",
     "test/support/test_silencer.rb",
     "test/support/webrat/integrations/rails.rb",
     "test/test_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<mocha>, [">= 0"])
      s.add_development_dependency(%q<webrat>, [">= 0"])
      s.add_runtime_dependency(%q<devise>, ["~> 1.1.0"])
    else
      s.add_dependency(%q<mocha>, [">= 0"])
      s.add_dependency(%q<webrat>, [">= 0"])
      s.add_dependency(%q<devise>, ["~> 1.1.0"])
    end
  else
    s.add_dependency(%q<mocha>, [">= 0"])
    s.add_dependency(%q<webrat>, [">= 0"])
    s.add_dependency(%q<devise>, ["~> 1.1.0"])
  end
end

