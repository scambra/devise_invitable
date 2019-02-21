source 'https://rubygems.org'

gemspec

group :test do
  platforms :jruby do
    gem 'activerecord-jdbcsqlite3-adapter', '~> 52.1'
  end

  platforms :ruby do
    gem 'sqlite3', '~> 1.3.6'
  end

  gem 'devise', '~> 4.6'
  gem 'activerecord', '~> 5.2.2'
  gem 'actionmailer', '~> 5.2.2'
  gem 'mongoid' # github: 'mongoid/mongoid', branch: 'master'
  gem 'capybara'
  gem 'mocha'
  gem 'nokogiri'
  gem 'rspec-rails'
end
