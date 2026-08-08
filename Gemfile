source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

group :test do
  platforms :jruby do
    gem 'activerecord-jdbcsqlite3-adapter', '>= 52.1'
  end

  platforms :ruby do
    gem 'sqlite3', '~> 1.4'
  end

  gem 'actionmailer', '~> 7.0.0'
  gem 'activerecord', '~> 7.0.0'
  gem 'capybara'
  gem 'devise', '~> 5.0'
  gem 'mocha'
  gem 'mongoid' # gem 'mongoid', github: 'mongoid/mongoid', branch: 'master'
  gem 'nokogiri'
  gem 'rspec-rails'
end
