source "http://rubygems.org"

if File.exist? File.expand_path('../../rails', __FILE__)
  gem "rails", :path => "../rails"
else
  gem "rails", :git => "git://github.com/rails/rails.git"
end

gem "sqlite3-ruby"
gem "webrat", "0.7.0"
gem "mocha", :require => false
gem "jeweler", :require => false
gem "devise", "~> 1.1", :git => "git://github.com/plataformatec/devise.git"

if RUBY_VERSION < '1.9'
  gem "ruby-debug", ">= 0.10.3"
end

group :mongoid do
  gem "mongo"
  gem "mongoid", :git => "git://github.com/durran/mongoid.git"
  gem "bson_ext"
end
