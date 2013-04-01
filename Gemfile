source 'https://rubygems.org'

gemspec

group :test do
  platforms :jruby do
    gem 'activerecord-jdbcsqlite3-adapter'
  end

  platforms :ruby do
    gem "sqlite3", "~> 1.3.4"
  end

  gem 'activerecord', '~> 3.0'
  gem "mongoid", "~> 2.3"
  gem "bson_ext", "~> 1.3"
  gem "capybara", "~> 1.1.0"
  gem 'shoulda', '~> 2.11.3'
  gem 'mocha', '~> 0.12.10', :require => false
  gem 'factory_girl_rails', '~> 1.2'
end
