source 'https://rubygems.org'

gemspec

group :test do
  platforms :jruby do
    gem 'activerecord-jdbcsqlite3-adapter', '>= 1.3.0.beta1'
  end

  platforms :ruby do
    gem "sqlite3", "~> 1.3.4"
  end

  gem 'devise', '~> 4.0'
  gem 'test_after_commit' # needed for devise >= 4.1 and rails < 5
  gem 'activerecord', '~> 4.2.7.1'
  gem 'actionmailer', '~> 4.2.7.1'
  gem "mongoid"
  # gem "mongoid", :github => "mongoid/mongoid", :branch => "master"
  gem "capybara"
  #gem "launchy", "~> 2.4.3"
  gem 'mocha'
  gem 'factory_girl_rails'
  gem 'nokogiri'
  gem 'rspec-rails'
end
