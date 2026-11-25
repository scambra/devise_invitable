# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

group :development do
  gem 'bundler', '>= 2.0', require: false
  gem 'simplecov', '~> 0.22.0', require: false
end

group :test do
  platforms :jruby do
    gem 'activerecord-jdbcsqlite3-adapter', '>= 52.1'
  end

  platforms :ruby do
    gem 'sqlite3', '>= 2.1'
  end

  gem 'actionmailer', '~> 8.1.0'
  gem 'activerecord', '~> 8.1.0'
  gem 'capybara'
  gem 'devise', '~> 5.0'
  gem 'mocha'
  gem 'mongoid' # gem 'mongoid', github: 'mongoid/mongoid', branch: 'master'
  gem 'nokogiri'
  gem 'rspec-rails'
end

group :lint do
  gem 'rubocop', '~> 1.86.0', require: false
  gem 'rubocop-erb', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
end
