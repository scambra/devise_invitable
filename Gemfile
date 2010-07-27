source "http://rubygems.org"

gemspec

group :test do
  gem 'sqlite3-ruby'
  
  gem 'mocha', :require => false
  
  gem 'spork'
  gem 'rspactor', '>= 0.7.beta.5'
  
  gem 'shoulda'
  gem 'rspec-rails', '>= 2.0.0.beta.19'
  
  gem 'steak', '>= 0.4.0.beta.1'
  gem 'capybara'
  gem 'launchy'
  
  gem 'factory_girl_rails'
end

group :mongoid do
  gem 'mongo'
  gem 'mongoid',  :git => "git://github.com/durran/mongoid.git"
  gem 'bson_ext', '>= 1.0.4'
end