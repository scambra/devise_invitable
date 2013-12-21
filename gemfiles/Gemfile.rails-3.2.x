source 'https://rubygems.org'

gemspec :path => '..'

gem 'rails', '~> 3.2.6'

group :test do
  platforms :jruby do
    gem 'activerecord-jdbcsqlite3-adapter', '~> 1.2.9'
  end

  platforms :rbx do
    gem 'minitest', '4.7.5'
    gem 'psych'
    gem 'racc'
    gem 'rubinius-coverage'
    gem 'rubysl', '~> 2.0'
  end

  platforms :ruby do
    gem "sqlite3", "~> 1.3.4"
    gem "bson_ext", "~> 1.3"
    gem "optionable", "~> 0.2.0"
    gem "origin", "~> 2.0.0"
  end

  gem 'activerecord', '~> 3.0'
  gem 'i18n',    "~> 0.6.5"
  gem "mongoid", "~> 2.3"
  gem "capybara", "~> 1.1.0"
  gem 'shoulda', '~> 2.11.3'
  gem 'mocha', '~> 0.13.0'
  gem 'factory_girl_rails', '~> 1.2'
  gem 'nokogiri', '< 1.6.0', :platforms => :ruby_18
end
