source "http://rubygems.org"

gem "rails", :git => "git://github.com/rails/rails.git"

gem "sqlite3-ruby"
gem "webrat",       "0.7.0"
gem "mocha",                  :require => false
gem "jeweler",                :require => false
gem "devise",       "~> 1.1", :git => "git://github.com/plataformatec/devise.git"

if RUBY_VERSION < '1.9'
  gem "ruby-debug", ">= 0.10.3"
end

group :mongoid do
  gem "mongo"
  gem "mongoid", :git => "git://github.com/durran/mongoid.git"
  gem "bson_ext"
end
