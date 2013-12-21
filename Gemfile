source 'https://rubygems.org'

gemspec

group :test do
  platforms :jruby do
    gem 'activerecord-jdbcsqlite3-adapter', '>= 1.3.0.beta1'
    gem "bson", "~> 2.0"
  end

  platforms :rbx do
   gem 'racc'
   gem 'rubysl'
  end

  platforms :ruby do
    gem "sqlite3", "~> 1.3.4"
    gem "bson_ext", "~> 1.3"
  end

  gem 'activerecord', '~> 4.0.0.beta'
  gem "mongoid", :github => "mongoid/mongoid", :branch => "master"
  gem "capybara", "~> 1.1.0"
  gem 'shoulda', '~> 2.11.3'
  gem 'mocha', '~> 0.13.0'
  gem 'factory_girl_rails', '~> 1.2'
  gem 'nokogiri', '< 1.6.0', :platforms => :ruby_18
  gem 'rspec-rails', '~> 2.12.0'
end
