source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

group :test do
  platforms :jruby do
    gem 'activerecord-jdbcsqlite3-adapter', '~> 52.1'
  end

  platforms :ruby do
    gem 'sqlite3', '~> 1.3.13'
  end

  gem 'actionmailer', '~> 5.2.2'
  gem 'activerecord', '~> 5.2.2'
  gem 'capybara'
  gem 'devise', '~> 4.7'
  gem 'mocha'
  gem 'mongoid' # gem 'mongoid', github: 'mongoid/mongoid', branch: 'master'
  gem 'nokogiri'
  gem 'rspec-rails'
end
